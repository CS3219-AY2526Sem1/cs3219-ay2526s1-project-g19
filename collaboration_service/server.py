import logging
import os
import socketio
from socketio import AsyncRedisManager
from aiohttp import web
import redis.asyncio as aioredis
import asyncio
from datetime import datetime
from schemas import CodeChangeData, CursorData, ErrorData, RoomJoinData
from kafka.kafka_client import kafka_client
from confluent_kafka.schema_registry.avro import AvroSerializer
from config import settings

# Use settings from config
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

logger = logging.getLogger(__name__)

EXPIRY_TIME = settings.expiry_time
INACTIVE_SESSION_TIMEOUT = settings.inactive_session_timeout
SERVICE_PREFIX = settings.service_prefix.rstrip("/")
REDIS_URL = settings.redis_url

# Track background tasks for ending sessions
session_end_tasks = {}

# Load session end schema and create serializer
with open("kafka/schemas/session_end.avsc") as f:
    session_end_schema = f.read()

session_end_serializer = AvroSerializer(
    kafka_client.schema_registry_client,
    session_end_schema
)


@web.middleware
async def fixed_prefix_middleware(request, handler):
    """
    Strip a configured prefix so the service can respond on both the root path
    and the prefixed path (e.g. behind nginx /collaboration-service-api).
    Also re-prefix Location headers on redirects.
    """
    target_request = request
    if SERVICE_PREFIX and request.path.startswith(SERVICE_PREFIX):
        stripped_path = request.path[len(SERVICE_PREFIX):] or "/"
        rel_url = request.rel_url.with_path(stripped_path)
        clone_kwargs = {"rel_url": rel_url, "headers": request.headers.copy()}
        target_request = request.clone(**clone_kwargs)
        logging.info("prefix rewrite: %s -> %s", request.path_qs, target_request.path_qs)

    response = await handler(target_request)

    logging.info(
        "REQ %s %s -> %s",
        request.method,
        target_request.path_qs if target_request is not request else request.path_qs,
        response.status,
    )

    if SERVICE_PREFIX:
        location = response.headers.get("Location")
        if location and location.startswith("/") and not location.startswith(SERVICE_PREFIX):
            response.headers["Location"] = f"{SERVICE_PREFIX}{location}"

    return response


async def health_check(request):
    """Health check endpoint for ALB"""
    return web.json_response({"status": "healthy"})


# --- Socket.IO server clustered with Redis ---
sio = socketio.AsyncServer(
    cors_allowed_origins="*",
    logger=True,
    engineio_logger=True,
    client_manager=AsyncRedisManager(REDIS_URL),
    ping_interval=25,
    ping_timeout=60,
)

# Create main app and ATTACH ONCE. Register middleware.
app = web.Application()
sio.attach(app, socketio_path="socket.io")

# Health routes (work at both /health and /{prefix}/health thanks to middleware)
app.router.add_get("/health", health_check)
app.router.add_get("/health/", health_check)

# Create prefixed subapp, attach socket.io again (so /prefix/socket.io works)
prefixed_app = web.Application()
sio.attach(prefixed_app, socketio_path="socket.io")
prefixed_app.router.add_get("/health", health_check)
prefixed_app.router.add_get("/health/", health_check)
app.add_subapp(SERVICE_PREFIX, prefixed_app)


# Initialize Redis connection (for cached code snapshots)
redis = None

async def init_redis():
    """Initialize Redis connection."""
    global redis
    try:
        redis = await aioredis.from_url(REDIS_URL, decode_responses=True)
        logger.info(f"Connected to Redis at {REDIS_URL}")
    except Exception as e:
        logger.exception("Failed to connect to Redis")
        raise


