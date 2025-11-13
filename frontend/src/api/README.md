# API Architecture Documentation

This document explains the API structure, authentication flow, and how to maintain or extend the API layer.

## 📁 Directory Structure

```
src/api/
├── client.ts           # Axios client instances
├── config.ts           # API base URLs and configurations
├── interceptors.ts     # Request/response interceptors (auth, token refresh, response unwrapping)
├── services/
│   └── userService.ts  # User/Auth API endpoints
└── README.md          # This file

src/types/
├── auth.ts            # Authentication-related types
├── user.ts            # User-related types
├── common.ts          # Shared/generic types
└── index.ts           # Type exports

src/contexts/
└── AuthContext.jsx    # Global authentication state management
```

---

## 🔧 Core Components

### 1. **API Configuration** (`config.ts`)

Centralizes all service URLs and common headers.

```typescript
export const API_CONFIGS = {
  user: {
    baseURL: import.meta.env.VITE_USER_SERVICE_URL || 'http://localhost:8004/',
    timeout: 10000,
  },
  // Add more services here...
};

export const COMMON_HEADERS = {
  'Content-Type': 'application/json',
};
```

**Adding a new service:**
```typescript
export const API_CONFIGS = {
  user: { ... },
  question: {
    baseURL: import.meta.env.VITE_QUESTION_SERVICE_URL || 'http://localhost:8005/',
    timeout: 10000,
  },
};
```

---

### 2. **Axios Clients** (`client.ts`)

Creates separate axios instances for each microservice.

```typescript
export const userClient = axios.create({
  ...API_CONFIGS.user,
  headers: COMMON_HEADERS,
});

setupInterceptors(userClient);
```

**Creating a new client:**
```typescript
export const questionClient = axios.create({
  ...API_CONFIGS.question,
  headers: COMMON_HEADERS,
});

setupInterceptors(questionClient);
```

---

### 3. **Interceptors** (`interceptors.ts`)

Handles cross-cutting concerns automatically for all API calls.

#### **Request Interceptor**
- Automatically attaches `Authorization: Bearer {token}` header
- Reads token from `localStorage.getItem('authToken')`

#### **Response Interceptor**
- **Unwraps nested responses**: Converts `response.data.data` → `response.data`
- **Auto token refresh**: On 401 errors, automatically refreshes access token
- **Request queuing**: Prevents duplicate refresh calls during concurrent requests
- **Error handling**: Redirects to login on auth failures

#### **How Auto-Refresh Works:**

```
1. API call fails with 401
2. Check if already refreshing (prevent duplicates)
3. Queue the failed request
4. Call POST /api/auth/refresh/ with refresh token
5. Update tokens in localStorage
6. Retry all queued requests with new token
7. If refresh fails → clear storage, redirect to /login
```

**Key Variables:**
- `isRefreshing`: Boolean flag to prevent concurrent refresh calls
- `failedQueue`: Array of pending requests waiting for token refresh

---

### 4. **Service Layer** (`services/userService.ts`)

Defines all API endpoint functions. Each function returns an axios promise.

```typescript
export const userService = {
  register: (data: RegisterRequest) =>
    userClient.post<RegisterResponse>('api/auth/register/', data),

  login: (data: LoginRequest) =>
    userClient.post<LoginResponse>('api/auth/login/', data),

  verifyToken: () =>
    userClient.get<VerifyTokenResponse>('api/auth/verify-token/'),

  logout: () =>
    userClient.post('api/auth/logout/'),
};
```

**Adding a new endpoint:**
```typescript
export const userService = {
  // ... existing endpoints

  updateProfile: (data: UpdateUserDto) =>
    userClient.put<User>('api/users/profile/', data),
};
```

**Adding a new service:**
```typescript
// services/questionService.ts
import { questionClient } from '../client';

export const questionService = {
  getQuestions: (params: PaginationParams) =>
    questionClient.get<PaginatedResponse<Question>>('api/questions/', { params }),

  getQuestionById: (id: string) =>
    questionClient.get<Question>(`api/questions/${id}/`),
};
```

---

## 🔐 Authentication Flow

### **AuthContext** (`src/contexts/AuthContext.jsx`)

Manages global authentication state using React Context.

#### **State:**
- `user`: Current user object
- `isAuthenticated`: Boolean auth status
- `loading`: Loading state during token verification

#### **Methods:**
- `login(userData, tokens)`: Sets user, stores tokens in localStorage
- `logout()`: Calls backend logout API, clears local state & storage

#### **Token Verification on Mount:**

When the app loads, AuthContext automatically:
1. Checks for `authToken` in localStorage
2. Calls `userService.verifyToken()` to validate with backend
3. If valid → sets user state
4. If invalid → clears storage and redirects to login

```jsx
useEffect(() => {
  const verifyAuth = async () => {
    const token = localStorage.getItem('authToken');
    if (!token) return;

    try {
      const response = await userService.verifyToken();
      setUser(response.data.user);
      setIsAuthenticated(true);
    } catch (error) {
      // Clear invalid tokens
      localStorage.clear();
      setIsAuthenticated(false);
    }
  };

  verifyAuth();
}, []);
```

---

## 🚀 Complete API Request Flow

### **Example: Login Request**

