import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { ArrowLeft, GripVertical } from "lucide-react";
import { questionService } from "../api/services/questionService";
import { useNotification } from "../contexts/NotificationContext";
import DetailCodeEditor from "../components/question/DetailCodeEditor";
import DetailQuestionPanel from "../components/question/DetailQuestionPanel";

const QuestionDetailPage = () => {
  const { id } = useParams(); // Match the route parameter name
  const navigate = useNavigate();
  const { showError } = useNotification();
  
  const [questionData, setQuestionData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [leftPanelSplit, setLeftPanelSplit] = useState(50); // percentage for question panel
  const [isDragging, setIsDragging] = useState(false);
  const [selectedLanguage, setSelectedLanguage] = useState("python");
  const leftPanelRef = useRef(null);

  // Fetch question data
  useEffect(() => {
    const fetchQuestion = async () => {
      if (!id) {
        console.error('No question ID in URL params');
        showError('Error', 'No question ID provided');
        navigate('/questions');
        return;
      }
      
      console.log('Fetching question with ID:', id);

      setIsLoading(true);
      try {
        const data = await questionService.getQuestion(id);
        if (!data) {
          showError('Error', 'Question not found');
          navigate('/questions');
          return;
        }
        console.log('Question data loaded:', data);
        setQuestionData(data);
      } catch (error) {
        console.error('Failed to fetch question:', error);
        showError('Error', 'Failed to load question');
        navigate('/questions');
      } finally {
        setIsLoading(false);
      }
    };

    fetchQuestion();
  }, [id]);

  // Handle panel resize
  const handleMouseDown = () => {
    setIsDragging(true);
  };

  useEffect(() => {
    const handleMouseMove = (e) => {
      if (!isDragging || !leftPanelRef.current) return;

      const containerRect = leftPanelRef.current.parentElement.getBoundingClientRect();
      const newSplit = ((e.clientX - containerRect.left) / containerRect.width) * 100;

      // Constrain between 20% and 80%
      if (newSplit >= 20 && newSplit <= 80) {
        setLeftPanelSplit(newSplit);
      }
    };

    const handleMouseUp = () => {
      setIsDragging(false);
    };

    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    }

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging]);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-background">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        <span className="ml-3 text-gray-400 text-lg">Loading question...</span>
      </div>
    );
  }

  if (!questionData) {
    return null;
  }

  return (
    <div className="flex flex-col w-screen h-screen bg-background page-transition">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 bg-background-secondary border-b border-gray-700">
        <div className="flex items-center gap-4">
          <button
            onClick={() => navigate('/questions')}
            className="flex items-center gap-2 px-3 py-2 text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            Back to Questions List
          </button>
          <div className="h-6 w-px bg-gray-700" />
        </div>

        {/* Language Selector */}
        <div className="flex items-center gap-4">
            <label htmlFor="language-select" className="text-gray-300">Select Language:</label>
            <select
            id="language-select"
            value={selectedLanguage}
            onChange={(e) => setSelectedLanguage(e.target.value)}
            className="px-4 py-2 bg-background border border-gray-600 rounded-lg text-gray-300 focus:outline-none focus:ring-2 focus:ring-primary"
            >
            <option value="python">Python</option>
            <option value="javascript">JavaScript</option>
            <option value="java">Java</option>
            <option value="cpp">C++</option>
            <option value="c">C</option>
            </select>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex flex-1 overflow-hidden">
        {/* Left Panel - Question */}
        <div
          ref={leftPanelRef}
          style={{ width: `${leftPanelSplit}%` }}
          className="flex flex-col border-r border-gray-700 overflow-y-auto overflow-x-hidden"
        >
          <DetailQuestionPanel question={questionData} />
        </div>

        {/* Resizer */}
        <div
          className={`w-2 bg-gray-800 hover:bg-gray-700 cursor-col-resize flex items-center justify-center transition-colors ${
            isDragging ? 'bg-primary' : ''
          }`}
          onMouseDown={handleMouseDown}
        >
          <GripVertical className="w-4 h-4 text-gray-600" />
        </div>

        {/* Right Panel - Code Editor */}
        <div
          style={{ width: `${100 - leftPanelSplit}%` }}
          className="flex flex-col overflow-hidden"
        >
          <DetailCodeEditor
            language={selectedLanguage}
            questionId={id}
          />
        </div>
      </div>
    </div>
  );
};

export default QuestionDetailPage;