# User Service - Database Schema & API Overview

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL, -- encrypted with AES-256
    email_hash VARCHAR(64) UNIQUE NOT NULL, -- for uniqueness checks
    password_hash VARCHAR(255) NOT NULL, -- bcrypt hashed
    display_name VARCHAR(50) NOT NULL,
    bio TEXT CHECK(length(bio) <= 500),
    profile_picture_url VARCHAR(500),
    email_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE, -- for soft delete
    proficiency_score INTEGER DEFAULT 1200, -- ELO-based
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    profile_updated_at TIMESTAMP,
    last_login_at TIMESTAMP
);
```

### User Sessions Table
```sql
CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    refresh_token_hash VARCHAR(255) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);
-- NOTE: Can leverage Django's built-in sessions framework instead
-- Django provides: django_session table with session_key, session_data, expire_date
```

### Email Verification Tokens Table
```sql
CREATE TABLE email_verification_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- NOTE: Can use Django's built-in token generation utilities
-- Or leverage third-party packages like django-rest-auth
```

### Password Reset Tokens Table
```sql
CREATE TABLE password_reset_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- NOTE: Django has built-in password reset functionality
-- Can use django.contrib.auth.tokens.default_token_generator
```

### OAuth Accounts Table (Optional)
```sql
CREATE TABLE oauth_accounts (
    oauth_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    provider VARCHAR(20) NOT NULL, -- 'google', 'github'
    provider_user_id VARCHAR(100) NOT NULL,
    provider_email VARCHAR(255),
    linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(provider, provider_user_id)
);
-- NOTE: Can use django-allauth package which handles OAuth providers
-- and provides its own socialaccount_socialaccount table
```

### Rate Limiting Table
```sql
CREATE TABLE rate_limits (
    limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier VARCHAR(100) NOT NULL, -- IP or user_id
    action_type VARCHAR(50) NOT NULL, -- 'login_attempt', 'email_resend', etc.
    attempt_count INTEGER DEFAULT 1,
    window_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    blocked_until TIMESTAMP,
    UNIQUE(identifier, action_type)
);
-- NOTE: Can use django-ratelimit or django-axes packages
-- django-axes provides axes_accessattempt, axes_accesslog tables
```

## API Endpoints Overview

### Authentication & Registration
- `POST /api/auth/register` - Used in Registration Page - Create new user account
- `POST /api/auth/login` - Used in Login Page - Authenticate user and return tokens  
- `POST /api/auth/refresh` - Used across all pages - Refresh expired access token
- `POST /api/auth/logout` - Used in all authenticated pages - Invalidate user session

### Password Management  
- `POST /api/auth/forgot-password` - Used in Forgot Password Page - Send password reset email
- `POST /api/auth/reset-password` - Used in Password Reset Page - Reset password with token

### Email Verification
- `POST /api/auth/verify-email` - Used in Email Verification Page - Verify user email address
- `POST /api/auth/resend-verification` - Used in Profile Page/Dashboard - Resend verification email

### User Profile Management
- `GET /api/users/me` - Used in Profile Page/Dashboard/Edit Profile Page - Get current user's profile
- `PUT /api/users/profile` - Used in Edit Profile Page - Update user profile information  
- `DELETE /api/users/me` - Used in Account Settings Page - Delete user account

### OAuth Integration (Optional)
- `POST /api/auth/oauth/google` - Used in Login/Registration Page - Authenticate with Google
- `POST /api/auth/oauth/github` - Used in Login/Registration Page - Authenticate with GitHub

### User Statistics (for other services)
- `GET /api/users/attempts/summary` - Used in Profile Page - Get question attempt statistics
- `GET /api/users/collaborationsessions` - Used in Profile Page - Get collaboration session history  
- `GET /api/users/proficiency` - Used in Profile Page - Get proficiency score and history

### Session Validation (for other microservices)
- `GET /api/auth/validate-token` - Used by other services - Validate JWT token and get user info
- `POST /api/auth/check-session` - Used by other services - Check if user session is active