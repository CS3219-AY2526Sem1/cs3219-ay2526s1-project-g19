# Question Service - Database Schema & API Overview

## Database Schema

### Questions Table

```sql
CREATE TABLE questions (
    question_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL, -- URL-safe
    title TEXT NOT NULL,
    statement_md TEXT NOT NULL, -- Markdown
    assets JSONB NOT NULL DEFAULT '[]',
    difficulty difficulty_level NOT NULL,
    topics TEXT[] NOT NULL DEFAULT '{}',
    company_tags TEXT[] NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    search_tsv TSVECTOR
);
```

### Question Popularity/progress

```sql
CREATE TABLE question_stats (
    question_id UUID PRIMARY KEY REFERENCES questions(question_id) ON DELETE CASCADE,
    views BIGINT NOT NULL DEFAULT 0,
    attempts BIGINT NOT NULL DEFAULT 0,
    solved BIGINT NOT NULL DEFAULT 0,
    last_activity_at TIMESTAMPTZ,
    percentage_solved REAL GENERATED ALWAYS AS
    (CASE WHEN attempts > 0 THEN (solved::REAL/attempts)\*100 ELSE 0 END) STORED
);
```

### Question solutions

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

### Question score

```sql
CREATE TABLE question_scores (
    question_id UUID PRIMARY KEY REFERENCES questions(question_id) ON DELETE CASCADE,
    attainable_score INTEGER NOT NULL,
    model_version TEXT NOT NULL,
    computed_at TIMESTAMPTZ NOT NULL
);
```

## API Endpoints Overview

### 3.1 CRUD

- `POST /api/questions` - Create question
- `PUT /api/questions/{id}` - Update question
- `DELETE /api/questions/{id}` - Delete question
- `GET /api/questions/{id}` - Retreive the full question which consists content, media, stats, solutions, hints, score

### 3.2 Listing / Filtering / Sorting

- `GET /api/questions` - get list of questions based on query params

**Query params**

- `topic=arrays&topic=graphs` (multi)
- `difficulty=easy|medium|hard`
- `popularity_min=<int>` (by attempts)
- `solved_by_user=true|false`
- `sort=newest|difficulty|percentage_solved|popularity|topic`
- `order=asc|desc` (default `desc`)
- `page=<int>` (default 1), `page_size=<1..100>` (default 20)
- `fields=title,topics,difficulty,percentage_solved` (sparse fieldsets)

### 3.3 Search

- `GET /api/questions/search?q=<text>&prefix=true&stem=true` - question search based on full-text search
- `GET /api/questions/search/regex?field=title&re=^Two.*` - Question search via Advanced regex search

### 3.4 Solutions / Hints / Related

- `POST /api/questions/{id}/runs` - Submit code for evaluation on the question’s official test suite
- `GET /api/questions/{id}/runs/{run_id}` - Fetch the result of a code run and Returns normalized outcome and structured results

### 3.5 Session & Cross‑Service

#### For Matching Service

- `POST /api/questions:pick-for-session` - Select a question given constraints derived from match criteria (topics, difficulty, optional seed/exclusions).
- `GET /api/questions/catalog?fields=id,title,difficulty,topics,popularity` - Lightweight catalog slice to aid match-time filtering or preselection. |

#### For Collaboration Service

- `GET /api/questions/{id}?fields=id,title,statement_md,assets` - Fetch render-ready question content for the coding room once a session is created via Collaboration Service (`POST /api/session/create`).
