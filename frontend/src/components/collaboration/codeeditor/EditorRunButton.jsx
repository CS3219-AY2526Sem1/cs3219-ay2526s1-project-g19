import { Play } from "lucide-react";

const EditorRunButton = ({ onClick, isRunning }) => (
  <button
    onClick={onClick}
    disabled={isRunning}
    className={`
      flex items-center gap-2 px-4 py-2  rounded-xl font-semibold shadow-lg
      transition-all duration-200 transform
      ${isRunning 
        ? 'bg-gray-400 cursor-not-allowed' 
        : 'bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 active:scale-95 cursor-pointer'
      }
      text-white
    `}
  >
    {isRunning ? (
      <>
        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
        <span>Running...</span>
      </>
    ) : (
      <>
        <Play className="w-4 h-4" fill="currentColor" />
        <span>Run Code</span>
      </>
    )}
  </button>
);

export default EditorRunButton;