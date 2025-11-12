# Question Service - Database Schema & API Overview

## Database Schema

### Questions Table (as implemented)

```sql
CREATE TABLE questions (
    question_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    statement_md TEXT NOT NULL,
    assets JSONB NOT NULL DEFAULT '[]',
    difficulty TEXT NOT NULL, -- one of: easy|medium|hard
    topics JSONB NOT NULL DEFAULT '[]',
    company_tags JSONB NOT NULL DEFAULT '[]',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    search_tsv TSVECTOR,
    examples JSONB NOT NULL DEFAULT '[]',
    constraints JSONB NOT NULL DEFAULT '[]'
);
```

### Question Statistics

```sql
CREATE TABLE question_stats (
    question_id UUID PRIMARY KEY REFERENCES questions(question_id) ON DELETE CASCADE,
    views BIGINT NOT NULL DEFAULT 0,
    attempts BIGINT NOT NULL DEFAULT 0,
    solved BIGINT NOT NULL DEFAULT 0,
    last_activity_at TIMESTAMPTZ
);
```

### Question Solutions

```sql
CREATE TABLE question_solutions (
    solution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES questions(question_id) ON DELETE CASCADE,
    language TEXT NOT NULL,
    solution_md TEXT NOT NULL,
    author UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (question_id, language)
);
```

### Question Score

```sql
CREATE TABLE question_scores (
    question_id UUID PRIMARY KEY REFERENCES questions(question_id) ON DELETE CASCADE,
    attainable_score INTEGER NOT NULL,
    model_version TEXT NOT NULL,
    computed_at TIMESTAMPTZ NOT NULL
);
```

## API Endpoints Overview

### 3.1 Health

- `GET /health` — Service health check (200, `{ "status": "healthy" }`)

### 3.2 Questions (CRUD + list)

- `GET /api/questions` — List questions (paginated) with filters/sorting
- `GET /api/questions/{id}` — Retrieve a question by UUID
- `POST /api/questions` — Create a question
- `PUT /api/questions/{id}` — Full update
- `PATCH /api/questions/{id}` — Partial update
- `DELETE /api/questions/{id}` — Delete

**Query params**

- `topic=<str>` (multi) — filter by topic (e.g. `topic=Array&topic=Graph`)
- `difficulty=easy|medium|hard`
- `status=active|inactive|true|false|1|0`
- Sorting:
  - `sort=newest|created_at|difficulty|percentage_solved|popularity|topic|category`
  - `order=asc|desc` (default `desc`)
- Pagination:
  - `page=<int>` (default 1)
  - `page_size=<1..100>` (default 20)
- Random:
  - `random=true|1` or `sort=random` — random order; if no limit/page_size, defaults to 1 item

Response shape for list is full-detail serializer per item (includes fields such as `question_id`, `title`, `statement_md`, `assets`, `topics`, `difficulty`, `examples`, `constraints`, and nested `stats`/`score` if present).

### 3.3 Reference Data

- `GET /api/topics` — returns `{ "topics": [ ... ] }`
- `GET /api/difficulty` — returns `{ "difficulties": ["easy","medium","hard"] }`

These are also published to Kafka on service start and on question changes.

### 3.4 Solutions / Hints / Related

Currently not exposed as standalone endpoints in this service (solutions are part of the data model).

### 3.5 Docs

- `GET /api/schema/` — OpenAPI schema (JSON)
- `GET /api/docs/` — Swagger UI
- `GET /api/redoc/` — ReDoc UI

Notes:
- Endpoints like `pick-for-session`, `catalog`, or `/runs` are not implemented at present and have been removed from this spec for accuracy.
