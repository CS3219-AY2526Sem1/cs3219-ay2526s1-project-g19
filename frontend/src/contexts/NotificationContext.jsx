import { createContext, useContext, useState } from 'react';
import Notification from '../components/common/Notification';

const NotificationContext = createContext(null);

export const NotificationProvider = ({ children }) => {
    const [notifications, setNotifications] = useState([]);

    const addNotification = (type, title, message, duration = 5000) => {
        const id = Date.now() + Math.random(); // Simple ID generation
        const notification = { id, type, title, message, duration };
        
        setNotifications(prev => [...prev, notification]);
        
        return id;
    };

    const removeNotification = (id) => {
        setNotifications(prev => prev.filter(notification => notification.id !== id));
    };

    // Convenience methods
    const showSuccess = (title, message, duration) => addNotification('success', title, message, duration);
    const showError = (title, message, duration) => addNotification('error', title, message, duration);
    const showWarning = (title, message, duration) => addNotification('warning', title, message, duration);
    const showInfo = (title, message, duration) => addNotification('info', title, message, duration);

    return (
        <NotificationContext.Provider value={{
            addNotification,
            removeNotification,
            showSuccess,
            showError,
            showWarning,
            showInfo
        }}>
            {children}
            
            <div className="fixed top-4 right-4 z-50 space-y-3">
                {notifications.map((notification) => (
                    <Notification
                        key={notification.id}
                        type={notification.type}
                        title={notification.title}
                        message={notification.message}
                        duration={notification.duration}
                        onClose={() => removeNotification(notification.id)}
                    />
                ))}
            </div>
        </NotificationContext.Provider>
    );
};

export const useNotification = () => {
    const context = useContext(NotificationContext);
    if (!context) {
        throw new Error('useNotification must be used within NotificationProvider');
    }
    return context;
};