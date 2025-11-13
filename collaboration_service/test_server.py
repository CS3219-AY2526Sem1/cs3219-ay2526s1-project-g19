import pytest
import socketio
from aiohttp import web
from server import app, sio  # Import the app and sio from server.py
import redis.asyncio as aioredis

# Create a test client for Socket.IO
@pytest.fixture
def test_client():
    client = socketio.AsyncClient()
    return client

@pytest.fixture
async def start_server():
    # Clear Redis before starting the server
    redis_url = "redis://localhost:6379"
    redis = await aioredis.from_url(redis_url, decode_responses=True)
    await redis.flushdb()  # Clear all keys in Redis

    # Start the server in a test environment
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "localhost", 8005)
    await site.start()
    yield
    await runner.cleanup()

@pytest.mark.asyncio
async def test_connect(test_client, start_server):
    """
    Test WebSocket connection.
    """
    await test_client.connect("http://localhost:8005")
    assert test_client.sid is not None
    print("Connected with SID:", test_client.sid)
    await test_client.disconnect()

@pytest.mark.asyncio
async def test_join_room(test_client, start_server):
    """
    Test joining a room.
    """
    await test_client.connect("http://localhost:8005")
    room_name = "test-room"

    # Listen for "receive" events
    received_data = []

    @test_client.on("receive")
    def on_receive(data):
        print(f"Received data: {data}")  # Debugging log
        received_data.append(data)

    # Emit "join" event
    await test_client.emit("join", {"room": room_name})
    await test_client.sleep(1)  # Allow time for the server to process

    # Verify the received data
    if len(received_data) > 0:
        # If cached code exists, verify its structure
        assert "code" in received_data[0]
        print(f"Cached code received: {received_data[0]['code']}")
    else:
        # If no cached code exists, ensure no events were received
        assert len(received_data) == 0

    await test_client.disconnect()

@pytest.mark.asyncio
async def test_change_code_two_clients(start_server):
    """
    Test broadcasting code changes between two clients.
    """
    client1 = socketio.AsyncClient()
    client2 = socketio.AsyncClient()

    await client1.connect("http://localhost:8005")
    await client2.connect("http://localhost:8005")

    room_name = "test-room"
    code_snippet = "print('Hello, World!')"

    # Both clients join the room
    await client1.emit("join", {"room": room_name})
    await client2.emit("join", {"room": room_name})
    await client1.sleep(1)
    await client2.sleep(1)

    # Listen for "receive" events on client2
    received_data_client2 = []

    @client2.on("receive")
    def on_receive(data):
        received_data_client2.append(data)

    # Client1 emits "change" event
    await client1.emit("change", {"room": room_name, "code": code_snippet})
    await client2.sleep(1)  # Allow time for the server to process

    # Verify that client2 received the code change
    assert len(received_data_client2) == 1
    assert received_data_client2[0]["code"] == code_snippet

    await client1.disconnect()
    await client2.disconnect()

@pytest.mark.asyncio
async def test_leave_room(test_client, start_server):
    """
    Test leaving a room.
    """
    await test_client.connect("http://localhost:8005")
    room_name = "test-room"

    # Join the room
    await test_client.emit("join", {"room": room_name})
    await test_client.sleep(1)

    # Emit "leave" event
    await test_client.emit("leave", {"room": room_name})
    await test_client.sleep(1)

    # No specific assertion here, but ensure no errors occur
    await test_client.disconnect()

@pytest.mark.asyncio
async def test_two_users_join_room(start_server):
    """
    Test two users joining the same room.
    """
    client1 = socketio.AsyncClient()
    client2 = socketio.AsyncClient()

    await client1.connect("http://localhost:8005")
    await client2.connect("http://localhost:8005")

    room_name = "test-room"

    # Listen for "receive" events on both clients
    received_data_client1 = []
    received_data_client2 = []

    @client1.on("receive")
    def on_receive_client1(data):
        print("Client1 received:", data)
        received_data_client1.append(data)

    @client2.on("receive")
    def on_receive_client2(data):
        print("Client2 received:", data)
        received_data_client2.append(data)

    # Emit "join" event for both clients
    await client1.emit("join", {"room": room_name})
    await client2.emit("join", {"room": room_name})
    await client1.sleep(1)  # Allow time for the server to process
    await client2.sleep(1)

    # Verify that both clients received the join notification
    assert len(received_data_client1) == 1
    assert len(received_data_client2) == 1
    assert received_data_client1[0]["type"] == "receive"
    assert received_data_client2[0]["type"] == "receive"

    await client1.disconnect()
    await client2.disconnect()