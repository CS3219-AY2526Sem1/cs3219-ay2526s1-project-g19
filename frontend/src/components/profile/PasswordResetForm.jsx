import { useState } from 'react';
import { X, Eye, EyeOff, MessageSquareWarning } from 'lucide-react';
import { useNotification } from '../../contexts/NotificationContext';
import { useAuth } from '../../contexts/AuthContext';
import { userService } from '../../api/services/userService';
import { useNavigate } from 'react-router-dom';

// Password validation function - same with registration form rules
const validatePassword = (value) => {
    const errors = [];

    if (value.length === 0) {
        errors.push("Password is required.");
        return errors;
    }

    const allowedCharsRegex = /^[A-Za-z0-9!@#$%^&*(),.?":{}|<>_-]+$/;

    if (!allowedCharsRegex.test(value)) {
        errors.push("Password contains illegal characters. Only letters, numbers, and standard special symbols are allowed.");
    }
    
    if (value.length < 8) {
        errors.push("Password must be at least 8 characters long.");
    }
    if (!/[A-Z]/.test(value)) {
        errors.push("Password must contain at least one uppercase letter.");
    }
    if (!/[a-z]/.test(value)) {
        errors.push("Password must contain at least one lowercase letter.");
    }
    if (!/[0-9]/.test(value)) {
        errors.push("Password must contain at least one number.");
    }
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(value)) {
        errors.push("Password must contain at least one special character.");
    }
    
    return errors;
};

const validateConfirmPassword = (value, passwordValue) => {
    const errors = [];

    if (value.length === 0) {
        errors.push("Confirm Password is required.");
        return errors;
    }

    if (value !== passwordValue) {
        errors.push("Passwords do not match.");
    }

    return errors;
};

