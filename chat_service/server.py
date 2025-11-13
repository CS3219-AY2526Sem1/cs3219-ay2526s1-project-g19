import json
import logging
import os
import socketio
from socketio import AsyncRedisManager
from aiohttp import web
import redis.asyncio as redis
from schemas import MessageData

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

# --- Config / constants ---
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
EXPIRY_TIME = 3600
SERVICE_PREFIX = os.getenv("SERVICE_PREFIX", "/chat-service-api")
if SERVICE_PREFIX and not SERVICE_PREFIX.startswith("/"):
    SERVICE_PREFIX = "/" + SERVICE_PREFIX
SERVICE_PREFIX = SERVICE_PREFIX.rstrip("/")

# --- Redis connection (for chat history) ---
redis_client = None

async def init_redis():
    global redis_client
    redis_client = await redis.from_url(REDIS_URL, decode_responses=True)
    logger.info(f"Connected to Redis at {REDIS_URL}")

async def cleanup_on_startup():
    """Clean up chat-related data on server startup."""
    try:
        chat_keys = await redis_client.keys("chat_history_*")
        if chat_keys:
            await redis_client.delete(*chat_keys)
            logger.info(f"Cleaned up {len(chat_keys)} chat history entries on startup")

        user_keys = await redis_client.keys("room_users_*")
        if user_keys:
            await redis_client.delete(*user_keys)
            logger.info(f"Cleaned up {len(user_keys)} room user entries on startup")

        logger.info("Startup cleanup completed")
    except Exception as e:
        logger.error(f"Error during startup cleanup: {e}")

async def health_check(request):
    return web.json_response({"status": "healthy"})

# --- Socket.IO: create TWO servers that share the SAME Redis manager ---
def make_sio() -> socketio.AsyncServer:
    return socketio.AsyncServer(
        cors_allowed_origins="*",
        logger=True,
        engineio_logger=True,
        client_manager=AsyncRedisManager(REDIS_URL),  # <-- cross-pod + cross-app fanout
        ping_interval=25,
        ping_timeout=60,
    )

sio_root = make_sio()      # serves at /socket.io
sio_prefixed = make_sio()  # serves at /{SERVICE_PREFIX}/socket.io

# --- Register identical event handlers on BOTH Socket.IO servers ---
def register_handlers(sio: socketio.AsyncServer):

    @sio.event
    async def connect(sid, environ):
        logger.info(f"[{id(sio)}] User connected: {sid}")
        print(f"[{id(sio)}] User connected: {sid}")

    @sio.event
    async def join(sid, data):
        username = (data or {}).get("username")
        room = (data or {}).get("room")
        if not room or not username:
            await sio.emit("error", {"message": "username and room are required"}, to=sid)
            return

        # Get current users in room before joining
        room_users_key = f"room_users_{room}"
        existing_users = await redis_client.smembers(room_users_key)
        
        # Enter the room
        await sio.enter_room(sid, room)
        
        # Add user to room tracking
        await redis_client.sadd(room_users_key, username)
        await redis_client.expire(room_users_key, EXPIRY_TIME)
        
        logger.info(f"[{id(sio)}] {username} joined room: {room}")

        # Replay last messages
        cache_key = f"chat_history_{room}"
        try:
            history = await redis_client.lrange(cache_key, 0, -1)
        except Exception:
            history = []
            logger.exception("Redis LRANGE failed for %s", cache_key)

        for msg_str in history or []:
            msg_dict = json.loads(msg_str)
            msg_data = MessageData.from_dict(msg_dict)
            await sio.emit("receive", msg_data.to_dict(), to=sid)

        # Notify the joining user about existing users first
        for existing_user in existing_users:
            if existing_user != username:  # Don't announce self
                existing_user_notification = MessageData(
                    message=f"{existing_user} has joined the session",
                    username="ChatBot"
                )
                await sio.emit("receive", existing_user_notification.to_dict(), to=sid)

        # Then notify room about new user joining
        join_notification = MessageData(
            message=f"{username} has joined the session",
            username="ChatBot"
        )
        await sio.emit("receive", join_notification.to_dict(), room=room)

    @sio.event
    async def send(sid, data):
        room = (data or {}).get("room")
        username = (data or {}).get("username")
        message = (data or {}).get("message")

        if not all([room, username, message]):
            await sio.emit("error", {"message": "room, username and message are required"}, to=sid)
            return

        message_data = MessageData(message=message, username=username)

        cache_key = f"chat_history_{room}"
        try:
            await redis_client.rpush(cache_key, json.dumps(message_data.to_dict()))
            # Keep only last 100 messages
            await redis_client.ltrim(cache_key, -100, -1)
            # Set expiry time (refreshes on every message)
            await redis_client.expire(cache_key, EXPIRY_TIME)
        except Exception:
            logger.exception("Redis write failed for %s", cache_key)

        await sio.emit("receive", message_data.to_dict(), room=room)
        logger.info(f"[{id(sio)}] {username} @ {room}: {message}")

    @sio.event
    async def leave(sid, data):
        username = (data or {}).get("username")
        room = (data or {}).get("room")
        if not room or not username:
            await sio.emit("error", {"message": "username and room are required"}, to=sid)
            return

        # Remove user from room tracking
        room_users_key = f"room_users_{room}"
        await redis_client.srem(room_users_key, username)
        
        await sio.leave_room(sid, room)
        leave_notification = MessageData(
            message=f"{username} has left the room",
            username="ChatBot"
        )
        await sio.emit("receive", leave_notification.to_dict(), room=room)
        
        # Also send partner-left event to trigger modal on partner's side
        await sio.emit("partner-left", {
            "username": username,
            "message": f"{username} has left the collaboration room"
        }, room=room, skip_sid=sid)
        
        logger.info(f"[{id(sio)}] {username} left room: {room}")

    @sio.event
    async def disconnect(sid):
        logger.info(f"[{id(sio)}] User disconnected: {sid}")
        print(f"[{id(sio)}] User disconnected: {sid}")

# Register handlers on both servers
register_handlers(sio_root)
register_handlers(sio_prefixed)

# --- Aiohttp apps: root app + prefixed subapp (NO middleware) ---
root_app = web.Application()
prefixed_app = web.Application()

# Attach Socket.IO servers (note: different server objects; same Redis manager)
sio_root.attach(root_app, socketio_path="socket.io")
sio_prefixed.attach(prefixed_app, socketio_path="socket.io")

# Health on both
root_app.router.add_get("/health", health_check)
root_app.router.add_get("/health/", health_check)
prefixed_app.router.add_get("/health", health_check)
prefixed_app.router.add_get("/health/", health_check)

# Mount the prefixed subapp
if SERVICE_PREFIX:
    root_app.add_subapp(SERVICE_PREFIX, prefixed_app)

# Startup sequence
async def startup_sequence(app: web.Application):
    await init_redis()
    await cleanup_on_startup()

root_app.on_startup.append(startup_sequence)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8006))
    web.run_app(root_app, port=port)