async def cleanup_on_startup():
    """Clean up all collaboration-related data on server startup."""
    try:
        # Get all room code keys
        room_keys = await redis.keys("room:*:code")
        if room_keys:
            await redis.delete(*room_keys)
            logger.info(f"Cleaned up {len(room_keys)} room code entries on startup")

        # Get all room users keys
        user_keys = await redis.keys("collab_room_users:*")
        if user_keys:
            await redis.delete(*user_keys)
            logger.info(f"Cleaned up {len(user_keys)} room user entries on startup")
        
        # Get all sid-to-user mapping keys
        sid_keys = await redis.keys("collab_sid_to_user:*")
        if sid_keys:
            await redis.delete(*sid_keys)
            logger.info(f"Cleaned up {len(sid_keys)} sid-to-user mapping entries on startup")
        
        # Get all session users tracking keys
        session_user_keys = await redis.keys("session_all_users:*")
        if session_user_keys:
            await redis.delete(*session_user_keys)
            logger.info(f"Cleaned up {len(session_user_keys)} session users tracking entries on startup")
        
        # Get all users who left tracking keys
        who_left_keys = await redis.keys("session_users_who_left:*")
        if who_left_keys:
            await redis.delete(*who_left_keys)
            logger.info(f"Cleaned up {len(who_left_keys)} users who left tracking entries on startup")

        # Get all inactive session keys
        inactive_keys = await redis.keys("inactive_collab_session:*")
        if inactive_keys:
            await redis.delete(*inactive_keys)
            logger.info(f"Cleaned up {len(inactive_keys)} inactive session entries on startup")

        logger.info("Startup cleanup completed")
    except Exception as e:
        logger.error(f"Error during startup cleanup: {e}")


async def schedule_session_end(room: str):
    """Schedule a session to end after timeout if room becomes empty."""
    # Cancel existing task if any
    if room in session_end_tasks:
        session_end_tasks[room].cancel()
    
    # Mark session as inactive in Redis
    inactive_key = f"inactive_collab_session:{room}"
    await redis.set(inactive_key, "1", ex=INACTIVE_SESSION_TIMEOUT + 60)
    
    async def end_session_task():
        """Background task to end session after timeout."""
        try:
            logger.info(f"Waiting {INACTIVE_SESSION_TIMEOUT}s before ending session {room}")
            await asyncio.sleep(INACTIVE_SESSION_TIMEOUT)
            
            # Check if room still has no users
            room_users_key = f"collab_room_users:{room}"
            user_count = await redis.scard(room_users_key)
            
            if user_count == 0:
                try:
                    # Produce session end event to Kafka
                    ended_at = int(datetime.now().timestamp() * 1000)
                    timestamp = ended_at
                    
                    value = {
                        "session_id": room,
                        "ended_at": ended_at,
                        "timestamp": timestamp
                    }
                    
                    kafka_client.produce(
                        topic=settings.topic_session_end,
                        key=room,
                        value=value,
                        serializer=session_end_serializer
                    )
                    
                    kafka_client.producer.flush()
                    logger.info(f"Successfully produced session end event for {room}")
                    
                    # Clean up Redis data
                    await redis.delete(room_users_key)
                    await redis.delete(f"session_all_users:{room}")
                    await redis.delete(f"session_users_who_left:{room}")
                    await redis.delete(f"room:{room}:code")
                    await redis.delete(f"inactive_collab_session:{room}")
                    
                except Exception as e:
                    logger.error(f"Error producing session end event for {room}: {e}")
                    # Clean up Redis even if Kafka fails
                    await redis.delete(room_users_key)
                    await redis.delete(f"session_all_users:{room}")
                    await redis.delete(f"session_users_who_left:{room}")
                    await redis.delete(f"room:{room}:code")
                    await redis.delete(f"inactive_collab_session:{room}")
            else:
                logger.info(f"Session {room} has active users, not ending")
                await redis.delete(f"inactive_collab_session:{room}")
        except asyncio.CancelledError:
            logger.info(f"Session end task for {room} was cancelled")
        finally:
            # Clean up task reference
            if room in session_end_tasks:
                del session_end_tasks[room]
    
    # Create and store the task
    task = asyncio.create_task(end_session_task())
    session_end_tasks[room] = task
    logger.info(f"Scheduled session end for {room} in {INACTIVE_SESSION_TIMEOUT}s")


async def cancel_session_end(room: str):
    """Cancel scheduled session end when users rejoin."""
    if room in session_end_tasks:
        session_end_tasks[room].cancel()
        del session_end_tasks[room]
    
    # Remove inactive marker
    inactive_key = f"inactive_collab_session:{room}"
    await redis.delete(inactive_key)
    logger.info(f"Cancelled session end for {room}")


