import pytest
import asyncio
import json
import time
from unittest.mock import patch
from aiohttp.test_utils import AioHTTPTestCase

# Configure pytest-asyncio
pytestmark = pytest.mark.asyncio

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(autouse=True)
async def setup_test():
    """Setup for each test."""
    from server import init_redis, cleanup_on_startup
    await init_redis()
    await cleanup_on_startup()

class TestChatService(AioHTTPTestCase):

    async def get_application(self):
        """Create test application."""
        from server import app
        return app

    async def setUpAsync(self):
        """Set up test environment."""
        await super().setUpAsync()
        from server import init_redis, cleanup_on_startup
        await init_redis()
        await cleanup_on_startup()

async def test_user_join_room():
    """Test user joining a room."""
    from server import join
    
    # Mock sio.emit and sio.enter_room
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room') as mock_enter:
        
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Verify room entry and notification
        mock_enter.assert_called_once_with("user1", "room1")
        assert mock_emit.called
        
        # Check for join notification
        calls = mock_emit.call_args_list
        join_notification = None
        for call in calls:
            if len(call[0]) > 1 and isinstance(call[0][1], dict):
                if "Alice has joined" in call[0][1].get("message", ""):
                    join_notification = call[0][1]
                    break
        
        assert join_notification is not None
        assert join_notification["username"] == "ChatBot"

async def test_send_and_receive_message():
    """Test sending and receiving messages."""
    from server import join, send
    
    # First join a room
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'):
        
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Clear previous calls
        mock_emit.reset_mock()
        
        # Send a message
        await send("user1", {
            "username": "Alice",
            "room": "room1",
            "message": "Hello, World!"
        })
        
        # Check that message was broadcast
        broadcast_calls = [call for call in mock_emit.call_args_list 
                         if call[0][0] == "receive" and len(call[0]) > 1]
        
        assert len(broadcast_calls) >= 1
        message_data = broadcast_calls[-1][0][1]
        assert message_data["message"] == "Hello, World!"
        assert message_data["username"] == "Alice"
        assert "__createdtime__" in message_data

async def test_message_history_persistence():
    """Test that message history is stored and retrieved."""
    from server import join, send
    
    room = "test_room"
    
    # Join room and send messages
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'):
        
        # User joins
        await join("user1", {
            "username": "Alice",
            "room": room
        })
        
        # Send multiple messages
        messages = ["Message 1", "Message 2", "Message 3"]
        for msg in messages:
            await send("user1", {
                "username": "Alice",
                "room": room,
                "message": msg
            })
        
        # Clear mock and simulate new user joining
        mock_emit.reset_mock()
        
        await join("user2", {
            "username": "Bob",
            "room": room
        })
        
        # Check that history was sent to new user
        history_calls = [call for call in mock_emit.call_args_list 
                       if call[0][0] == "receive" and 
                       call[1].get("to") == "user2"]
        
        # Should have sent 3 history messages
        sent_messages = []
        for call in history_calls:
            if isinstance(call[0][1], dict) and call[0][1].get("username") == "Alice":
                sent_messages.append(call[0][1]["message"])
        
        assert len(sent_messages) == 3
        assert all(msg in sent_messages for msg in messages)

