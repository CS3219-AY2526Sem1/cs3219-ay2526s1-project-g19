import { useEffect, useState, useRef } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { userService } from '../api/services/userService';

const EmailSSOPage = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { login } = useAuth();
  const [status, setStatus] = useState('verifying'); // 'verifying', 'success', 'error'
  const [errorMessage, setErrorMessage] = useState('');
  const verificationAttempted = useRef(false); // Prevent duplicate verification attempts

  useEffect(() => {
    // Prevent duplicate verification attempts (e.g., React StrictMode double-rendering)
    if (verificationAttempted.current) {
      return;
    }
    verificationAttempted.current = true;

    const verifyToken = async () => {
      // Extract token from URL
      const token = searchParams.get('token');
      const redirectPath = searchParams.get('redirect');

      if (!token) {
        setStatus('error');
        setErrorMessage('No authentication token found in the link.');
        setTimeout(() => navigate('/login'), 3000);
        return;
      }

      try {
        // Verify token with backend
        const response = await userService.verifyEmailSSO({ token });
        console.log('Email SSO verification response:', response.data);


        // Extract data from response
        const { user, tokens, session_profile } = response.data;

        // Use AuthContext login to store tokens
        login(user, tokens);

        setStatus('success');

        // Redirect after short delay
        setTimeout(() => {
          if (redirectPath && redirectPath.startsWith('/')) {
            navigate(redirectPath);
          } else {
            navigate('/home');
          }
        }, 1500);

      } catch (error) {
        console.error('Email SSO verification failed:', error);
        console.error('Error response data:', error.response?.data);
        setStatus('error');

        // Parse error message
        if (error.response?.data?.error?.message) {
          setErrorMessage(error.response.data.error.message);
        } else if (error.response?.data?.message) {
          setErrorMessage(error.response.data.message);
        } else if (error.response?.status === 400) {
          setErrorMessage('Invalid or expired sign-in link.');
        } else if (error.response?.status === 401) {
          setErrorMessage('User not found or account inactive.');
        } else {
          setErrorMessage('Failed to verify sign-in link. Please try again.');
        }

        // Redirect to login after delay
        setTimeout(() => navigate('/login'), 3000);
      }
    };

    verifyToken();
  }, [searchParams, navigate, login]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="max-w-md w-full bg-background-secondary rounded-lg shadow-md p-8">
        {status === 'verifying' && (
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <h2 className="text-xl font-semibold text-gray-800 mb-2">
              Verifying Sign-In Link
            </h2>
            <p className="text-gray-600">
              Please wait while we log you in...
            </p>
          </div>
        )}

        {status === 'success' && (
          <div className="text-center">
            <div className="text-green-500 text-5xl mb-4">✓</div>
            <h2 className="text-xl font-semibold text-gray-800 mb-2">
              Sign-In Successful!
            </h2>
            <p className="text-gray-600">
              Redirecting you to your dashboard...
            </p>
          </div>
        )}

        {status === 'error' && (
          <div className="text-center">
            <div className="text-red-500 text-5xl mb-4">✗</div>
            <h2 className="text-xl font-semibold text-gray-800 mb-2">
              Sign-In Failed
            </h2>
            <p className="text-gray-600 mb-4">
              {errorMessage}
            </p>
            <p className="text-sm text-gray-500">
              Redirecting to login page...
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default EmailSSOPage;
