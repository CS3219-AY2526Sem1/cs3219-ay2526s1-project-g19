import { Children, useEffect, useMemo, useState } from "react";
import { ChevronDown } from "lucide-react";
import { useMatchingSocket } from "../../hooks/useMatchingSocket";
import { useAuth } from "../../contexts/AuthContext";
import CancelConfirmation from "./CancelConfirmation";
import FindingMatch from "./FindingMatch";
import MatchFound from "./MatchFound";
import MatchNotFound from "./MatchNotFound";
import { questionService } from "../../api/services/questionService";
import { matchingService as matchingApiService } from "../../api/services/matchingService";

const DEFAULT_TOPICS = [
    "Array",
    "String",
    "Two Pointers",
    "Sliding Window",
    "Matrix",
    "Hashmap",
    "Intervals",
    "stack",
    "Linked List",
    "Binary Tree General",
    "Binary Tree BFS",
    "Binary Search Tree",
    "Graph General",
    "Graph BFS",
    "Trie",
    "Backtracking",
    "Divide and Conquer",
    "Kadane's Algorithm",
    "Binary Search",
    "Heap",
    "Bit Manipulation",
    "Math",
    "1D DP",
    "Multi-D DP"
];

const DEFAULT_DIFFICULTIES = ["easy", "medium","hard"];

const DEFAULT_LANGUAGES = [
    "Python",
    "Java",
    "Javascript",
    "C",
    "C++",
    "Default" // See if backend retrieve from api or default
];

const ANY_DIFFICULTY_OPTION = "Any";

const capitalize = (value) => {
    if (!value) return value;
    return value.charAt(0).toUpperCase() + value.slice(1);
};

// Helper functions
const BubbleLabels = ({ label, isSelected, onClick}) => {
    const baseClass = "px-3 py-1 rounded-full border cursor-pointer select-none font-ubuntu text-sm transition duration-200";
    const selectedClass = "bg-primary text-gray-100 border-primary hover:bg-primary-dark hover:border-primary-dark";
    const unselectedClass = "bg-gray-700 text-gray-200 border border-gray-600 hover:text-white hover:bg-primary";

    return (
        <span
            onClick={onClick}
            className={`${baseClass} ${isSelected ? selectedClass : unselectedClass}`}
        >
            {label}
        </span>
    );
};


