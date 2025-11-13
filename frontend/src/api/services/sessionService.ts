import { sessionClient } from '../client';

export const sessionService = {
  // End a collaboration session
  endSession: (sessionId: string) =>
    sessionClient.post(`/api/session/end?session_id=${sessionId}`),
  // Check if user has an active session
  getActiveSession: async () => {
    try {
      const response = await sessionClient.get(`/api/session`);
      return response.data;
    } catch (error) {
      console.error('Error fetching active session:', error);
      return null;
    }
  },
  // Get session history (5 session per page)
  getHistory: (page: number = 1, size: number = 5) =>
    sessionClient.get(`/api/session/history?page=${page}&size=${size}`),
};
