/// <reference types="vite/client" />

export const ensureTrailingSlash = (rawUrl?: string): string => {
  if (!rawUrl || rawUrl.trim() === '') {
    return '';
  }
  return rawUrl.endsWith('/') ? rawUrl : `${rawUrl}/`;
};

const USER_SERVICE_BASE = ensureTrailingSlash(import.meta.env.VITE_USER_SERVICE_URL) || '/user-service-api/';

export const API_CONFIGS = {
  user: {
    baseURL: USER_SERVICE_BASE,
    timeout: 10000,
  },
  question: {
    baseURL: ensureTrailingSlash(import.meta.env.VITE_QUESTION_SERVICE_URL) || '/question-service-api/',
    timeout: 10000,
  },
  matching: {
    baseURL: ensureTrailingSlash(import.meta.env.VITE_MATCHING_SERVICE_URL) || '/matching-service-api/',
    timeout: 10000,
  },
  session: {
    baseURL: ensureTrailingSlash(import.meta.env.VITE_SESSION_SERVICE_URL) || '/session-service-api/',
    timeout: 10000,
  },
  // order: {
  //   baseURL: ensureTrailingSlash(import.meta.env.VITE_ORDER_SERVICE_URL) || 'http://localhost:8002/',
  //   timeout: 10000,
  // },
  // product: {
  //   baseURL: ensureTrailingSlash(import.meta.env.VITE_PRODUCT_SERVICE_URL) || 'http://localhost:8003/',
  //   timeout: 10000,
  // },
  // auth: {
  //   baseURL: ensureTrailingSlash(import.meta.env.VITE_AUTH_SERVICE_URL) || 'http://localhost:8004/',
  //   timeout: 10000,
  // },
};

export const COMMON_HEADERS = {
  'Content-Type': 'application/json',
};
