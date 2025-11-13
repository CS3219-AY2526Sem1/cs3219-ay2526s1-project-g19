# Chat Service

A real-time chat service implementation using Socket.IO and Redis for the PeerPrep application.

## Overview

The chat service enables real-time communication between users in interview rooms. It uses:
- Socket.IO for WebSocket connections
- Redis for message persistence
- aiohttp for the web server

## Architecture

### WebSocket Events

1. **connect**
   - Triggered when a client connects to the WebSocket server
   - Logs the connection with the socket ID

2. **join**
   - Parameters: `username`, `room`
   - Adds user to a specific chat room
   - Sends chat history to the joining user
   - Broadcasts join notification to other users in the room

3. **send**
   - Parameters: `username`, `room`, `message`
   - Stores message in Redis
   - Broadcasts message to all users in the room

4. **leave**
   - Parameters: `username`, `room`
   - Removes user from the room
   - Broadcasts leave notification to other users

5. **disconnect**
   - Triggered when a client disconnects
   - Logs the disconnection

### Redis Data Structure

Messages are stored in Redis using Lists:

```
Key format: chat_history_{room_id}
Value: JSON strings containing message data
```

Message Format:
```json
{
    "message": "Hello World",
    "username": "User123",
    "__createdtime__": 1632140800000
}
```

### Message History

- Each room maintains its own message history
- Last 100 messages are kept per room
- Messages are stored as JSON strings in Redis lists
- Messages include:
  - Content
  - Sender username
  - Timestamp

## Running the Service

1. Start Redis server:
```bash
redis-server
```
or use the redis service on docker

2. Start the chat service:
```bash
python server.py
```
or use the service on docker

The service will run on port 8006.

## WebSocket Events Reference

### Client to Server

```javascript
// Join a room
socket.emit('join', { username: 'User123', room: 'room-id' })

// Send a message
socket.emit('send', {
    room: 'room-id',
    username: 'User123',
    message: 'Hello World'
})

// Leave a room
socket.emit('leave', { username: 'User123', room: 'room-id' })
```

### Server to Client

```javascript
// Receive messages (including system messages)
socket.on('receive', (data) => {
    // data.message - message content
    // data.username - sender's username
    // data.__createdtime__ - timestamp
})

// Error handling
socket.on('error', (data) => {
    // data.message - error message
})
```