async def test_user_leave_room():
    """Test user leaving a room."""
    from server import join, leave
    
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'), \
         patch('server.sio.leave_room') as mock_leave:
        
        # User joins first
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Clear previous calls
        mock_emit.reset_mock()
        
        # User leaves
        await leave("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Check that user left the room
        mock_leave.assert_called_once_with("user1", "room1")
        
        # Check for leave notification
        leave_calls = [call for call in mock_emit.call_args_list 
                      if call[0][0] == "receive"]
        
        assert len(leave_calls) >= 1
        leave_message = leave_calls[-1][0][1]
        assert "Alice has left" in leave_message["message"]
        assert leave_message["username"] == "ChatBot"

async def test_invalid_join_parameters():
    """Test joining with invalid parameters."""
    from server import join
    
    with patch('server.sio.emit') as mock_emit:
        
        # Missing username
        await join("user1", {
            "room": "room1"
        })
        
        # Missing room
        await join("user1", {
            "username": "Alice"
        })
        
        # Empty parameters
        await join("user1", {})
        
        # Check that error messages were sent
        error_calls = [call for call in mock_emit.call_args_list 
                      if call[0][0] == "error"]
        
        assert len(error_calls) == 3
        for call in error_calls:
            error_message = call[0][1]["message"]
            assert "required" in error_message

async def test_invalid_send_parameters():
    """Test sending messages with invalid parameters."""
    from server import send
    
    with patch('server.sio.emit') as mock_emit:
        
        # Missing message
        await send("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Missing username
        await send("user1", {
            "room": "room1",
            "message": "Hello"
        })
        
        # Missing room
        await send("user1", {
            "username": "Alice",
            "message": "Hello"
        })
        
        # Check that error messages were sent
        error_calls = [call for call in mock_emit.call_args_list 
                      if call[0][0] == "error"]
        
        assert len(error_calls) == 3

async def test_message_limit():
    """Test that only last 100 messages are kept."""
    from server import join, send, redis_client
    
    room = "test_room"
    
    with patch('server.sio.emit'), \
         patch('server.sio.enter_room'):
        
        # Join room
        await join("user1", {
            "username": "Alice",
            "room": room
        })
        
        # Send 105 messages
        for i in range(105):
            await send("user1", {
                "username": "Alice",
                "room": room,
                "message": f"Message {i}"
            })
        
        # Check Redis directly
        cache_key = f"chat_history_{room}"
        history_length = await redis_client.llen(cache_key)
        
        # Should only have 100 messages
        assert history_length == 100
        
        # Check that the oldest messages were removed
        history = await redis_client.lrange(cache_key, 0, -1)
        first_message = json.loads(history[0])
        last_message = json.loads(history[-1])
        
        # First message should be "Message 5" (0-4 were trimmed)
        assert first_message["message"] == "Message 5"
        # Last message should be "Message 104"
        assert last_message["message"] == "Message 104"

async def test_multiple_users_same_room():
    """Test multiple users in the same room."""
    from server import join
    
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'):
        
        # First user joins
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Second user joins
        await join("user2", {
            "username": "Bob",
            "room": "room1"
        })
        
        # Both should have received join notifications
        join_calls = [call for call in mock_emit.call_args_list 
                     if call[0][0] == "receive" and "joined" in call[0][1].get("message", "")]
        
        assert len(join_calls) >= 2  # At least 2 join notifications

async def test_redis_cleanup_on_startup():
    """Test that Redis is cleaned up on startup."""
    from server import redis_client, cleanup_on_startup
    
    # Add some test data to Redis
    test_room = "test_cleanup_room"
    cache_key = f"chat_history_{test_room}"
    
    # Add a message to Redis
    test_message = {
        "message": "Test message",
        "username": "TestUser",
        "__createdtime__": int(time.time() * 1000)
    }
    await redis_client.rpush(cache_key, json.dumps(test_message))
    
    # Verify message exists
    history_before = await redis_client.llen(cache_key)
    assert history_before > 0
    
    # Run cleanup
    await cleanup_on_startup()
    
    # Verify message was cleaned up
    history_after = await redis_client.llen(cache_key)
    assert history_after == 0

async def test_message_timestamp_format():
    """Test that messages have proper timestamp format."""
    from server import join, send
    
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'):
        
        # Join and send message
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Clear previous calls
        mock_emit.reset_mock()
        
        # Send message
        await send("user1", {
            "username": "Alice",
            "room": "room1",
            "message": "Test message"
        })
        
        # Check message format
        broadcast_calls = [call for call in mock_emit.call_args_list 
                         if call[0][0] == "receive" and len(call[0]) > 1]
        
        assert len(broadcast_calls) >= 1
        message_data = broadcast_calls[-1][0][1]
        
        # Verify timestamp is a number and reasonable (within last minute)
        timestamp = message_data["__createdtime__"]
        assert isinstance(timestamp, int)
        current_time = int(time.time() * 1000)
        assert abs(current_time - timestamp) < 60000  # Within 1 minute

async def test_concurrent_messages():
    """Test handling concurrent messages from multiple users."""
    from server import join, send
    
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'):
        
        # Both users join
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        await join("user2", {
            "username": "Bob",
            "room": "room1"
        })
        
        # Clear previous calls
        mock_emit.reset_mock()
        
        # Send messages concurrently
        tasks = []
        for i in range(5):
            tasks.append(send("user1", {
                "username": "Alice",
                "room": "room1",
                "message": f"Alice message {i}"
            }))
            
            tasks.append(send("user2", {
                "username": "Bob",
                "room": "room1",
                "message": f"Bob message {i}"
            }))
        
        # Wait for all messages to be sent
        await asyncio.gather(*tasks)
        
        # Verify all messages were broadcast
        broadcast_calls = [call for call in mock_emit.call_args_list 
                         if call[0][0] == "receive"]
        
        assert len(broadcast_calls) == 10  # 5 from Alice + 5 from Bob

async def test_full_chat_flow():
    """Test complete chat flow with multiple users."""
    from server import join, send, leave
    
    with patch('server.sio.emit') as mock_emit, \
         patch('server.sio.enter_room'), \
         patch('server.sio.leave_room'):
        
        # User 1 joins
        await join("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # User 2 joins
        await join("user2", {
            "username": "Bob",
            "room": "room1"
        })
        
        # Both users send messages
        await send("user1", {
            "username": "Alice",
            "room": "room1",
            "message": "Hello Bob!"
        })
        
        await send("user2", {
            "username": "Bob",
            "room": "room1",
            "message": "Hi Alice!"
        })
        
        # User 1 leaves
        await leave("user1", {
            "username": "Alice",
            "room": "room1"
        })
        
        # Verify we have the expected number of emit calls
        total_emits = len(mock_emit.call_args_list)
        assert total_emits >= 5  # At least 2 joins + 2 messages + 1 leave

async def test_redis_connection():
    """Test Redis connection and basic operations."""
    from server import redis_client
    
    # Test basic Redis operation
    test_key = "test_key"
    test_value = "test_value"
    
    await redis_client.set(test_key, test_value)
    retrieved_value = await redis_client.get(test_key)
    
    assert retrieved_value == test_value
    
    # Clean up
    await redis_client.delete(test_key)

async def test_connect_disconnect():
    """Test connect and disconnect events."""
    from server import connect, disconnect
    
    # Test connect
    await connect("test_sid", {})  # connect doesn't need data
    
    # Test disconnect
    await disconnect("test_sid")
    
    # These should run without errors
    assert True

if __name__ == "__main__":
    # Run the tests
    pytest.main([__file__, "-v", "--asyncio-mode=auto"])