import { UserCircle2, Loader2 } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useState, useEffect } from "react";
import { useAuth } from "../../contexts/AuthContext";
import { userService } from "../../api/services/userService";

const DIFFICULTIES_COLORS = {
    "easy": "text-green-500 border-green-500",
    "medium": "text-yellow-500 border-yellow-500",
    "hard": "text-red-500 border-red-500"
};

const getDifficultyColor = (difficulty) => {
    return DIFFICULTIES_COLORS[difficulty] || "text-gray-500 border-gray-500";
}

const getDifficulties = (difficultyStr) => {
    switch (difficultyStr) {
        case "easy":
            return "Easy";
        case "medium":
            return "Medium";
        case "hard":
            return "Hard";
        default:
            return "Any";
    }
}

const MatchFound = ({ user1, matchedSelections, sessionData}) => {
    const navigate = useNavigate();
    const { user } = useAuth();
    const [partnerName, setPartnerName] = useState("");
    const REDIRECT_DELAY = 2000; // 2 seconds buffer to view match found screen

    // Fetch partner's name from user service
    useEffect(() => {
        const fetchPartnerName = async () => {
            try {
                const partnerId = sessionData?.user_id_list?.find(id => id !== user?.id);

                if (partnerId) {
                    const response = await userService.getPublicProfile(partnerId);
                    setPartnerName(response.data?.user?.display_name || "Partner");
                } else {
                    setPartnerName("Partner");
                }
            } catch (error) {
                console.error('Failed to fetch partner profile:', error);
                setPartnerName("Partner");
            }
        };

        if (sessionData?.user_id_list) {
            fetchPartnerName();
        }
    }, [sessionData, user?.id]);

    useEffect(() => {
        // Automatically navigate to collaboration page with session ID in URL
        const timer = setTimeout(() => {
            if (sessionData?.session_id) {
                navigate(`/collaboration/${sessionData.session_id}`, { 
                    state: { sessionData } 
                });
            } else {
                console.error('No session ID found in sessionData');
            }
        }, REDIRECT_DELAY);

        return () => clearTimeout(timer);
    }, [navigate, sessionData]);
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75">
            <div className = "rounded-lg shadow-lg p-8 max-w-lg w-full relative bg-background-secondary border border-gray-700">
                <div className="text-center">
                    <h3 className="text-gray-200 font-bold mb-6">Match Found!</h3>

                    <div className="flex justify-center items-center mb-4 font-semibold text-lg text-gray-300 gap-2 grid grid-cols-3">
                        <div className="flex flex-col items-center">
                            <UserCircle2 className="h-20 w-20 text-primary mb-2"/>
                            <p className="text-lg font-bold">{user1}</p>
                        </div>

                        <span className="text-4xl text-gray-400 font-extrabold"> VS </span>

                        <div className="flex flex-col items-center">
                            <UserCircle2 className="h-20 w-20 text-primary mb-2"/>
                            <p className="text-lg font-bold">{partnerName}</p>
                        </div>
                    </div>

                    <div className="flex flex-col gap-3 text-sm font-semibold mt-5 mb-8 items-center">
                        <span className="px-3 py-1 rounded-full text-primary bg-bg-secondary border border-primary inline-block">
                            Topic: {matchedSelections.topic}
                        </span>
                        <span className={`px-3 py-1 rounded-full bg-bg-secondary border ${getDifficultyColor(matchedSelections.difficulty)} inline-block`}>
                            Difficulty: {getDifficulties(matchedSelections.difficulty)}
                        </span>
                        <span className="px-3 py-1 rounded-full text-primary bg-bg-secondary border border-primary inline-block">
                            Language: {matchedSelections.language}
                        </span>
                    </div>

                    <p>
                        <Loader2 className="inline-block animate-spin mr-2" />
                        Please wait while we create the collaboration space...
                    </p>
                    {/* 
                    <button
                        onClick={onQuit}
                        className="mt-8 w-full text-lg font-bold py-3 rounded-lg border-2 bg-red-500 hover:bg-red-600">
                        Quit Match
                    </button> 
                    */}
                </div>
            </div>
        </div>
    );
}

export default MatchFound;