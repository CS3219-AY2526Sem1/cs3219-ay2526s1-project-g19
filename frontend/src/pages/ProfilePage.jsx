import { useAuth } from "../contexts/AuthContext";
import { LucideLockKeyhole, Verified, LogOut } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useNotification } from "../contexts/NotificationContext";
import { useState } from "react";
import PasswordResetForm from "../components/profile/PasswordResetForm";

const ProfilePage = () => {
    const { user } = useAuth();
    const { logout } = useAuth();
    const { showSuccess, showError } = useNotification();
    const navigate = useNavigate();
    const [isPasswordFormOpen, setIsPasswordFormOpen] = useState(false);

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
    
    return (
        <div className="container mx-auto p-10">
            <h1 className="text-4xl font-bold mb-4">{user.display_name}</h1>
            <h4 className="text-gray-400 mb-2">Email: {user.email}</h4>
            <div className="mt-6 flex flex-col space-y-4 w-fit">
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
                {/* <button className="bg-green-500 text-white hover:bg-green-600 font-semibold py-2 px-4 rounded whitespace-nowrap">
                    <Verified className="inline-block mr-2" />
                    Verify Account
                </button> */}
            </div>

            {/* Password Reset Form */}
            <PasswordResetForm
                isOpen={isPasswordFormOpen}
                onClose={() => setIsPasswordFormOpen(false)}
            />
        </div>
    );
};

export default ProfilePage;
