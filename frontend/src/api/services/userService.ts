import { userClient, authClient } from '../client';
import type {
  LoginRequest,
  LoginResponse,
  RefreshTokenRequest,
  RefreshTokenResponse,
  VerifyTokenResponse,
  RegisterRequest,
  RegisterResponse,
  EmailSSORequest,
  EmailSSOResponse,
  EmailSSOVerifyRequest,
  EmailSSOVerifyResponse
} from '../../types';

export const userService = {
  register: (data: RegisterRequest) =>
    userClient.post<RegisterResponse>('api/auth/register/', data),

  login: (data: LoginRequest) =>
    userClient.post<LoginResponse>('api/auth/login/', data),

  // Use authClient (without interceptors) to avoid circular refresh calls
  refreshToken: (data: RefreshTokenRequest) =>
    authClient.post<RefreshTokenResponse>('api/auth/refresh/', data),

  // Verify JWT token and get current user
  verifyToken: () =>
    userClient.get<VerifyTokenResponse>('api/auth/verify-token/'),

  // Logout user and invalidate all sessions
  logout: () =>
    userClient.post('api/auth/logout/'),

  // Reset password
  resetPassword: (data: { new_password: string }) =>
    userClient.put('api/auth/reset-password/', data),

  // Email SSO - Request magic link
  requestEmailSSO: (data: EmailSSORequest) =>
    userClient.post<EmailSSOResponse>('api/auth/email-sso/', data),

  // Email SSO - Verify token and login
  verifyEmailSSO: (data: EmailSSOVerifyRequest) =>
    userClient.post<EmailSSOVerifyResponse>('api/auth/email-sso/verify/', data),

  // Get public profile information by user ID
  getPublicProfile: (userId: string) =>
    userClient.get(`api/users/public-profile/?user_id=${userId}`),
};