const MatchingForm = () => {
    const { user } = useAuth();
    const [topicOptions, setTopicOptions] = useState(DEFAULT_TOPICS);
    const [difficultyOptions, setDifficultyOptions] = useState(DEFAULT_DIFFICULTIES);
    const [languageOptions, setLanguageOptions] = useState(DEFAULT_LANGUAGES);
    const [optionsLoading, setOptionsLoading] = useState(false);
    const [optionsError, setOptionsError] = useState(null);
    const [hasLoadedOptions, setHasLoadedOptions] = useState(false);

    const [selections, setSelections] = useState({
        topics: [],
        difficulties: [],
        preferredLanguage: '',
        backupLanguages: []
    });

    const [isDropdownOpen, setIsDropdownOpen] = useState(false);
    const [showCancelConfirm, setShowCancelConfirm] = useState(false);
    const [confirmAction, setConfirmAction] = useState('');

    useEffect(() => {
        const loadOptions = async () => {
            setOptionsLoading(true);
            try {
                const [topics, difficulties, languages] = await Promise.all([
                    questionService.getTopics(),
                    questionService.getDifficulties(),
                    matchingApiService.getLanguages()
                ]);

                const safeTopics = topics.length ? topics : DEFAULT_TOPICS;
                const safeDifficulties = difficulties.length ? difficulties : DEFAULT_DIFFICULTIES;
                const safeLanguages = languages.length ? languages : DEFAULT_LANGUAGES;

                setTopicOptions(safeTopics);
                setDifficultyOptions(safeDifficulties);
                setLanguageOptions(safeLanguages);

                setSelections((prev) => {
                    const filteredTopics = prev.topics.filter((topic) => safeTopics.includes(topic));
                    const filteredBackup = prev.backupLanguages.filter((lang) => safeLanguages.includes(lang));
                    const preferredLanguage = safeLanguages.includes(prev.preferredLanguage) ? prev.preferredLanguage : '';

                    let filteredDifficulties = prev.difficulties.includes(ANY_DIFFICULTY_OPTION)
                        ? [ANY_DIFFICULTY_OPTION]
                        : prev.difficulties.filter((difficulty) => safeDifficulties.includes(difficulty));

                    if (filteredDifficulties.length === safeDifficulties.length) {
                        filteredDifficulties = [ANY_DIFFICULTY_OPTION];
                    }

                    return {
                        ...prev,
                        topics: filteredTopics,
                        difficulties: filteredDifficulties,
                        preferredLanguage,
                        backupLanguages: filteredBackup
                    };
                });

                setOptionsError(null);
            } catch (error) {
                console.error('Failed to load matching options', error);
                setOptionsError('Unable to load latest options. Using default values.');
                setTopicOptions(DEFAULT_TOPICS);
                setDifficultyOptions(DEFAULT_DIFFICULTIES);
                setLanguageOptions(DEFAULT_LANGUAGES);
            } finally {
                setOptionsLoading(false);
                setHasLoadedOptions(true);
            }
        };

        // Only load if haven't loaded yet
        if (!hasLoadedOptions) {
            void loadOptions();
        }
    }, [hasLoadedOptions]);

    const sortedTopicOptions = useMemo(() => [...topicOptions].sort((a, b) => a.localeCompare(b)), [topicOptions]);
    const difficultyOptionDetails = useMemo(() => difficultyOptions.map((value) => ({
        value,
        label: capitalize(value)
    })), [difficultyOptions]);
    const sortedLanguageOptions = useMemo(() => [...languageOptions].sort((a, b) => a.localeCompare(b)), [languageOptions]);
    
    // Use Socket.IO-like hook for consistency with collaboration service
    const { 
        isConnected,
        isMatching, 
        matchFound,
        sessionData,
        error,
        isRelaxed,
        startMatching, 
        cancelMatching,
        resetMatch
    } = useMatchingSocket();

    // Handlers for selections
    // For bubble selections: topics, backupLanguages
    const handleBubbleToggle = (field, item) => {
        if (field === 'topics' && !topicOptions.includes(item)) {
            return;
        }
        if (field === 'backupLanguages' && !languageOptions.includes(item)) {
            return;
        }

        setSelections(prev => {
            const currentSelections = prev[field];
            const isSelected = currentSelections.includes(item);

            let updatedSelections;

            if (isSelected) {
                updatedSelections = currentSelections.filter(i => i !== item);
            } else {
                // Enforced max 2 selections for backupLanguages
                if (field === 'backupLanguages' && currentSelections.length >= 2) {
                    return prev; // Do nothing if already 2 selected
                } else {
                    updatedSelections = [...currentSelections, item];
                }
            }

            return {...prev, [field]: updatedSelections};
        });
    }

    // For difficulty selection
    const handleDifficultyToggle = (difficulty) => {
        setSelections(prev => {
            const current = prev.difficulties;

            if (difficulty === ANY_DIFFICULTY_OPTION) {
                const hasAny = current.includes(ANY_DIFFICULTY_OPTION);
                return {
                    ...prev,
                    difficulties: hasAny ? [] : [ANY_DIFFICULTY_OPTION]
                };
            }

            let withoutAny = current.filter(value => value !== ANY_DIFFICULTY_OPTION);
            if (withoutAny.includes(difficulty)) {
                withoutAny = withoutAny.filter(value => value !== difficulty);
            } else {
                withoutAny = [...withoutAny, difficulty];
            }

            if (withoutAny.length === difficultyOptions.length) {
                return {
                    ...prev,
                    difficulties: [ANY_DIFFICULTY_OPTION]
                };
            }

            return {
                ...prev,
                difficulties: withoutAny
            };
        });
    }

    const isAnySelected = selections.difficulties.includes(ANY_DIFFICULTY_OPTION);

    // Handler for preferred language dropdown
    const handlePreferredLanguageSelect = (language) => {
        setSelections(prev => ({...prev, preferredLanguage: language}));
        setIsDropdownOpen(false);
    }

    const renderLanguageDropdown = sortedLanguageOptions.map(lang => (
        <div
            key={lang}
            className={"px-4 py-2 hover:bg-gray-900 cursor-pointer text-gray-200"}
            onClick={() => handlePreferredLanguageSelect(lang)}
        >
            {lang}
        </div>
    ));

    // Form submission handler
    const handleSubmit = async (e) => {
        e.preventDefault();

        // Convert "Any" difficulty to all available difficulties
        let submittedDifficulties = selections.difficulties;
        if (selections.difficulties.includes(ANY_DIFFICULTY_OPTION)) {
            submittedDifficulties = difficultyOptions;
        }

        // Prepare matching criteria for the backend (match backend schema)
        const criteria = {
            topics: selections.topics.length > 0 ? selections.topics : [],
            difficulty: submittedDifficulties.length > 0 ? submittedDifficulties : [],
            primary_lang: selections.preferredLanguage || null,
            secondary_lang: selections.backupLanguages.length > 0 ? selections.backupLanguages : [],
            proficiency: 0 // Default proficiency level
        };

        try {
            await startMatching(criteria);
        } catch (err) {
            console.error('Failed to start matching:', err);
        }
    }

    // Handle cancel button click during matching
    const handleCancelClick = () => {
        setConfirmAction('confirm_cancel');
        setShowCancelConfirm(true);
    };

    // Handle quit button click when match is found
    const handleQuitClick = () => {
        setConfirmAction('confirm_leave');
        setShowCancelConfirm(true);
    };

    // Confirm cancellation/quit
    const handleConfirmAction = async () => {
        if (confirmAction === 'confirm_cancel') {
            await cancelMatching();
        } else if (confirmAction === 'confirm_leave') {
            await cancelMatching();
            resetMatch();
        }
        setShowCancelConfirm(false);
        setConfirmAction('');
    };

    // Cancel confirmation dialog
    const handleCancelConfirmation = () => {
        setShowCancelConfirm(false);
        setConfirmAction('');
    };

    // Handle rematch (Use same criteria)
    const handleRematch = async () => {
        // Convert "Any" difficulty to all available difficulties
        let submittedDifficulties = selections.difficulties;
        if (selections.difficulties.includes(ANY_DIFFICULTY_OPTION)) {
            submittedDifficulties = difficultyOptions;
        }

        const criteria = {
            topics: selections.topics.length > 0 ? selections.topics : [],
            difficulty: submittedDifficulties.length > 0 ? submittedDifficulties : [],
            primary_lang: selections.preferredLanguage || null,
            secondary_lang: selections.backupLanguages.length > 0 ? selections.backupLanguages : [],
            proficiency: 0 // Set as 0 as haven't implement this yet
        };
        
        resetMatch();
        try {
            await startMatching(criteria);
        } catch (err) {
            console.error('Failed to rematch:', err);
        }
    };

    // Handle return to form from match not found
    const handleReturnToForm = () => {
        resetMatch();
    };

    // Show different components based on current state
    if (isMatching) {
        return (
            <>
                <FindingMatch 
                    selections={{
                        topic: selections.topics.join(', ') || 'Any',
                        difficulty: selections.difficulties.join(', ') || 'Any',
                        preferredLanguage: selections.preferredLanguage || 'Any',
                        backupLanguages: selections.backupLanguages || []
                    }}
                    isRelaxed={isRelaxed}
                    onCancel={handleCancelClick}
                />
                {/* Confirmation Dialog */}
                {showCancelConfirm && (
                    <CancelConfirmation 
                        actionType={confirmAction}
                        onConfirm={handleConfirmAction}
                        onCancel={handleCancelConfirmation}
                    />
                )}
            </>
        );
    }

    if (matchFound && sessionData) {
        return (
            <>
                <MatchFound 
                    user1={user?.display_name || "You"}
                    user2="Matched User" // Need API to get name
                    matchedSelections={{
                        topic: sessionData.topics?.[0] || 'Any',
                        difficulty: sessionData.difficulty || 'Any',
                        language: sessionData.language || 'JavaScript'
                    }}
                    sessionData={sessionData}
                    onQuit={handleQuitClick}
                />
                {/* Confirmation Dialog */}
                {showCancelConfirm && (
                    <CancelConfirmation 
                        actionType={confirmAction}
                        onConfirm={handleConfirmAction}
                        onCancel={handleCancelConfirmation}
                    />
                )}
            </>
        );
    }

    if (error && (error.includes('No match found') || error.includes('Partner quit'))) {
        const isPartnerQuit = error.includes('Partner quit');
        
        return (
            <MatchNotFound 
                title={isPartnerQuit ? "Partner Left" : "No Match Found"}
                message={isPartnerQuit 
                    ? "Your partner has left the match." 
                    : "We couldn't find a suitable match based on your preferences."
                }
                subtitle={isPartnerQuit 
                    ? "Don't worry! You can try finding a new match."
                    : "You can try adjusting your preferences or match again."
                }
                onRematch={handleRematch}
                onReturn={handleReturnToForm}
            />
        );
    }

    return (
        <>
            <div className="bg-background-secondary p-6 rounded-xl w-full max-w-6xl shadow-2xl border border-gray-700">
                {/* Form Header */}
                <div className="mb-4 border-b border-gray-700 pb-4">
                    <h3 className="text-white font-bold">
                        Find a match
                    </h3>
                    <p className="text-gray-400 text-s pt-3">
                        System will find a match based on your selected topics, difficulty and programming language.
                    </p>
                </div>

                {/* Topic Selection */}
                <section className="mb-8">
                    <h4 className ="text-white font-semibold mb-3">
                        Topics: <span className="text-sm font-normal text-gray-400 pl-1">Select one or more, default is set as Any</span>
                    </h4>
                    <div className="flex flex-wrap gap-3 border border-gray-600 p-4 rounded-lg max-h-48 overflow-y-auto justify-start">
                        {topicOptions.map(topic => (
                            <BubbleLabels
                                key={topic}
                                label={topic}
                                isSelected={selections.topics.includes(topic)}
                                onClick={() => handleBubbleToggle('topics', topic)}
                            />
                        ))}
                    </div>
                </section>

                {/* Difficulty Selection */}
                <section className="mb-8">
                    <h4 className ="text-white font-semibold mb-3">
                        Difficulty: <span className="text-sm font-normal text-gray-400 pl-1">Select one or more</span>
                    </h4>
                    {difficultyOptions.map(difficulty => (
                        <label key={difficulty} className="inline-flex items-center mr-6 mb-2 cursor-pointer">
                            <input
                                type="checkbox"
                                name="difficulty"
                                value={difficulty}
                                checked={selections.difficulties.includes(difficulty) || isAnySelected}
                                onChange={() => handleDifficultyToggle(difficulty)}
                                disabled={isAnySelected && difficulty !== ANY_DIFFICULTY_OPTION}
                                className="form-checkbox h-5 w-5 text-primary bg-gray-700 border-gray-600 rounded focus:ring-0 cursor-pointer"
                            />
                            <span className="ml-2 text-gray-200 select-none">{capitalize(difficulty)}</span>
                        </label>
                    ))}
                    <label className="inline-flex items-center mr-6 mb-2 cursor-pointer">
                        <input
                            type="checkbox"
                            name="difficulty"
                            value={ANY_DIFFICULTY_OPTION}
                            checked={isAnySelected}
                            onChange={() => handleDifficultyToggle(ANY_DIFFICULTY_OPTION)}
                            className="form-checkbox h-5 w-5 text-secondary bg-gray-700 border-gray-600 rounded focus:ring-0 cursor-pointer"
                        />
                        <span className="ml-2 text-gray-200 select-none">Any</span>
                    </label>
                </section>

                {/* Preferred Language Selection */}
                <section className="grid mb-8 md:grid-cols-2 gap-8 mb-5">
                    <div>
                        <h4 className="text-white font-semibold mb-3">
                            Preferred Language: <span className="text-sm font-normal text-gray-400 pl-1">Select one</span>
                        </h4>
                        <div className="relative">
                            <button
                                type="button"
                                className="w-full bg-gray-700 text-gray-200 border border-gray-600 rounded-lg px-4 py-2 flex justify-between items-center focus:outline-none focus:ring-2 focus:ring-primary"
                                onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                            >
                                <span className="text-gray-200">
                                    {selections.preferredLanguage || "Select one language"}
                                </span>
                                <ChevronDown className="ml-2 h-4 w-4 text-gray-400" />
                            </button>
                            {isDropdownOpen && (
                                <div className="absolute z-10 mt-1 w-full bg-background-secondary border border-gray-600 rounded-lg shadow-lg max-h-40 overflow-y-auto">
                                    {renderLanguageDropdown}
                                </div>
                            )}
                        </div>
                    </div>
                    <div>
                        <h4 className="text-white font-semibold mb-3">
                            Backup Languages : <span className="text-sm font-normal text-gray-400 pl-1">Select up to two (Optional)</span>
                        </h4>
                        <div className="flex flex-wrap gap-3 border border-gray-600 p-4 rounded-lg max-h-48 overflow-y-auto justify-start">
                            {languageOptions.map(lang => (
                                <BubbleLabels
                                    key={lang}
                                    label={lang}
                                    isSelected={selections.backupLanguages.includes(lang)}
                                    onClick={() => handleBubbleToggle('backupLanguages', lang)}
                                />
                            ))}
                        </div>
                        <p className="text-sm text-gray-400 mt-2">
                            Enabled after 30s if no match found
                        </p>
                    </div>
                </section>

                {/* Submit Button */}
                <div className="text-center flex justify-center p-4">
                    <button
                        type="submit"
                        onClick={handleSubmit}
                        disabled={!selections.preferredLanguage}
                        className="bg-primary hover:bg-primary-dark text-white font-semibold py-2 px-6 rounded-lg transition duration-200 w-full disabled:bg-gray-600 disabled:cursor-not-allowed"
                    >
                        Find Match
                    </button>
                </div>
                
                {/* Error Messages */}
                {error && !error.includes('No match found') && (
                    <div className="text-center mt-4 p-4 bg-red-900 border border-red-600 rounded-lg">
                        <p className="text-red-300 font-semibold">Error: {error}</p>
                    </div>
                )}
            </div>

            {/* Confirmation Dialog */}
            {showCancelConfirm && (
                <CancelConfirmation 
                    actionType={confirmAction}
                    onConfirm={handleConfirmAction}
                    onCancel={handleCancelConfirmation}
                />
            )}
        </>
    );
}

export default MatchingForm;