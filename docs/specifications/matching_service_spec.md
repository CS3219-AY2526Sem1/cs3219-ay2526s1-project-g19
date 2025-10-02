# Matching Service Specifications
> M2: Matching Service – responsible for matching users based on some reasonable criteria (e.g., topics and difficulty level of questions, proficiency level of the users, etc.) This service can potentially be developed by offering multiple matching criteria.

The matching service is responsible for matching users based on the below defined criteria:
1. Topic selection (multiselect)
1. Difficulty selection (multiselect): Easy, Medium, Hard (or as defined by Question Service)
1. Language preference (One primary language, *up to* two secondary language)
1. Proficiency level (within +-10%)

## Implementation Options for Matching
### Queue Architecture
1. Simple database-based queue
    - Pros: Simple implementation, minimal techstack, fault tolerant, vertical/horizontal scaling
    - Cons: Low performance compared to in-memory database
1. In-memory database such as Redis
    - Pros: Significant improvement in performance, vertical/horizontal scaling
    - Cons: Lack durability
### Communication Architecture
1. Intervaled polling
    - Pros: Simple to implement
    - Cons: Not real-time, performance is dependent on polling interval, expensive
1. Event-driven
    - Pros: Fit for microservice, scalable, reliable, real-time, loose coupling
    - Cons: Complex implementation, slightly higher latency compared to WebSockets
1. WebSockets
    - Pros: Lowest latency, no need for broker/middleware
    - Cons: Increased coupling between services

## Quality Attributes Trade Off
### Prioritized Quality Attributes
1. Performance (Responsiveness): Users should get real-time update when they are matched
1. Scalability: Matching service should support increasing numbers of maximum/average expected user's using the matching service

### Trade-offs
Durability is less prioritized as users are only maintained in the matching queue for 1 minute before matching time out and being removed from the queue. This means that the expected number of users in the queue at any point in time should be low, so a drop of this set of users on server crash can be tolerated. Moreover, recovery is simple: users can just rejoin the queue.

## Implementation Choice Based on Selected Quality Attributes
### Queue Architecture
The matching service will be implemented using Redis, an in-memory key-value database used as a distributed cache. This optimizes performance compared to a database-backed implementation. Since queue state is ephemeral, some minor loss on server fault can be tolerated. Durability can be stregthened using RDB (snapshotting) or AOF (Append-Only File), further limiting loss on server fault.
### Communication Architecture
HTTP/REST APIs will be used for stateless calls, while WebSockets will be used for event messages. WebSockets is chosen over message broker as the main use case of the matching service is communication with frontend, which provides better support for WebSockets compared to pub/sub message broker architecture. WebSockets over provides better performance.
### Web Framework
FastAPI will be chosen over Django. Django is boasted to be a "batteries-included" framework, including templating, admin dashboards, ORM, and so on. This is not required by matching service as it is not database-backed. Including of these "batteries" will increase unnecessary dependencies. FastAPi is better fitted for this use case and proves to be more performant with its asynchronous capabilities.

## Matching Service API Endpoints
### Basic matching
- `POST /api/match` - Adds the user to the matching queue with the given criteria
    - Used by: Frontend - Matching page
    - Input: (as request body)
        ```python
        {
            user_id: UUID,
            topics: list[Topic] = [], # empty list implies all topics
            difficulty: list[Difficulty] = [], # empty list implies all difficulty
            primary_lang: Language | None = None, # None implies no language preference
            secondary_lang: list[Language] = [], # empty list implies no language preference
            proficiency: int
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
- `GET /api/match` - Checks the matching status of the user (Only if polling driven approach is used)
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
