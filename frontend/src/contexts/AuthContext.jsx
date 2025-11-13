import { createContext, useContext, useState, useEffect } from 'react';
import { userService } from '../api/services/userService';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Verify token on mount
  useEffect(() => {
    const verifyAuth = async () => {
      const token = localStorage.getItem('authToken');

      if (!token) {
        setLoading(false);
        return;
      }

      try {
        const response = await userService.verifyToken();
        setUser(response.data.user);
        setIsAuthenticated(true);
      } catch (error) {
        console.error('Token verification failed:', error);
        // Clear invalid tokens
        localStorage.removeItem('authToken');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('user');
        setUser(null);
        setIsAuthenticated(false);
      } finally {
        setLoading(false);
      }
    };

    verifyAuth();
  }, []);

  const login = (userData, tokens) => {
    setUser(userData);
    setIsAuthenticated(true);
    localStorage.setItem('authToken', tokens.access_token.token);
    localStorage.setItem('refreshToken', tokens.refresh_token.token);
    localStorage.setItem('user', JSON.stringify(userData));
  };

  const logout = async () => {
    // Store result for notification handling
    let result = { success: false, error: null };
    
    try {
      // Call backend to invalidate session
      await userService.logout();
      result.success = true;
    } catch (error) {
      console.error('Logout API call failed:', error);
      
      // Determine error type based on response status
      if (error.response?.status === 401) {
        result.error = { type: 'auth', message: 'Authentication required' };
      } else if (error.response?.status === 400) {
        result.error = { type: 'bad_request', message: 'Logout failed - invalid request' };
      } else {
        result.error = { type: 'network', message: 'Network error during logout' };
      }
    } finally {
      // Always clear local state and storage
      setUser(null);
      setIsAuthenticated(false);
      localStorage.removeItem('authToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('user');
    }
    
    return result;
  };

  return (
    <AuthContext.Provider value={{ user, loading, isAuthenticated, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