async def end_session_now(room: str):
    """Immediately end a session (when all users have permanently left)."""
    try:
        # Cancel any pending timeout tasks
        if room in session_end_tasks:
            session_end_tasks[room].cancel()
            del session_end_tasks[room]
        
        # Produce session end event to Kafka
        ended_at = int(datetime.now().timestamp() * 1000)
        timestamp = ended_at
        
        value = {
            "session_id": room,
            "ended_at": ended_at,
            "timestamp": timestamp
        }
        
        kafka_client.produce(
            topic=settings.topic_session_end,
            key=room,
            value=value,
            serializer=session_end_serializer
        )
        
        kafka_client.producer.flush()
        logger.info(f"Successfully ended session {room} immediately (all users left)")
        
        # Clean up Redis data
        room_users_key = f"collab_room_users:{room}"
        session_users_key = f"session_all_users:{room}"
        users_who_left_key = f"session_users_who_left:{room}"
        
        await redis.delete(room_users_key)
        await redis.delete(session_users_key)
        await redis.delete(users_who_left_key)
        await redis.delete(f"room:{room}:code")
        await redis.delete(f"inactive_collab_session:{room}")
        
        logger.info(f"Cleaned up Redis data for session {room}")
        
    except Exception as e:
        logger.error(f"Error ending session {room} immediately: {e}")


@sio.event
async def connect(sid, environ):
    """Handle a new WebSocket connection."""
    logger.info(f"WebSocket: connect called for SID {sid}")


@sio.event
async def join(sid, data):
    """Handle a user joining a room."""
    join_data = RoomJoinData.from_request(data, sid)

    if not join_data.room:
        error = ErrorData("room is required")
        await sio.emit("error", error.to_dict(), to=sid)
        return

    await sio.enter_room(sid, join_data.room)
    
    # Track user in room (socket ID)
    room_users_key = f"collab_room_users:{join_data.room}"
    await redis.sadd(room_users_key, sid)
    await redis.expire(room_users_key, EXPIRY_TIME)
    
    # Map socket ID to user ID for tracking permanent leaves
    sid_to_user_key = f"collab_sid_to_user:{join_data.room}:{sid}"
    await redis.setex(sid_to_user_key, EXPIRY_TIME, join_data.user_id)
    
    # Initialize the set of users who participated in this session
    # This tracks ALL users who have ever been in the session
    session_users_key = f"session_all_users:{join_data.room}"
    await redis.sadd(session_users_key, join_data.user_id)
    await redis.expire(session_users_key, EXPIRY_TIME)
    
    # Remove this user from "who left" set since they're rejoining
    users_who_left_key = f"session_users_who_left:{join_data.room}"
    await redis.srem(users_who_left_key, join_data.user_id)
    logger.info(f"User {join_data.user_id} rejoined, removed from 'who left' tracking")
    
    # Cancel any scheduled session end
    await cancel_session_end(join_data.room)
    
    logger.info(f"User {join_data.user_id} (SID {sid}) joined room {join_data.room}")

    # Send cached code if it exists
    cache_key = f"room:{join_data.room}:code"
    try:
        cached_code = await redis.get(cache_key)
        if cached_code:
            logger.info(f"Found cached code for room {join_data.room}, sending to SID {sid}")
            code_data = CodeChangeData(code=cached_code)
            await sio.emit("receive", code_data.to_dict(), to=sid)
    except Exception:
        logger.exception("Redis GET failed for %s", cache_key)


@sio.event
async def change(sid, data):
    """Handle code changes."""
    room = data.get("room")
    code = data.get("code")

    if not room or code is None:
        error = ErrorData("room and code are required")
        await sio.emit("error", error.to_dict(), to=sid)
        return

    code_change = CodeChangeData(code=code)

    # Cache the new code in Redis for late joiners
    cache_key = f"room:{room}:code"
    try:
        await redis.setex(cache_key, EXPIRY_TIME, code)
    except Exception:
        logger.exception("Redis SETEX failed for %s", cache_key)

    # Broadcast the code change to others in the room
    await sio.emit("receive", code_change.to_dict(), room=room, skip_sid=sid)
    logger.info(f"Code change broadcasted to room {room} by SID {sid}")


