import { useState, useEffect } from 'react';
import { CheckCircle, XCircle, AlertCircle, X } from 'lucide-react';

const Notification = ({ type, title, message, onClose, duration = 5000 }) => {
    const [isVisible, setIsVisible] = useState(true);

    useEffect(() => {
        if (duration > 0) {
            const timer = setTimeout(() => {
                setIsVisible(false);
                setTimeout(onClose, 300); 
            }, duration);

            return () => clearTimeout(timer);
        }
    }, [duration, onClose]);

    const getIcon = () => {
        switch (type) {
            case 'success':
                return <CheckCircle className="w-6 h-6 text-green-500" />;
            case 'error':
                return <XCircle className="w-6 h-6 text-red-500" />;
            case 'warning':
                return <AlertCircle className="w-6 h-6 text-yellow-500" />;
            default:
                return <AlertCircle className="w-6 h-6 text-blue-500" />;
        }
    };

    const getBgColor = () => {
        switch (type) {
            case 'success':
                return 'bg-green-900 border-green-700';
            case 'error':
                return 'bg-red-900 border-red-700';
            case 'warning':
                return 'bg-yellow-900 border-yellow-700';
            default:
                return 'bg-blue-900 border-blue-700';
        }
    };

    const handleClose = () => {
        setIsVisible(false);
        setTimeout(onClose, 300);
    };

    return (
        <div className={`transform transition-all duration-300 ${
            isVisible ? 'translate-x-0 opacity-100' : 'translate-x-full opacity-0'
        }`}>
            <div className={`min-w-80 max-w-md shadow-lg rounded-lg border ${getBgColor()} p-5`}>
                <div className="flex items-start justify-between">
                    <div className="flex items-start space-x-3 flex-1 min-w-0">
                        <div className="flex-shrink-0 mt-0.5">
                            {getIcon()}
                        </div>
                        <div className="flex-1 min-w-0 pr-2">
                            {title && (
                                <p className="text-base font-semibold text-white mb-1">
                                    {title}
                                </p>
                            )}
                            <p className="text-sm text-gray-300 leading-relaxed">
                                {message}
                            </p>
                        </div>
                    </div>
                    <div className="flex-shrink-0 ml-3">
                        <button
                            onClick={handleClose}
                            className="text-white items-center justify-center w-8 h-8 rounded-full bg-transparent focus:outline-none hover:bg-transparent transition-colors duration-200"
                        >
                            <X className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Notification;