import { XCircle, RotateCcw } from "lucide-react";

const MatchNotFound = ({ 
    onRematch, 
    onReturn, 
    title,
    message,
    subtitle
}) => {
return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75">
        <div className = "rounded-lg shadow-lg p-8 max-w-xl w-full relative bg-background-secondary border border-gray-700">
            <div className="text-center">
                <XCircle className="mx-auto mb-4 h-12 w-12 text-red-500" />
                <h3 className="text-gray-200 font-bold mb-2">{title}</h3>
                <p className="text-gray-400 p-2">{message}</p>
                <p className="text-gray-400 p-2 mb-6">{subtitle}</p>

                <div className="flex justify-center gap-4">
                    <button
                        onClick={onReturn}
                        className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 bg-background-secondary border-gray-600 text-gray-300 hover:bg-gray-700">
                        Adjust Preferences
                    </button>
                    <button
                        onClick={onRematch}
                        className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 bg-primary hover:bg-primary-dark text-white">
                        <RotateCcw className="inline-block mr-2" />
                        Rematch
                    </button>
                </div>
            </div>
        </div>
    </div>
    );
}

export default MatchNotFound;

