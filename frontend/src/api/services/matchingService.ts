import { matchingClient } from '../client';
import { ensureTrailingSlash } from '../config';
import type {
  MatchResponse,
  MatchingSelections,
} from '../../types';

export const matchingService = {
  // To add user to matching queue
  addToQueue: (data: MatchingSelections) =>
    matchingClient.post<MatchResponse>('/api/match', data),

  // To remove user from matching queue when matched, timed out or cancelled
  removeFromQueue: () =>
    matchingClient.delete('/api/match'),

  getLanguages: async (): Promise<string[]> => {
    const response = await matchingClient.get<string[]>('/api/languages');
    return response.data ?? [];
  },

  // WebSocket connection helper with proxy support
  createWebSocket: (baseUrl?: string) => {
    let wsUrl: string;
    const token = localStorage.getItem('authToken');
    if (!token) {
      return
    }
    
    // Get the configured base URL or use default proxy path
    const apiBaseUrl = baseUrl || matchingClient.defaults.baseURL || '/matching-service-api/';
    
    // If using a proxy path , construct WebSocket URL using current window location
    if (apiBaseUrl.startsWith('/')) {
      // Use the current window location to build WebSocket URL
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const host = window.location.host;
      const cleanBase = ensureTrailingSlash(apiBaseUrl).replace(/\/$/, '');
      wsUrl = `${protocol}//${host}${cleanBase}/api/ws?token=${encodeURIComponent(token)}`;
    } else {
      // Direct URL, convert http to ws
      const wsBaseUrl = ensureTrailingSlash(apiBaseUrl).replace(/^http/, 'ws').replace(/\/$/, '');
      wsUrl = `${wsBaseUrl}/api/ws?token=${encodeURIComponent(token)}`;
    }
    
    console.log('Creating WebSocket connection to:', wsUrl);
    
    return new WebSocket(wsUrl);
  },
};
