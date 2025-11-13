import type { AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { userService } from './services/userService';

let isRefreshing = false;
let failedQueue: Array<{
  resolve: (value?: unknown) => void;
  reject: (reason?: unknown) => void;
}> = [];

const processQueue = (error: Error | null, token: string | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });

  failedQueue = [];
};

export const setupInterceptors = (client: AxiosInstance) => {
  // Request interceptor
  client.interceptors.request.use(
    (config) => {
      const token = localStorage.getItem('authToken');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    },
    (error) => Promise.reject(error)
  );

  // Response interceptor with auto-refresh
  client.interceptors.response.use(
    (response) => {
      // Unwrap nested data from backend response format: {success, message, data}
      if (response.data && response.data.data !== undefined) {
        response.data = response.data.data;
      }
      return response;
    },
    async (error) => {
      const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

      // If error is 401 and we haven't retried yet
      if (error.response?.status === 401 && !originalRequest._retry) {
        if (isRefreshing) {
          // If already refreshing, queue this request
          return new Promise((resolve, reject) => {
            failedQueue.push({ resolve, reject });
          })
            .then((token) => {
              originalRequest.headers.Authorization = `Bearer ${token}`;
              return client(originalRequest);
            })
            .catch((err) => Promise.reject(err));
        }

        originalRequest._retry = true;
        isRefreshing = true;

        const refreshToken = localStorage.getItem('refreshToken');

        if (!refreshToken) {
          // No refresh token, redirect to login
          localStorage.clear();
          if (window.location.pathname !== '/login') {
            window.location.href = '/login';
          }
          return Promise.reject(error);
        }

        try {
          // Call refresh token endpoint via userService
          const response = await userService.refreshToken({
            refresh_token: refreshToken,
          });

          const { tokens } = response.data;

          // Update tokens in localStorage
          localStorage.setItem('authToken', tokens.access_token.token);
          localStorage.setItem('refreshToken', tokens.refresh_token.token);

          // Update the authorization header
          client.defaults.headers.common['Authorization'] = `Bearer ${tokens.access_token.token}`;
          originalRequest.headers.Authorization = `Bearer ${tokens.access_token.token}`;

          // Process queued requests
          processQueue(null, tokens.access_token.token);

          // Retry original request
          return client(originalRequest);
        } catch (refreshError) {
          // Refresh failed, clear tokens and redirect to login
          processQueue(refreshError as Error, null);
          localStorage.clear();
          if (window.location.pathname !== '/login') {
            window.location.href = '/login';
          }
          return Promise.reject(refreshError);
        } finally {
          isRefreshing = false;
        }
      }

      return Promise.reject(error);
    }
  );
};
