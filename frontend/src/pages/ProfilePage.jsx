import { useAuth } from "../contexts/AuthContext";
import { LucideLockKeyhole, Verified, LogOut, Loader2 } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useNotification } from "../contexts/NotificationContext";
import { useState } from "react";
import PasswordResetForm from "../components/profile/PasswordResetForm";
import SessionHistory from "../components/profile/SessionHistory";
import { userService } from "../api/services/userService";

const ProfilePage = () => {
    const { user, logout } = useAuth();
    const { showSuccess, showError } = useNotification();
    const navigate = useNavigate();
    const [isPasswordFormOpen, setIsPasswordFormOpen] = useState(false);
    const [isSendingVerification, setIsSendingVerification] = useState(false);

    const isVerified = Boolean(user?.is_verified);

    const handleLogout = async () => {
        const result = await logout();
        
        if (result.success) {
            showSuccess('Success', 'You have been logged out successfully');
        } else {
            // Handle different error types notification
            let errorTitle = 'Logout Error';
            let errorMessage = result.error?.message || 'An unexpected error occurred';
            
            switch (result.error?.type) {
                case 'auth':
                    errorTitle = 'Authentication Error';
                    errorMessage = 'Session expired - you have been logged out locally';
                    break;
                case 'bad_request':
                    errorTitle = 'Logout Failed';
                    errorMessage = 'Server error during logout - you have been logged out locally';
                    break;
                case 'network':
                    errorTitle = 'Network Error';
                    errorMessage = 'Could not connect to server - you have been logged out locally';
                    break;
            }
            
            showError(errorTitle, errorMessage);
        }
        
        // Always redirect to login page after logout attempt
        navigate('/login');
    }

    const handleSendVerificationEmail = async () => {
        if (!user || user.is_verified || isSendingVerification) {
            return;
        }

        setIsSendingVerification(true);
        try {
            const response = await userService.sendVerificationEmail();
            const detail = response.data?.detail || 'Verification email sent successfully.';
            showSuccess('Email Sent', detail);
        } catch (error) {
            console.error('Failed to send verification email:', error);
            const detail = error?.response?.data?.detail || 'Failed to send verification email. Please try again.';
            showError('Verification Error', detail);
        } finally {
            setIsSendingVerification(false);
        }
    };

    if (!user) {
        return (
            <div className="container mx-auto p-10 page-transition">
                <p className="text-gray-500">Loading profile...</p>
            </div>
        );
    }
    
    return (
        <div className="container mx-auto p-10 page-transition">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-4xl font-bold mb-2">{user.display_name}</h1>
                    <h4 className="text-gray-400">Email: {user.email}</h4>
                    <div className={`inline-flex items-center gap-2 text-sm font-semibold px-3 py-1 rounded-full mt-3 ${isVerified ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                        <Verified className={`h-4 w-4 ${isVerified ? '' : 'text-yellow-600'}`} />
                        {isVerified ? 'Email verified' : 'Email not verified'}
                    </div>
                </div>
                <div className="flex gap-4">
                    <button 
                        onClick={handleSendVerificationEmail}
                        disabled={isVerified || isSendingVerification}
                        className={`bg-green-600 text-white font-semibold py-2 px-4 rounded whitespace-nowrap flex items-center justify-center disabled:opacity-60 disabled:cursor-not-allowed ${!isVerified ? 'hover:bg-green-700' : ''}`}
                    >
                        {isSendingVerification ? (
                            <Loader2 className="inline-block mr-2 animate-spin" />
                        ) : (
                            <Verified className="inline-block mr-2" />
                        )}
                        {isVerified ? 'Email Verified' : isSendingVerification ? 'Sending...' : 'Send Verification Email'}
                    </button>
                    <button 
                        onClick={() => setIsPasswordFormOpen(true)}
                        className="bg-primary text-white hover:bg-primary-dark font-semibold py-2 px-4 rounded whitespace-nowrap"
                    >
                        <LucideLockKeyhole className="inline-block mr-2" />
                        Password Reset
                    </button>
                    <button
                        onClick={handleLogout}
                        className="bg-red-500 text-white hover:bg-red-600 font-semibold py-2 px-4 rounded whitespace-nowrap">
                        <LogOut className="inline-block mr-2" />
                        Logout
                    </button>
                </div>
            </div>

            {/* Password Reset Form */}
            <PasswordResetForm
                isOpen={isPasswordFormOpen}
                onClose={() => setIsPasswordFormOpen(false)}
            />

            {/* Session History Section */}
            <SessionHistory />
        </div>
    );
};

export default ProfilePage;
