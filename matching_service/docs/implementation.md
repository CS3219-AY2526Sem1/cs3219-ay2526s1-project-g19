# Implementation Details

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


## Adding to matching queue
Redis stores all information.
1. General queue: stores user id and join queue time, used for deconflicting matches to implement FIFO
1. queue:{criteria}:{criteria_name}