@sio.event
async def leave(sid, data):
    """Handle user leaving a room."""
    room = data.get("room")
    if not room:
        error = ErrorData("room is required")
        await sio.emit("error", error.to_dict(), to=sid)
        return

    # Get the user ID from the socket mapping
    sid_to_user_key = f"collab_sid_to_user:{room}:{sid}"
    user_id = await redis.get(sid_to_user_key)
    
    if user_id:
        # Mark this user as having left (permanently, until they rejoin)
        users_who_left_key = f"session_users_who_left:{room}"
        await redis.sadd(users_who_left_key, user_id)
        await redis.expire(users_who_left_key, EXPIRY_TIME)
        logger.info(f"User {user_id} marked as left in room {room}")
    
    # Remove user from room tracking
    room_users_key = f"collab_room_users:{room}"
    await redis.srem(room_users_key, sid)
    
    # Clean up socket-to-user mapping
    await redis.delete(sid_to_user_key)

    # Notify other users in the room that this user left
    await sio.emit("user_left", {"userId": sid}, room=room, skip_sid=sid)

    await sio.leave_room(sid, room)
    logger.info(f"SID {sid} left room {room}")
    
    # Check if we should end the session
    remaining_users = await redis.scard(room_users_key)
    
    if remaining_users == 0:
        # Room is empty - check if ALL users who participated have left at least once
        session_users_key = f"session_all_users:{room}"
        users_who_left_key = f"session_users_who_left:{room}"
        
        all_users = await redis.smembers(session_users_key)
        users_who_left = await redis.smembers(users_who_left_key)
        
        # Convert bytes to strings if needed
        all_users = {u.decode() if isinstance(u, bytes) else u for u in all_users}
        users_who_left = {u.decode() if isinstance(u, bytes) else u for u in users_who_left}
        
        logger.info(f"Room {room} empty. All users: {all_users}, Users who left: {users_who_left}")
        
        # End session only if everyone has left at least once
        if all_users and all_users.issubset(users_who_left):
            logger.info(f"All users have left room {room}. Ending session immediately.")
            await end_session_now(room)
        else:
            logger.info(f"Room {room} empty but not all users have left yet. Scheduling timeout.")
            await schedule_session_end(room)


@sio.event
async def disconnect(sid):
    """Handle WebSocket disconnection."""
    rooms = sio.manager.get_rooms(sid, namespace='/')
    for room in rooms:
        if room != sid:  # Skip the user's own room
            # Remove from room tracking
            room_users_key = f"collab_room_users:{room}"
            await redis.srem(room_users_key, sid)
            
            # Notify others
            await sio.emit("user_left", {"userId": sid}, room=room, skip_sid=sid)
            
            # Check if room is now empty
            remaining_users = await redis.scard(room_users_key)
            if remaining_users == 0:
                logger.info(f"Room {room} is now empty after disconnect, scheduling session end")
                await schedule_session_end(room)

    logger.info(f"WebSocket: disconnect called for SID {sid}")


@sio.event
async def cursor(sid, data):
    """Handle cursor position updates."""
    room = data.get("room")
    if not room:
        error = ErrorData("room is required")
        await sio.emit("error", error.to_dict(), to=sid)
        return

    cursor_data = CursorData.from_dict(data, sid)

    # Volatile broadcast; no persistence
    await sio.emit("cursor", cursor_data.to_dict(), room=room, skip_sid=sid)
    logger.info(f"Cursor update from {sid} in room {room} at line {cursor_data.line}, ch {cursor_data.ch}")


async def startup_sequence(app):
    """Run startup sequence."""
    await init_redis()
    await cleanup_on_startup()


async def shutdown_sequence(app):
    """Run shutdown sequence."""
    kafka_client.shutdown()


# Run the server
if __name__ == "__main__":
    app.on_startup.append(startup_sequence)
    app.on_shutdown.append(shutdown_sequence)
    web.run_app(app, port=settings.port)
