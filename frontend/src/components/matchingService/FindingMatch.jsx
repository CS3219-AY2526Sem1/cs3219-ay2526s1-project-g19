import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";

const FindingMatch = ({ selections: { topic, difficulty, preferredLanguage, backupLanguages }, onCancel, isRelaxed }) => {
    const [seconds, setSeconds] = useState(0);
    const [isMatching, setIsMatching] = useState(true);

    useEffect(() => {
        if (!isMatching) return;

        const timer = setInterval(() => {
            setSeconds(prev => prev + 1);
        }, 1000);

        return () => clearInterval(timer);
    }, [isMatching]);

    // Depend on the max matching time (If < 1 min, update to show seconds only)
    const formatTime = (totalSeconds) => {
        const mins = String(Math.floor(totalSeconds / 60)).padStart(2, '0');
        const secs = String(totalSeconds % 60).padStart(2, '0');
        return `${mins}:${secs}`;
    };

    return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-70">
        <div className="rounded-lg shadow-lg p-8 max-w-lg w-full relative bg-background-secondary border border-gray-700 border-1 shadow-lg">
            <div className="text-center">
                <Loader2 className="mx-auto mb-4 h-12 w-12 animate-spin text-primary" />
                <h3 className="text-gray-200 mb-2">Finding your Match...</h3>
                <p className="text-gray-400 p-2 mb-2">Please wait while we find the best match for you.</p>
        
            <div className="text-gray-300 mb-4 text-center border border-gray-700 p-5 rounded bg-gray-800">
                <p><strong>Topic:</strong> <span>{topic}</span></p>
                <p><strong>Difficulty:</strong> <span>{difficulty}</span></p>
                <p><strong>Preferred Language:</strong> <span>{preferredLanguage}</span></p>
                {backupLanguages.length > 0 && (
                    <p><strong>Backup Languages:</strong> <span>{backupLanguages.join(', ')}</span></p>
                )}
            </div>

            <p className="text-center text-primary font-mono font-bold text-5xl p-2">
                {formatTime(seconds)}
            </p>

            <div className="w-full h-2 bg-background-secondary rounded-full overflow-hidden mb-4">
                <div 
                    className="h-full bg-primary transition-all duration-1000 ease-out"
                    style={{ width: `${Math.min((seconds / 60) * 100, 100)}%` }}
                    // Max matching time is 1min
                ></div>
            </div>

            {isRelaxed && backupLanguages && backupLanguages.length > 0 && (
                <div className="mb-4 p-3 bg-yellow-900/20 border border-yellow-700 rounded-lg animate-pulse">
                    <p className="text-yellow-400 text-sm text-center">
                        Now also matching with backup languages: <strong>{backupLanguages.join(', ')}</strong>
                    </p>
                </div>
            )}

            <button
                onClick={onCancel}
                className="w-full text-lg font-bold py-3 rounded-lg border-2 bg-red-500 hover:bg-red-600">
                Cancel Match
            </button>
            </div>
        </div>
    </div>
    );
}

export default FindingMatch;