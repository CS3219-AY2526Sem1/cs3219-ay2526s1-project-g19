# Session Service - Database Schema & API Overview

## API Endpoints Overview

### History Management
- `GET /api/session` - Get current active session for user
    - Input: `user_id: UUID`
    - Output:
        ```
            class Session:
                id: UUID
                started_at: datetime
                ended_at: datetime | None
                question_id: UUID
                language: str
        ```
- `POST /api/session/end` - Get specific history entry details

## Event Handling
- QuestionChosen Event - Creates and stores session id, publishes SessionCreated event
- SessionEnd Event - Stores session metadata in SessionMetadata Table

## Database Schema

### Session Table
```sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    language VARCHAR(10) NOT NULL
);

CREATE TABLE session_users (
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    PRIMARY KEY (session_id, user_id)
);

CREATE TABLE session_metadata (
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    question_id UUID,
    time_taken BIGINT,
    attempts INT,
    PRIMARY KEY (session_id)
);
```