```jsx
// 1. Component calls service
const response = await userService.login({
  email: "user@example.com",
  password: "password123"
});

// 2. Request Interceptor runs
// - Adds Authorization header (if token exists)

// 3. Request sent to backend
// POST http://localhost:8004/api/auth/login/

// 4. Backend responds with:
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": { ... },
    "tokens": { ... },
    "session_profile": { ... }
  }
}

// 5. Response Interceptor runs
// - Unwraps: response.data.data → response.data
// - Now response.data = { user, tokens, session_profile }

// 6. Component receives clean data
const { user, tokens } = response.data;
```

### **Example: Protected API Call with Auto-Refresh**

```jsx
// 1. Component calls protected endpoint
const response = await userService.verifyToken();

// 2. Request Interceptor adds token
// Authorization: Bearer {expired_token}

// 3. Backend responds with 401 Unauthorized

// 4. Response Interceptor catches 401
// - Checks if already refreshing (no)
// - Sets isRefreshing = true
// - Calls POST /api/auth/refresh/
// - Updates tokens in localStorage
// - Retries original request with new token
// - Sets isRefreshing = false

// 5. Original request succeeds with new token
// - Response unwrapped and returned to component
```

---

## 📝 Type Definitions

Types are organized by domain in `src/types/`:

### **auth.ts** - Authentication types
```typescript
export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  user: User;
  tokens: Tokens;
  session_profile: SessionProfile;
}

export interface Tokens {
  access_token: TokenInfo;
  refresh_token: TokenInfo;
}
```

### **user.ts** - User types
```typescript
export interface User {
  id: string;
  email: string;
  display_name: string;
  // ...
}
```

### **common.ts** - Reusable types
```typescript
export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}
```

### **index.ts** - Centralized exports
```typescript
export type { User } from './user';
export type { LoginRequest, LoginResponse } from './auth';
export type { PaginatedResponse } from './common';
```

**Usage:**
```typescript
import type { User, LoginRequest } from '@/types';
```

---

## 🛠️ How to Add a New Feature

### **Example: Add "Get User Profile" Endpoint**

#### **1. Define Types** (`types/user.ts`)
```typescript
export interface UserProfile extends User {
  bio?: string;
  avatar_url?: string;
}
```

#### **2. Export Type** (`types/index.ts`)
```typescript
export type { UserProfile } from './user';
```

#### **3. Add Service Method** (`services/userService.ts`)
```typescript
import type { UserProfile } from '@/types';

export const userService = {
  // ... existing methods

  getProfile: () =>
    userClient.get<UserProfile>('api/users/profile/'),
};
```

#### **4. Use in Component**
```jsx
import { userService } from '@/api/services/userService';

const ProfilePage = () => {
  const [profile, setProfile] = useState(null);

  useEffect(() => {
    const fetchProfile = async () => {
      const response = await userService.getProfile();
      setProfile(response.data); // Already unwrapped by interceptor!
    };
    fetchProfile();
  }, []);

  return <div>{profile?.display_name}</div>;
};
```

---

## 🔒 Security Best Practices

### **Token Storage**
- ✅ Access tokens stored in `localStorage` (short-lived, auto-refresh)
- ✅ Refresh tokens stored in `localStorage`
- ⚠️ For production: Consider `httpOnly` cookies for refresh tokens

### **Token Refresh**
- ✅ Automatic refresh on 401 errors
- ✅ Queue concurrent requests during refresh
- ✅ Clear tokens and redirect on refresh failure

### **Protected Routes**
- ✅ `ProtectedRoute` component checks `isAuthenticated` from AuthContext
- ✅ Backend validates token on every protected request
- ✅ Shows loading state during initial token verification

---

## 📋 Common Patterns

### **Making API Calls in Components**

```jsx
import { useState } from 'react';
import { userService } from '@/api/services/userService';

const MyComponent = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleAction = async () => {
    setLoading(true);
    setError('');

    try {
      const response = await userService.someEndpoint();
      console.log(response.data); // Already unwrapped!
    } catch (err) {
      setError(err.response?.data?.error?.message || 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  return <button onClick={handleAction} disabled={loading}>
    {loading ? 'Loading...' : 'Submit'}
  </button>;
};
```

### **Using AuthContext**

```jsx
import { useAuth } from '@/contexts/AuthContext';

const NavBar = () => {
  const { user, isAuthenticated, logout } = useAuth();

  if (!isAuthenticated) return null;

  return (
    <div>
      <p>Welcome, {user.display_name}</p>
      <button onClick={logout}>Logout</button>
    </div>
  );
};
```

---

## 🐛 Debugging Tips

### **Check Token in DevTools**
```javascript
// Console
localStorage.getItem('authToken')
localStorage.getItem('refreshToken')
```

### **Monitor API Calls**
1. Open DevTools → Network tab
2. Filter by "Fetch/XHR"
3. Check request headers (Authorization)
4. Check response status codes

### **Common Issues**

| Issue | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Token expired/invalid | Check if auto-refresh works, verify token in localStorage |
| Infinite refresh loop | Refresh token expired | Clear localStorage and re-login |
| CORS errors | Backend config | Check backend CORS settings |
| `response.data.data` undefined | Backend changed response format | Update interceptor unwrapping logic |

---

## 📚 References

- **Axios Documentation**: https://axios-http.com/docs/intro
- **React Context**: https://react.dev/reference/react/useContext
- **JWT Best Practices**: https://tools.ietf.org/html/rfc8725

---

## 👥 Maintainers

For questions or issues with the API layer, contact the backend team or refer to the backend API documentation.

**Last Updated**: 2025-10-08
