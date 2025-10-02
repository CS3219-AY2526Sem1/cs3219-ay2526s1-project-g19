# Matching Service Specifications
> M2: Matching Service – responsible for matching users based on some reasonable criteria (e.g., topics and difficulty level of questions, proficiency level of the users, etc.) This service can potentially be developed by offering multiple matching criteria.

The matching service is responsible for matching users based on the below defined criteria:
1. Topic selection (multiselect)
1. Difficulty selection (multiselect): Easy, Medium, Hard (or as defined by Question Service)
1. Language preference (One primary language, *up to* two secondary language)
1. Proficiency level (within +-10%)

## Matching Service API Endpoints
### WebSockets for Informing User Matched
- `ws /api/ws` - Connects to matching service websocket. To be used **before** calling `POST /api/match`.
    - Input: `user_id: str`
    - `ws://localhost:8001/api/ws?user_id=${userId}`
    - Message:
    ```json
        {
            "status": "success" | "timeout",
            "matched_user_id": "3fa85f64-5717-4562-b3fc-2c963f66afa5" | None,
            "criteria": {
                "topic": "string",
                "difficulty": "string",
                "langugage": "string"
            } | None
        }
    ```

### Basic matching
- `POST /api/match` - Adds the user to the matching queue with the given criteria
    - Used by: Frontend - Matching page
    - Pre-condition: A websocket with the same user id has to be connected and ready before calling this method
    - Input: (as request body)
        ```json
        {
            "user_id": "3fa85f64-5717-4562-b3fc-2c963f66afa5",
            "criteria": {
                "topics": [
                "string"
                ],
                "difficulty": [
                "string"
                ],
                "primary_lang": "string",
                "secondary_lang": [],
                "proficiency": 0
            }
            }
        ```
    - Response:
        - `201 Created`: User successfully added into queue - returns queue id
        - `400 Bad Request`: Invalid/Malformed input
        - `409 Conflict`: User already in queue
    - Output/Response body:
        ```python
        {
            status: Status,
            queue_id: UUID,
            timeout: int
        }
        ```
    - Possible pushed events:
        - UserMatched event:
            ```python
            {
                user_a: {id: UUID, proficiency: int},
                user_b: {id: UUID, proficiency: int},
                topic: Topic,
                difficulty: Difficulty,
                language: Language
            }
            ```
        - Timeout event
- `GET /api/match/status` - Checks the matching status of the user (Only if polling driven approach is used)
    - Used by: Frontend - Finding match page
    - Input:
        - `user_id: UUID **or** queue_id: UUID (up for discussion)`
    - Response:
        - `200 OK`: Returns the matching status of the user
        - `400 Bad Request`: Invalid/Malformed input
        - `404 Not Found`: User not in queue
    - Output/Response body:
        - `{ status: Status, time_remaining: int }`
- `DELETE /api/match` - Removes the user from the matching queue
    - Used by: Frontend - Finding match page - Cancel button
    - Input:
        - `user_id: UUID **or** queue_id: UUID (up for discussion)`
    - Response:
        - `200 OK`: User successfully removed from queue
        - `400 Bad Request`: Invalid/Malformed input
        - `404 Not Found`: User not in queue
### Lobby feature
- `GET /api/lobbies` - Retrieves available matching lobbies
    - Used by: Frontend - Finding match page
    - Input: None
    - Response:
        - `200 OK` - Returns list of lobbies
        - `400 Bad Request` - Invalid/Malformed input
    - Output/Response body:
        ```python
        {
            lobbies: [
                {
                    lobby_id: UUID,
                    topic: list[Topic],
                    difficulty: list[Difficulty],
                    primary_lang: Language | None,
                    secondary_lang: list[Language],
                    time_remaining: int # in seconds
                },
                ...
            ]
        }

        ```
