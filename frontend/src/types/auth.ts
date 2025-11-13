import type { User } from './user';

// Token Types
export interface TokenInfo {
  token: string;
  expires_at: string;
}

export interface Tokens {
  access_token: TokenInfo;
  refresh_token: TokenInfo;
}

// Login
export interface LoginRequest {
  email: string;
  password: string;
}

export interface SessionProfile {
  profile_id: string;
  session_key: string;
  ip_address: string;
  user_agent: string;
  login_at: string;
  last_activity_at: string;
  is_active: boolean;
}

export interface LoginResponse {
  user: User;
  tokens: Tokens;
  session_profile: SessionProfile;
}

// Refresh Token
export interface RefreshTokenRequest {
  refresh_token: string;
}

export interface RefreshTokenResponse {
  tokens: Tokens;
}

// Verify Token
export interface VerifyTokenResponse {
  user: User;
  session_profile: SessionProfile;
}

// Register
export interface RegisterRequest {
  email: string;
  password: string;
  display_name: string;
}

export interface RegisterResponse {
  user: User;
}

// Email SSO
export interface EmailSSORequest {
  email: string;
  redirect_path?: string;
}

export interface EmailSSOResponse {
  email: string;
  account_exists: boolean;
  delivered: boolean;
  expires_in: number;
  login_url: string | null;
}

export interface EmailSSOVerifyRequest {
  token: string;
}

export interface EmailSSOVerifyResponse {
  user: User;
  tokens: Tokens;
  session_profile: SessionProfile;
}
