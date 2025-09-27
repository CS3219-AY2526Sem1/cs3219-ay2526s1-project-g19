import os
import socketio
from aiohttp import web
import logging
import redis.asyncio as aioredis

logger = logging.getLogger(__name__)

EXPIRY_TIME = 1800  # 30 minutes

# Create a Socket.IO server
sio = socketio.AsyncServer(cors_allowed_origins="*")
app = web.Application()
sio.attach(app)

# Initialize Redis connection
redis = None

async def init_redis():
    global redis
    redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
    redis = await aioredis.from_url(redis_url, decode_responses=True)
    logger.info(f"Connected to Redis at {redis_url}")

@sio.event
async def connect(sid, environ):
    """
    Handle a new WebSocket connection.
    """
    logger.info(f"WebSocket: connect called for SID {sid}")
    print(f"WebSocket: connect called for SID {sid}")

@sio.event
async def join(sid, data):
    """
    Handle a user joining a room.
    """
    room = data.get("room")
    if not room:
        await sio.emit("error", {"message": "room is required"}, to=sid)
        return

    await sio.enter_room(sid, room)
    logger.info(f"SID {sid} joined room {room}")
    print(f"SID {sid} joined room {room}")

    # Send cached code if it exists
    cache_key = f"code_{room}"
    cached_code = await redis.get(cache_key)
    if cached_code:
        print(f"Found cached code {cached_code} for room {room}, sending to SID {sid}")
        await sio.emit("receive", {"type": "receive", "code": cached_code}, to=sid)

@sio.event
async def change(sid, data):
    """
    Handle code changes and broadcast them to the room.
    """
    print(f"Received change event from SID {sid} for room {data.get('room')} with code: {data.get('code')}")
    room = data.get("room")
    code = data.get("code")
    if not room or code is None:
        await sio.emit("error", {"message": "room and code are required"}, to=sid)
        return

    # Cache the new code in Redis
    cache_key = f"code_{room}"
    await redis.setex(cache_key, EXPIRY_TIME, code)

    # Broadcast the code change to others in the room, except the sender
    await sio.emit("receive", {"type": "receive", "code": code}, room=room, skip_sid=sid)
    logger.info(f"Code change broadcasted to room {room} by SID {sid}")

@sio.event
async def leave(sid, data):
    """
    Handle a user leaving a room.
    """
    room = data.get("room")
    if not room:
        await sio.emit("error", {"message": "room is required"}, to=sid)
        return

    await sio.leave_room(sid, room)
    logger.info(f"SID {sid} left room {room}")
    print(f"SID {sid} left room {room}")

@sio.event
async def disconnect(sid):
    """
    Handle WebSocket disconnection.
    """
    logger.info(f"WebSocket: disconnect called for SID {sid}")
    print(f"WebSocket: disconnect called for SID {sid}")

# Run the server
if __name__ == "__main__":
    app.on_startup.append(lambda app: init_redis())  # Initialize Redis on startup
    web.run_app(app, port=8005)
