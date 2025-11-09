import { useState, useEffect, useRef, useCallback } from 'react';
import { matchingService } from '../api/services/matchingService';
import { sessionService } from '../api/services/sessionService';
import { useAuth } from '../contexts/AuthContext';
import type { MatchingSelections, WebSocketMessage, SessionData } from '../types';

/**
 * WebSocket hook for matching service
 * Handles WebSocket connection and matching state
 */
export const useMatchingSocket = () => {
  const { user } = useAuth() as { user: any };
  const wsRef = useRef<WebSocket | null>(null);
  
  // Matching state
  const [isMatching, setIsMatching] = useState(false);
  const [matchFound, setMatchFound] = useState(false);
  const [sessionData, setSessionData] = useState<SessionData | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Connect WebSocket and setup listeners
  const connectWebSocket = useCallback((): Promise<boolean> => {
    return new Promise((resolve) => {
      if (!user?.id) {
        setError('User not authenticated');
        resolve(false);
        return;
      }

      // Close existing connection
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }

      try {
        const ws = matchingService.createWebSocket();
        wsRef.current = ws;

        const timeout = setTimeout(() => {
          if (ws.readyState !== WebSocket.OPEN) {
            console.error('WebSocket connection timeout');
            setError('Connection timeout');
            ws.close();
            wsRef.current = null;
            resolve(false);
          }
        }, 10000);

        ws.onopen = () => {
          clearTimeout(timeout);
          console.log('WebSocket connected successfully');
          setError(null);
          resolve(true);
        };

        ws.onmessage = (event) => {
          console.log('WebSocket message received:', event.data);
          const message: WebSocketMessage = JSON.parse(event.data);

          if (message.status === 'success' && message.session) {
            setMatchFound(true);
            setSessionData(message.session);
            setIsMatching(false);
          } else if (message.status === 'timeout') {
            setIsMatching(false);
            setError('No match found within the time limit');
          } else if (message.status === 'relax') {
            console.log('Language matching relaxed');
          }
        };

        ws.onerror = (event) => {
          clearTimeout(timeout);
          console.error('WebSocket error:', event);
          setError('WebSocket connection error');
          wsRef.current = null;
          resolve(false);
        };

        ws.onclose = (event) => {
          clearTimeout(timeout);
          console.log('WebSocket closed:', event.code, event.reason);
          wsRef.current = null;
        };

      } catch (error) {
        console.error('Failed to create WebSocket:', error);
        setError('Failed to create WebSocket');
        resolve(false);
      }
    });
  }, [user?.id]);

  // Start matching
  const startMatching = useCallback(async (criteria: MatchingSelections) => {
    if (!user?.id) {
      setError('User not authenticated');
      return;
    }

    // check active sessions
    const session = await sessionService.getActiveSession()
    console.log(`${session}`)
    if (session) {
      setError('Already in active session, rejoin from home screen');
      setIsMatching(false);
      return
    }

    console.log('Starting matching with criteria:', criteria);
    setError(null);
    setIsMatching(true);
    setMatchFound(false);

    try {
      // Connect WebSocket
      console.log('Connecting WebSocket...');
      const connected = await connectWebSocket();
      if (!connected) {
        console.error('WebSocket connection failed');
        setIsMatching(false);
        return;
      }

      // Verify WebSocket is still open before proceeding
      if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
        console.error('WebSocket not open after connection');
        setError('WebSocket connection lost');
        setIsMatching(false);
        return;
      }

      // Give a small delay to ensure connection is stable
      await new Promise(resolve => setTimeout(resolve, 200));

      // Double-check WebSocket is still open
      if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
        console.error('WebSocket closed before joining queue');
        setError('WebSocket connection lost');
        setIsMatching(false);
        return;
      }

      // Join queue 
      console.log('Joining queue via API...');
      await matchingService.addToQueue(criteria);
      console.log('Successfully joined queue');
      
    } catch (error: any) {
      console.error('Error in startMatching:', error);
      setIsMatching(false);
      
      if (error.response?.status === 409) {
        setError('Already in queue');
      } else if (error.response?.status === 503) {
        setError('Service temporarily unavailable');
      } else {
        setError(error.response?.data?.detail || 'Failed to start matching');
      }
      
      // Close WebSocket on error
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
    }
  }, [user?.id, connectWebSocket]);

  // Cancel matching
  const cancelMatching = useCallback(async () => {
    if (!user?.id) return;

    try {
      await matchingService.removeFromQueue();
      setIsMatching(false);
    } catch (error: any) {
      if (error.response?.status === 404) {
        setIsMatching(false);
      }
    }

    if (wsRef.current) {
      wsRef.current.close();
    }
  }, [user?.id]);

  // Reset state
  const resetMatch = useCallback(() => {
    setMatchFound(false);
    setSessionData(null);
    setError(null);
    setIsMatching(false);
  }, []);

  // Cleanup
  useEffect(() => {
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  return {
    isMatching,
    matchFound,
    sessionData,
    error,
    startMatching,
    cancelMatching,
    resetMatch,
  };
};
