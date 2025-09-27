# Collaboration Service - Database Schema & API Overview

## Database Schema

### Session Table
```sql
CREATE TABLE sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_1 UUID NOT NULL REFERENCES users(user_id),
    user_id_2 UUID NOT NULL REFERENCES users(user_id),
    question_id UUID NOT NULL REFERENCES questions(question_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Chat History Table
```sql
CREATE TABLE chat_history (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(user_id),
    message_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Code History Table
```sql
CREATE TABLE code_history (
    code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(user_id),
    code_snapshot TEXT NOT NULL, -- full code or diff JSON
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Cursor Positions Table
```sql
CREATE TABLE cursor_positions (
    cursor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id),
    line_number INT,
    column_number INT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```


## API Endpoints Overview

### Collaboration Session
- `POST /api/session/create` - Used when two users are matched to the same session - Create new collaboration session
- `DELETE /api/session/{session_id}` - Used when collaborators in the session choose to end the session - Deletes the session by session id

### Chat History
- `GET /api/session/{session_id}/chat` - Fetch chat histroy of a session
- `POST /api/session/{session_id}/chat` - Send a new chat message

### Code History (If persisted)
- `GET /api/session/{session_id}/code` - Fetch code history for a session
- `POST /api/session/{session_id}/code` - Push code snapshot/diff

### Cursor Positions
- `GET /api/session/{session_id}/cursor` - Get both users' current cursor positions
- `PUT /api/session/{session_id}/cursor` - Update current cursor position of a user

