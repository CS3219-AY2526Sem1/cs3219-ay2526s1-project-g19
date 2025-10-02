import { useState, useEffect, useRef, useCallback } from "react"
import CodeEditor from "../components/collaboration/CodeEditor"
import ChatBox from "../components/collaboration/ChatBox"
import QuestionPanel from "../components/collaboration/QuestionPanel"
import { Code2, Split, GripVertical } from "lucide-react"

const CollaborationPage = () => {
  const [username] = useState("User" + Math.floor(Math.random() * 1000))
  const [leftPanelSplit, setLeftPanelSplit] = useState(65) // percentage for question panel
  const [isDragging, setIsDragging] = useState(false)
  const leftPanelRef = useRef(null)
  const room = "example-room"

  // Handle vertical resizing for left panel
  const handleMouseDown = (e) => {
    e.preventDefault()
    setIsDragging(true)
  }

  const handleMouseMove = useCallback((e) => {
    if (!isDragging || !leftPanelRef.current) return
    
    const panel = leftPanelRef.current
    const rect = panel.getBoundingClientRect()
    const offsetY = e.clientY - rect.top
    const percentage = (offsetY / rect.height) * 100
    
    // Constrain between 20% and 80%
    const newSplit = Math.min(Math.max(percentage, 20), 80)
    setLeftPanelSplit(newSplit)
  }, [isDragging])

  const handleMouseUp = useCallback(() => {
    setIsDragging(false)
  }, [])

  useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove)
      document.addEventListener('mouseup', handleMouseUp)
      return () => {
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
      }
    }
  }, [isDragging, handleMouseMove, handleMouseUp])

  return (
    <div className="h-screen w-screen flex flex-col bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-50 dark:from-gray-950 dark:via-slate-900 dark:to-indigo-950">
      {/* Header */}
      <div className="bg-white/80 dark:bg-gray-900/80 backdrop-blur-xl border-b border-gray-200 dark:border-gray-800 shadow-sm flex-shrink-0">
        <div className="px-4 py-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-600 to-indigo-600 flex items-center justify-center">
                <Code2 className="w-4 h-4 text-white" />
              </div>
              <div>
                <h1 className="text-base font-bold text-gray-900 dark:text-white">
                  Collaborative Coding
                </h1>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  Room: {room} • {username}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content - Full Height Split */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Panel - Question + Chat with Resizable Split */}
        <div 
          ref={leftPanelRef}
          className="w-1/2 flex flex-col border-r border-gray-200 dark:border-gray-800"
        >
          {/* Question Panel */}
          <div 
            className="overflow-y-auto bg-white/60 dark:bg-gray-900/60"
            style={{ height: `${leftPanelSplit}%` }}
          >
            <QuestionPanel />
          </div>
          
          {/* Draggable Divider */}
          <div
            onMouseDown={handleMouseDown}
            className={`
              flex items-center justify-center h-2 bg-gray-200 dark:bg-gray-800 
              hover:bg-blue-400 dark:hover:bg-blue-600 cursor-row-resize 
              transition-colors duration-150 group relative
              ${isDragging ? 'bg-blue-500 dark:bg-blue-600' : ''}
            `}
          >
            <GripVertical className="w-5 h-5 text-gray-400 group-hover:text-white dark:text-gray-600 dark:group-hover:text-white rotate-90" />
          </div>
          
          {/* Chat Box */}
          <div 
            className="bg-white/60 dark:bg-gray-900/60 flex flex-col"
            style={{ height: `${100 - leftPanelSplit}%` }}
          >
            <ChatBox
              room={room}
              currentUsername={username}
            />
          </div>
        </div>

        {/* Right Panel - Code Editor */}
        <div className="w-1/2 overflow-y-auto bg-white/60 dark:bg-gray-900/60">
          <div className="p-2 h-full">
            <div className="bg-white/80 dark:bg-gray-900/80 backdrop-blur-xl rounded-lg shadow-xl border border-gray-200/50 dark:border-gray-800/50 p-3 h-full flex flex-col">
              <div className="flex items-center gap-2 mb-3 flex-shrink-0">
                <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
                  <Split className="w-4 h-4 text-white" />
                </div>
                <div>
                  <h2 className="text-base font-bold text-gray-900 dark:text-white">
                    Code Editor
                  </h2>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    Collaborate in real-time
                  </p>
                </div>
              </div>
              
              <div className="flex-1 overflow-y-auto">
                <CodeEditor 
                  room={room} 
                  currentUsername={username}
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default CollaborationPage;