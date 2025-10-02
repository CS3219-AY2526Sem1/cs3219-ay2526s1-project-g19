# Collaboration Service

A real-time collaborative code editor service using Socket.IO and Redis for the PeerPrep application.

## Overview

The collaboration service enables real-time code synchronization between users in interview rooms. It uses:
- Socket.IO for WebSocket connections
- Redis for code persistence
- aiohttp for the web server

## Architecture

### WebSocket Events

1. **connect**
   - Triggered when a client connects to the WebSocket server
   - Assigns a unique socket ID (SID) to the client
   - Logs the connection

2. **join**
   - Parameters: `room`
   - Adds user to a specific coding room
   - Retrieves and sends cached code if it exists
   - Uses Redis key format: `code_{room}`

3. **change**
   - Parameters: `room`, `code`
   - Stores updated code in Redis with 30-minute expiry
   - Broadcasts code changes to all other users in the room
   - Skips sending back to the original sender

4. **leave**
   - Parameters: `room`
   - Removes user from the specified room
   - Logs the departure

5. **disconnect**
   - Triggered when a client disconnects
   - Cleans up resources
   - Logs the disconnection

### Redis Implementation

```
Key format: code_{room_id}
Value: Current code state as string
Expiry: 30 minutes (1800 seconds)
```

Example:
```
KEY: code_room123
VALUE: "print('Hello, World!')"
TTL: 1800
```

## Running the Service

1. Start Redis server:
```bash
redis-server
```
or use the redis server on docker

2. Start the collaboration service:
```bash
python server.py
```
or use the service on docker

The service will run on port 8005.

## WebSocket Events Reference

### Client to Server

```javascript
// Join a room
socket.emit('join', { room: 'room-id' })

// Send code changes
socket.emit('change', {
    room: 'room-id',
    code: 'print("Hello World")'
})

// Leave a room
socket.emit('leave', { room: 'room-id' })
```

### Server to Client

```javascript
// Receive code updates
socket.on('receive', (data) => {
    // data.type - "receive"
    // data.code - updated code content
})

// Error handling
socket.on('error', (data) => {
    // data.message - error message
})
```
