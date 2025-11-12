import { TestTube } from "lucide-react";

const EditorRunTestsButton = ({ onClick, isRunning, disabled = false }) => (
  <button
    onClick={onClick}
    disabled={isRunning || disabled}
    className={`
      flex items-center gap-2 px-4 py-2 rounded-xl font-semibold shadow-lg
      transition-all duration-200 transform
      ${isRunning || disabled
        ? 'bg-gray-400 cursor-not-allowed' 
        : 'bg-primary hover:bg-blue-700 active:scale-95 cursor-pointer'
      }
      text-white
    `}
  >
    {isRunning ? (
      <>
        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
        <span>Running Tests...</span>
      </>
    ) : (
      <>
        <TestTube className="w-4 h-4" fill="currentColor" />
        <span>Run Tests</span>
      </>
    )}
  </button>
);

export default EditorRunTestsButton;