const PasswordResetForm = ({ isOpen, onClose }) => {
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showNewPassword, setShowNewPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [errors, setErrors] = useState({
        newPassword: [],
        confirmPassword: []
    });
    const { showSuccess, showError } = useNotification();
    const { logout } = useAuth();
    const navigate = useNavigate();

    if (!isOpen) return null;

    const handlePasswordChange = (e) => {
        const value = e.target.value;
        setNewPassword(value);
        
        const passwordErrors = validatePassword(value);
        setErrors(prev => ({ ...prev, newPassword: passwordErrors }));
        
        if (confirmPassword) {
            const confirmErrors = validateConfirmPassword(confirmPassword, value);
            setErrors(prev => ({ ...prev, confirmPassword: confirmErrors }));
        }
    };

    const handleConfirmPasswordChange = (e) => {
        const value = e.target.value;
        setConfirmPassword(value);
        
        const confirmErrors = validateConfirmPassword(value, newPassword);
        setErrors(prev => ({ ...prev, confirmPassword: confirmErrors }));
    };

    const handlePasswordBlur = () => {
        const passwordErrors = validatePassword(newPassword);
        setErrors(prev => ({ ...prev, newPassword: passwordErrors }));
    };

    const handleConfirmPasswordBlur = () => {
        const confirmErrors = validateConfirmPassword(confirmPassword, newPassword);
        setErrors(prev => ({ ...prev, confirmPassword: confirmErrors }));
    };

    const getBorderColor = (fieldName) => {
        const fieldErrors = errors[fieldName];
        if (!fieldErrors || fieldErrors.length === 0) return "border-gray-300";
        return "border-red-400";
    };

    const ErrorMessage = ({ errorsArray }) => {
        if (!errorsArray || errorsArray.length === 0) return null;
        return (
            <div className="text-red-500 text-xs mt-1 space-y-0.5">
                {errorsArray.map((err, idx) => (
                    <p key={idx} className="flex items-start">
                        <MessageSquareWarning className="inline w-3 h-3 mr-1 text-red-400"/>
                        {err}
                    </p>
                ))}
            </div>
        );
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        const passwordErrors = validatePassword(newPassword);
        const confirmErrors = validateConfirmPassword(confirmPassword, newPassword);

        setErrors({
            newPassword: passwordErrors,
            confirmPassword: confirmErrors
        });

        if (passwordErrors.length > 0 || confirmErrors.length > 0) {
            return;
        }

        setIsLoading(true);

        try {
            await userService.resetPassword({ new_password: newPassword });
            
            showSuccess(
                'Password Reset Successful', 
                'Your password has been updated. Please login again.'
            );
            
            onClose();
            
            setTimeout(async () => {
                await logout();
                navigate('/login');
            }, 100);
            
        } catch (error) {
            console.error('Password reset error:', error);
            
            if (error.response) {
                const status = error.response.status;
                const data = error.response.data;
                
                if (status === 400) {
                    showError('Invalid Input', data.detail || 'Please check your password and try again');
                } else if (status === 401) {
                    showError('Authentication Required', 'Your session has expired. Please login again.');
                    setTimeout(() => {
                        logout();
                        navigate('/login');
                    }, 1500);
                } else {
                    showError('Error', data.detail || 'Failed to reset password. Please try again.');
                }
            } else if (error.request) {
                showError('Network Error', 'Could not connect to the server. Please check your connection.');
            } else {
                showError('Error', 'An unexpected error occurred. Please try again.');
            }
        } finally {
            setIsLoading(false);
        }
    };

    const handleClose = () => {
        if (!isLoading) {
            setNewPassword('');
            setConfirmPassword('');
            setShowNewPassword(false);
            setShowConfirmPassword(false);
            setErrors({
                newPassword: [],
                confirmPassword: []
            });
            onClose();
        }
    };

    return (
        <div className="fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center z-50">
            <div className="bg-background-secondary border border-gray-700 rounded-lg shadow-xl max-w-md w-full mx-4">
                <div className="flex items-center justify-between p-6 border-b">
                    <h2 className="text-2xl font-bold text-gray-200">Reset Password</h2>
                    <button
                        onClick={handleClose}
                        disabled={isLoading}
                        className="text-white hover:text-red-500 disabled:opacity-50 bg-transparent hover:bg-transparent"
                    >
                        <X size={24} />
                    </button>
                </div>

                <form onSubmit={handleSubmit} className="p-6 space-y-4">
                    <div className="bg-yellow-300 bg-opacity-60 border border-yellow-400 rounded-lg p-4 text-sm">
                        <p className="font-semibold mb-1 text-white">⚠️ Warning</p>
                        <p className="text-white">For security reasons, you will need to login again with your new password after resetting it.</p>
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-200 mb-2">
                            New Password
                        </label>
                        <div className={`relative flex items-center border ${getBorderColor('newPassword')} rounded-lg focus-within:ring-2 focus-within:ring-primary focus-within:border-transparent`}>
                            <input
                                id="newPassword"
                                type={showNewPassword ? 'text' : 'password'}
                                value={newPassword}
                                onChange={handlePasswordChange}
                                onBlur={handlePasswordBlur}
                                disabled={isLoading}
                                className="focus:outline-none flex-grow bg-transparent ml-2 text-gray-200"
                                placeholder="Enter new password"
                                required
                            />
                            <button
                                type="button"
                                onClick={() => setShowNewPassword(!showNewPassword)}
                                disabled={isLoading}
                                className="focus:outline-none bg-transparent hover:bg-transparent hover:text-gray-100 text-gray-300"
                            >
                                {showNewPassword ? <Eye size={20} /> : <EyeOff size={20} />}
                            </button>
                        </div>
                        <ErrorMessage errorsArray={errors.newPassword} />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-200 mb-2">
                            Confirm New Password
                        </label>
                        <div className={`relative flex items-center border ${getBorderColor('confirmPassword')} rounded-lg focus-within:ring-2 focus-within:ring-primary focus-within:border-transparent`}>
                            <input
                                id="confirmPassword"
                                type={showConfirmPassword ? 'text' : 'password'}
                                value={confirmPassword}
                                onChange={handleConfirmPasswordChange}
                                onBlur={handleConfirmPasswordBlur}
                                disabled={isLoading}
                                className="focus:outline-none flex-grow bg-transparent ml-2 text-gray-200"
                                placeholder="Confirm new password"
                                required
                            />
                            <button
                                type="button"
                                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                                disabled={isLoading}
                                className="focus:outline-none bg-transparent hover:bg-transparent hover:text-gray-100 text-gray-300"
                            >
                                {showConfirmPassword ? <Eye size={20} /> : <EyeOff size={20} />}
                            </button>
                        </div>
                        <ErrorMessage errorsArray={errors.confirmPassword} />
                    </div>

                    {/* Buttons */}
                    <div className="flex space-x-3 pt-4">
                        <button
                            type="button"
                            onClick={handleClose}
                            disabled={isLoading}
                            className="flex-1 px-4 py-2 border bg-transparent border-gray-500 rounded-lg text-gray-200 font-medium hover:bg-background disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            disabled={isLoading}
                            className="flex-1 px-4 py-2 bg-primary text-white rounded-lg font-medium hover:bg-primary-dark disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                        >
                            {isLoading ? (
                                <>
                                    <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                    </svg>
                                    Updating...
                                </>
                            ) : (
                                'Reset Password'
                            )}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default PasswordResetForm;
