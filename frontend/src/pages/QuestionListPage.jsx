import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Filter, ChevronLeft, ChevronRight, X, ArrowUpDown, Check } from 'lucide-react';
import { questionService } from '../api/services/questionService';
import { useNotification } from '../contexts/NotificationContext';

const QUESTIONS_PER_PAGE = 10;

const QuestionPage = () => {
    const navigate = useNavigate();
    const { showError } = useNotification();
    
    const [questions, setQuestions] = useState([]);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalPages, setTotalPages] = useState(1);
    const [totalCount, setTotalCount] = useState(0);
    const [isLoading, setIsLoading] = useState(false);
    const [isInitialLoad, setIsInitialLoad] = useState(true);
    
    const [selectedDifficulties, setSelectedDifficulties] = useState([]);
    const [selectedTopics, setSelectedTopics] = useState([]);
    const [showFilters, setShowFilters] = useState(false);
    const [showSortMenu, setShowSortMenu] = useState(false);
    
    const [sortField, setSortField] = useState('created_at');
    const [sortOrder, setSortOrder] = useState('desc');
    
    const [availableTopics, setAvailableTopics] = useState([]);
    const [availableDifficulties, setAvailableDifficulties] = useState([]);

    useEffect(() => {
        const fetchOptions = async () => {
            try {
                const topics = await questionService.getTopics();
                const difficulties = await questionService.getDifficulties();
                setAvailableTopics(topics);
                setAvailableDifficulties(difficulties);
            } catch (error) {
                console.error('Failed to fetch filter options:', error);
            }
        };
        fetchOptions();
    }, []);

    // Fetch questions when filters or page changes
    useEffect(() => {
        fetchQuestions();
    }, [currentPage, selectedDifficulties, selectedTopics, sortField, sortOrder]);

    const fetchQuestions = async () => {
        setIsLoading(true);
        try {
            const params = {
                page: currentPage,
                page_size: QUESTIONS_PER_PAGE,
                sort: sortField,
                order: sortOrder
            };
            
            if (selectedDifficulties.length > 0) {
                params.difficulty = selectedDifficulties[0]; 
            }
            
            if (selectedTopics.length > 0) {
                params.topic = selectedTopics;
            }
            
            console.log('Fetching questions with params:', params);
            
            const response = await questionService.getQuestions(params);
            
            console.log('API Response:', response);
            console.log('Questions received:', response.results?.length);
            
            setQuestions(response.results || []);
            setTotalCount(response.count || 0);
            setTotalPages(Math.ceil((response.count || 0) / QUESTIONS_PER_PAGE));
        } catch (error) {
            console.error('Error fetching questions:', error);
            showError('Error', 'Failed to load questions');
            setQuestions([]);
        } finally {
            setIsLoading(false);
            setIsInitialLoad(false);
        }
    };

    const handleDifficultyToggle = (difficulty) => {
        setSelectedDifficulties(prev => 
            prev.includes(difficulty)
                ? [] 
                : [difficulty] 
        );
        setCurrentPage(1);
    };

    const handleTopicToggle = (topic) => {
        setSelectedTopics(prev => 
            prev.includes(topic)
                ? prev.filter(t => t !== topic)
                : [...prev, topic]
        );
        setCurrentPage(1);
    };

    const clearFilters = () => {
        setSelectedDifficulties([]);
        setSelectedTopics([]);
        setCurrentPage(1);
    };

    const getDifficultyColor = (difficulty) => {
        switch (difficulty?.toLowerCase()) {
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

    const handleQuestionClick = (questionId) => {
        console.log('Navigating to question with ID:', questionId);
        if (!questionId) {
            console.error('Question ID is undefined or null');
            showError('Error', 'Invalid question ID');
            return;
        }
        navigate(`/questions/${questionId}`);
    };

    const handleSort = (field) => {
        if (sortField === field) {
            // Toggle order if same field
            setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
        } else {
            // New field, default to ascending
            setSortField(field);
            setSortOrder('asc');
        }
        setCurrentPage(1);
        setShowSortMenu(false);
    };

    const getTopicDisplay = (topics) => {
        if (!topics) return '-';
        if (typeof topics === 'string') {
            try {
                const parsed = JSON.parse(topics);
                return Array.isArray(parsed) ? parsed.join(', ') : topics;
            } catch {
                return topics;
            }
        }
        return Array.isArray(topics) ? topics.join(', ') : topics.toString();
    };

    return (
        <div className="min-h-screen bg-background p-8 page-transition">
            <div className="max-w-7xl mx-auto">
                <div className="mb-8">
                    <h1 className="text-4xl font-bold text-white mb-2">Question List</h1>
                    <p className="text-gray-400">Practice the questions available on PeerPrep before collaborating with others.</p>
                </div>

                <div className="bg-background-secondary border border-gray-700 rounded-lg p-4 mb-6">
                    <div className="flex gap-3">
                        <div className="relative">
                            <button
                                onClick={() => setShowSortMenu(!showSortMenu)}
                                className="flex items-center gap-2 px-4 py-2 bg-background border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-800 transition-colors whitespace-nowrap"
                            >
                                <ArrowUpDown className="w-5 h-5" />
                                Sort
                            </button>
                            {showSortMenu && (
                                <div className="absolute left-0 mt-2 w-40 bg-background-secondary border border-gray-700 rounded-lg shadow-xl z-10">
                                    <div className="py-1">
                                        {[
                                            { label: 'Difficulty', value: 'difficulty' },
                                            { label: 'Time Created', value: 'newest' }
                                        ].map((option) => (
                                            <button
                                                key={option.value}
                                                onClick={() => handleSort(option.value)}
                                                className={`w-full text-left px-4 py-2 text-sm bg-background-secondary hover:bg-gray-800 transition-colors ${
                                                    sortField === option.value ? 'text-primary font-medium' : 'text-gray-300'
                                                }`}
                                            >
                                                {option.label} {sortField === option.value && `(${sortOrder === 'asc' ? '↑' : '↓'})`}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>

                        <button
                            onClick={() => setShowFilters(!showFilters)}
                            className="flex items-center gap-2 px-4 py-2 bg-background border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-800 transition-colors"
                        >
                            <Filter className="w-5 h-5" />
                            Filter
                            {(selectedDifficulties.length > 0 || selectedTopics.length > 0) && (
                                <span className="ml-1 px-2 py-0.5 bg-primary text-white text-xs rounded-full">
                                    {selectedDifficulties.length + selectedTopics.length}
                                </span>
                            )}
                        </button>
                    </div>

                    {showFilters && (
                        <div className="space-y-4 pt-4 border-t m-2 border-gray-700">
                            {/* Difficulty Filters */}
                            <div>
                                <label className="block text-sm font-medium text-gray-300 mb-2">
                                    Difficulty
                                </label>
                                <div className="flex flex-wrap gap-2">
                                    {availableDifficulties.map((difficulty) => (
                                        <button
                                            key={difficulty}
                                            onClick={() => handleDifficultyToggle(difficulty)}
                                            className={`px-3 py-1 text-sm rounded border transition-colors ${
                                                selectedDifficulties.includes(difficulty)
                                                    ? 'font-medium'
                                                    : 'text-gray-400 bg-gray-900/20 border-gray-700 hover:border-gray-600'
                                            }`}
                                        >
                                            {difficulty}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-300 mb-2">
                                    Topics
                                </label>
                                <div className="flex flex-wrap gap-2">
                                    {availableTopics.map((topic) => (
                                        <button
                                            key={topic}
                                            onClick={() => handleTopicToggle(topic)}
                                            className={`px-3 py-1 text-sm rounded border transition-colors ${
                                                selectedTopics.includes(topic)
                                                    ? 'font-medium'
                                                    : 'text-gray-400 bg-gray-900/20 border-gray-700 hover:border-gray-600'
                                            }`}
                                        >
                                            {topic}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {(selectedDifficulties.length > 0 || selectedTopics.length > 0) && (
                                <button
                                    onClick={clearFilters}
                                    className="flex items-center gap-2 text-sm text-red-400 bg-red-900/40 hover:bg-red-800 border border-red-800 transition-colors"
                                >
                                    <X className="w-4 h-4" />
                                    Clear all filters
                                </button>
                            )}
                        </div>
                    )}
                </div>

                {/* Questions Table */}
                {isInitialLoad && isLoading ? (
                    <div className="flex items-center justify-center py-20">
                        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
                        <span className="ml-3 text-gray-400 text-lg">Loading questions...</span>
                    </div>
                ) : questions.length === 0 ? (
                    <div className="bg-background-secondary border border-gray-700 rounded-lg p-12 text-center">
                        <p className="text-gray-400 text-lg">No questions found</p>
                        <p className="text-gray-500 text-sm mt-2">Try adjusting your filters or search term</p>
                    </div>
                ) : (
                    <>
                        {/* Table */}
                        <div className="bg-background-secondary border border-gray-700 rounded-lg overflow-hidden">
                            <div className="overflow-x-auto">
                                <table className="w-full">
                                    <thead className="bg-gray-800/50 border-b border-gray-700">
                                        <tr>
                                            <th className="px-4 py-3 text-left text-xs font-semibold text-gray-300 uppercase tracking-wider w-16">
                                                Index
                                            </th>
                                            <th className="px-4 py-3 text-left text-xs font-semibold text-gray-300 uppercase tracking-wider">
                                                Title
                                            </th>
                                            <th className="px-4 py-3 text-left text-xs font-semibold text-gray-300 uppercase tracking-wider">
                                                Topic
                                            </th>
                                            <th className="px-4 py-3 text-left text-xs font-semibold text-gray-300 uppercase tracking-wider w-28">
                                                Difficulty
                                            </th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-gray-700">
                                        {questions.map((question, index) => {
                                            const globalIndex = (currentPage - 1) * QUESTIONS_PER_PAGE + index + 1;
                                            const questionId = question.question_id 
                                            
                                            return (
                                                <tr
                                                    key={questionId || index}
                                                    onClick={() => handleQuestionClick(questionId)}
                                                    className="hover:bg-gray-800/40 cursor-pointer transition-colors"
                                                >
                                                    <td className="px-4 py-4 text-sm text-gray-400">
                                                        {globalIndex}
                                                    </td>
                                                    <td className="px-4 py-4">
                                                        <div className="text-sm font-medium text-gray-200 hover:text-primary transition-colors">
                                                            {question.title}
                                                        </div>
                                                    </td>
                                                    <td className="px-4 py-4">
                                                        <div className="text-sm text-gray-400 truncate max-w-xs">
                                                            {getTopicDisplay(question.topics)}
                                                        </div>
                                                    </td>
                                                    <td className="px-4 py-4">
                                                        <span className={`inline-flex items-center justify-center w-20 px-2 py-1 text-xs font-semibold rounded border ${getDifficultyColor(question.difficulty)}`}>
                                                            {question.difficulty || 'N/A'}
                                                        </span>
                                                    </td>
                                                </tr>
                                            );
                                        })}
                                    </tbody>
                                </table>
                            </div>
                        </div>

                        <div className="flex items-center justify-between mt-6">
                            <div className="text-sm text-gray-400">
                                Showing {(currentPage - 1) * QUESTIONS_PER_PAGE + 1} to {Math.min(currentPage * QUESTIONS_PER_PAGE, totalCount)} of {totalCount} questions
                            </div>
                            
                            <div className="flex items-center gap-4">
                                <button
                                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                                    disabled={currentPage === 1}
                                    className="flex items-center gap-2 px-4 py-2 bg-background-secondary border border-gray-700 rounded-lg text-gray-300 hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                                >
                                    <ChevronLeft className="w-4 h-4" />
                                    Previous
                                </button>

                                <span className="text-gray-400">
                                    Page {currentPage} of {totalPages}
                                </span>

                                <button
                                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                                    disabled={currentPage >= totalPages}
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
        </div>
    );
};

export default QuestionPage;
