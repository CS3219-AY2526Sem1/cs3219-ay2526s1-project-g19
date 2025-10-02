# History Service - Database Schema & API Overview

## Database Schema

# History Service - Database Schema & API Overview

## Database Schema

### History Table
```sql
CREATE TABLE history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    collaborator_id UUID NOT NULL REFERENCES users(user_id),
    session_id UUID NOT NULL,
    question_id UUID NOT NULL REFERENCES questions(question_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints Overview

### History Management
- `GET /api/history` - Get all history entries for the authenticated user
- `GET /api/history/{history_id}` - Get specific history entry details
- `POST /api/history` - Create a new history entry when a session starts
- `DELETE /api/history/{history_id}` - Delete a history entry (optional)
