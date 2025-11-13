import { useState, useEffect } from 'react';
import { Clock, Calendar, User, BookOpen, ChevronLeft, ChevronRight} from 'lucide-react';
import { sessionService } from '../../api/services/sessionService';
import { useNotification } from '../../contexts/NotificationContext';
import { userService } from '../../api/services/userService';

const SESSIONS_PER_PAGE = 5;

const SessionHistory = () => {
    const [sessions, setSessions] = useState([]);
    const [currentPage, setCurrentPage] = useState(1);
    const [isLoading, setIsLoading] = useState(true);
    const [hasMore, setHasMore] = useState(true);
    const [partnerNames, setPartnerNames] = useState({}); // Store partner names by user ID
    const { showError } = useNotification();

    useEffect(() => {
        fetchSessionHistory(currentPage);
    }, [currentPage]);

    const fetchSessionHistory = async (page) => {
        setIsLoading(true);
        try {
            const response = await sessionService.getHistory(page, SESSIONS_PER_PAGE);
            const data = response.data;
            console.log('Fetched session history:', data);
            
            // If we get an empty array, disable next 
            // If we get less than the page size, there are no more pages
            // Only enable next if we got exactly the page size AND it's not empty
            if (data.length === 0 && page > 1) {
                // Empty page after page 1 means we went too far, go back
                setCurrentPage(page - 1);
                setHasMore(false);
                return;
            }
            
            setHasMore(data.length === SESSIONS_PER_PAGE);
            setSessions(data);
            
            // Fetch partner names for all sessions
            const uniquePartnerIds = [...new Set(data.map(session => session.matched_user_id))];
            const names = {};
            
            await Promise.all(
                uniquePartnerIds.map(async (partnerId) => {
                    // Skip if we already have this partner's name
                    if (partnerNames[partnerId]) {
                        names[partnerId] = partnerNames[partnerId];
                        return;
                    }
                    
                    try {
                        const profileResponse = await userService.getPublicProfile(partnerId);
                        names[partnerId] = profileResponse.data?.user?.display_name || 'Unknown User';
                    } catch (error) {
                        console.error(`Failed to fetch partner name for ${partnerId}:`, error);
                        names[partnerId] = 'Unknown User';
                    }
                })
            );
            
            setPartnerNames(prev => ({ ...prev, ...names }));
        } catch (error) {
            console.error('Error fetching session history:', error);
            showError('Error', 'Failed to load session history');
            setSessions([]);
            setHasMore(false);
        } finally {
            setIsLoading(false);
        }
    };

    const formatDate = (dateString) => {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric',
            timeZone: 'Asia/Singapore'
        });
    };

    const formatTime = (dateString) => {
        const date = new Date(dateString);
        return date.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit',
            timeZone: 'Asia/Singapore'
        });
    };

    const calculateDuration = (startedAt, endedAt) => {
        if (!endedAt) return 'In Progress';
        
        const start = new Date(startedAt);
        const end = new Date(endedAt);
        const durationMs = end - start;
        
        const hours = Math.floor(durationMs / (1000 * 60 * 60));
        const minutes = Math.floor((durationMs % (1000 * 60 * 60)) / (1000 * 60));
        
        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        }
        return `${minutes}m`;
    };

    const getDifficultyColor = (difficulty) => {
        switch (difficulty.toLowerCase()) {
            case 'easy':
                return 'text-green-400 bg-green-900/20 border-green-700';
            case 'medium':
                return 'text-yellow-400 bg-yellow-900/20 border-yellow-700';
            case 'hard':
                return 'text-red-400 bg-red-900/20 border-red-700';
            default:
                return 'text-gray-400 bg-gray-900/20 border-gray-700';
        }
    };

    const handlePreviousPage = () => {
        if (currentPage > 1) {
            setCurrentPage(currentPage - 1);
        }
    };

    const handleNextPage = () => {
        if (hasMore) {
            setCurrentPage(currentPage + 1);
        }
    };

    if (isLoading && sessions.length === 0) {
        return (
            <div className="mt-8">
                <h2 className="text-2xl font-bold mb-4">Past Sessions</h2>
                <div className="flex items-center justify-center py-12">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                    <span className="ml-3 text-gray-400">Loading sessions...</span>
                </div>
            </div>
        );
    }

    return (
        <div className="mt-8">
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-2xl font-bold">Past Sessions</h2>
            </div>
            
            {sessions.length === 0 ? (
                <div className="bg-background-secondary border border-gray-700 rounded-lg p-8 text-center">
                    <BookOpen className="mx-auto h-12 w-12 text-gray-500 mb-3" />
                    <p className="text-gray-400">No past sessions yet</p>
                    <p className="text-gray-500 text-sm mt-2">Start collaborating to build your session history!</p>
                </div>
            ) : (
                <>
                    {/* Table */}
                    <div className="bg-background-secondary border border-gray-700 rounded-lg overflow-hidden">
                        <div className="overflow-x-auto">
                            <table className="w-full">
                                <thead className="bg-gray-800/50 border-b border-gray-700">
                                    <tr>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Date
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Question
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Topics
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Difficulty
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Language
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Partner
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                                            Duration
                                        </th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-700">
                                    {sessions.map((session) => (
                                        <tr 
                                            key={session.id}
                                            className="hover:bg-gray-800/30 transition-colors"
                                        >
                                            {/* Date & Time */}
                                            <td className="px-6 py-4">
                                                <div className="text-sm text-gray-300">
                                                    {formatDate(session.started_at)}
                                                </div>
                                                <div className="text-xs text-gray-500">
                                                    {formatTime(session.started_at)}
                                                </div>
                                            </td>

                                            {/* Question Title */}
                                            <td className="px-6 py-4">
                                                <div className="text-sm font-medium text-gray-200">
                                                    {session.question_title}
                                                </div>
                                            </td>

                                            {/* Topics */}
                                            <td className="px-6 py-4">
                                                <div className="flex flex-wrap gap-1 max-w-xs">
                                                    {session.topics && session.topics.length > 0 ? (
                                                        session.topics.slice(0, 2).map((topic, index) => (
                                                            <span 
                                                                key={index}
                                                                className="px-2 py-0.5 text-xs text-gray-200 rounded border border-gray-600"
                                                            >
                                                                {topic}
                                                            </span>
                                                        ))
                                                    ) : (
                                                        <span className="text-xs text-gray-500">-</span>
                                                    )}
                                                    {session.topics && session.topics.length > 2 && (
                                                        <span className="text-xs text-gray-500">
                                                            +{session.topics.length - 2}
                                                        </span>
                                                    )}
                                                </div>
                                            </td>

                                            {/* Difficulty */}
                                            <td className="px-6 py-4">
                                                <span className={`inline-flex px-2 py-1 text-xs font-medium rounded border ${getDifficultyColor(session.difficulty)}`}>
                                                    {session.difficulty}
                                                </span>
                                            </td>

                                            {/* Language */}
                                            <td className="px-6 py-4">
                                                <span className="text-sm text-gray-300 font-medium">
                                                    {session.language}
                                                </span>
                                            </td>

                                            {/* Partner */}
                                            <td className="px-6 py-4">
                                                <div className="flex items-center gap-2 text-sm text-gray-300">
                                                    <User className="w-4 h-4 text-gray-400" />
                                                    {partnerNames[session.matched_user_id] || 'Loading...'}
                                                </div>
                                            </td>

                                            {/* Duration */}
                                            <td className="px-6 py-4">
                                                <div className="flex items-center gap-1 text-sm text-gray-300">
                                                    <Clock className="w-4 h-4 text-gray-400" />
                                                    {calculateDuration(session.started_at, session.ended_at)}
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>

                    {/* Pagination Controls */}
                    <div className="flex items-center justify-between mt-6">
                        <div>
                        </div>
                        
                        <div className="flex items-center gap-4">
                            <button
                                onClick={handlePreviousPage}
                                disabled={currentPage === 1 || isLoading}
                                className="flex items-center gap-2 px-4 py-2 bg-background-secondary border border-gray-700 rounded-lg text-gray-300 hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                <ChevronLeft className="w-4 h-4" />
                                Previous
                            </button>

                            <span className="text-gray-400">
                                Page {currentPage}
                            </span>

                            <button
                                onClick={handleNextPage}
                                disabled={!hasMore || isLoading}
                                className="flex items-center gap-2 px-4 py-2 bg-background-secondary border border-gray-700 rounded-lg text-gray-300 hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                Next
                                <ChevronRight className="w-4 h-4" />
                            </button>
                        </div>
                    </div>
                </>
            )}
        </div>
    );
};

export default SessionHistory;
