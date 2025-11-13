import axios from 'axios';
import { API_CONFIGS, COMMON_HEADERS } from './config';
import { setupInterceptors } from './interceptors';

// Create separate clients for each service
export const userClient = axios.create({
  ...API_CONFIGS.user,
  headers: COMMON_HEADERS,
});

export const matchingClient = axios.create({
  ...API_CONFIGS.matching,
  headers: COMMON_HEADERS,
});

export const questionClient = axios.create({
  ...API_CONFIGS.question,
  headers: COMMON_HEADERS,
  paramsSerializer: {
    indexes: null,
  },
});

export const sessionClient = axios.create({
  ...API_CONFIGS.session,
  headers: COMMON_HEADERS,
});

// Bare client for auth operations (no interceptors to avoid circular calls)
export const authClient = axios.create({
  ...API_CONFIGS.user,
  headers: COMMON_HEADERS,
});

// Setup interceptors for all clients except authClient
setupInterceptors(userClient);
setupInterceptors(matchingClient);
setupInterceptors(questionClient);
setupInterceptors(sessionClient);