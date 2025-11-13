import { useState, useEffect, useRef, useCallback } from "react"
import { useLocation, useNavigate, useParams } from "react-router-dom"
import { useAuth } from "../contexts/AuthContext"
import { userService } from "../api/services/userService"
import { sessionService } from "../api/services/sessionService"
import CodeEditor from "../components/collaboration/CodeEditor"
import ChatBox from "../components/collaboration/ChatBox"
import QuestionPanel from "../components/collaboration/QuestionPanel"
import LeaveRoomConfirmation from "../components/collaboration/LeaveRoomConfirmation"
import PartnerLeftModal from "../components/collaboration/PartnerLeftModal"
import { Code2, GripVertical, LogOut, Clock } from "lucide-react"

const CollaborationPage = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const { sessionId } = useParams(); 
  const { user } = useAuth();
  const [username] = useState(user?.display_name || "User" + Math.floor(Math.random() * 1000))
  const [partnerName, setPartnerName] = useState("")
  const [leftPanelSplit, setLeftPanelSplit] = useState(65) // percentage for question panel
  const [isDragging, setIsDragging] = useState(false)
  const [showLeaveConfirmation, setShowLeaveConfirmation] = useState(false)
  const [showPartnerLeftModal, setShowPartnerLeftModal] = useState(false)
  const [isPartnerConnected, setIsPartnerConnected] = useState(true) // Track partner connection status
  const [partnerHasPermanentlyLeft, setPartnerHasPermanentlyLeft] = useState(false) // Track if partner explicitly left
  const [sessionTime, setSessionTime] = useState(0) // Session time in seconds
  const leftPanelRef = useRef(null)
  const chatSocketRef = useRef(null)
  const timerRef = useRef(null)

  // Get session data from navigation state
  const sessionData = location.state?.sessionData;

  // Redirect to matching page if no session data or session ID
  useEffect(() => {
    if (!sessionData || !sessionId) {
      console.error('No session data or session ID found, redirecting to matching page');
      navigate('/matching');
    } else if (sessionData.session_id !== sessionId) {
      console.error('Session ID mismatch, redirecting to matching page');
      navigate('/matching');
    }
    
    // Reset partner connection states when entering a new session
    setIsPartnerConnected(true);
    setPartnerHasPermanentlyLeft(false);
    setShowPartnerLeftModal(false);
    setShowLeaveConfirmation(false);
    
    // Disconnect any existing socket when session changes
    if (chatSocketRef.current && chatSocketRef.current.connected) {
      console.log("Disconnecting old socket on session change");
      chatSocketRef.current.disconnect();
      chatSocketRef.current = null;
    }
  }, [sessionData, sessionId, navigate]);

  // Extract data from session
  const room = sessionId || "example-room"; 
  const language = sessionData?.language || "C";
  const partnerIds = sessionData?.user_id_list?.filter(id => id !== user?.id) || [];
  const partnerId = partnerIds[0] || "Unknown";

  // Fetch partner's name from user service
  useEffect(() => {
    const fetchPartnerName = async () => {
      if (partnerId && partnerId !== "Unknown") {
        try {
          console.log("Fetching partner profile for ID:", partnerId);
          const response = await userService.getPublicProfile(partnerId);
          console.log("Partner profile response:", response);
          setPartnerName(response.data?.user?.display_name || sessionData.partner_name || "Partner");
        } catch (error) {
          console.error('Failed to fetch partner profile:', error);
          console.error('Error response:', error.response);
          setPartnerName(sessionData.partner_name || "Partner");
        }
      } else {
        setPartnerName(sessionData.partner_name || "Partner");
      }
    };

    fetchPartnerName();
  }, [partnerId]);

  // Calculate and update session time
  useEffect(() => {
    if (!sessionData?.started_at) return;

    let startTime;
    
    // Handle both timestamp formats
    if (typeof sessionData.started_at === 'number') {
      // Unix timestamp in milliseconds
      startTime = new Date(sessionData.started_at);
    } else if (typeof sessionData.started_at === 'string') {
      // ISO string format
      startTime = new Date(sessionData.started_at + 'Z');
    } else {
      console.error('Invalid started_at format:', sessionData.started_at);
      return;
    }
    
    // Calculate initial elapsed time
    const calculateElapsedTime = () => {
      return Math.floor((Date.now() - startTime.getTime()) / 1000);
    };

    // Set initial time
    setSessionTime(calculateElapsedTime());

    // Update timer every second
    timerRef.current = setInterval(() => {
      setSessionTime(calculateElapsedTime());
    }, 1000);

    // Cleanup on unmount or sessionData change
    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, [sessionData?.started_at]);

  // Format session time as HH:MM:SS or MM:SS
  const formatSessionTime = (seconds) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Handle leave room confirmation
  const handleLeaveClick = () => {
    setShowLeaveConfirmation(true);
  };

  const handleCancelLeave = () => {
    setShowLeaveConfirmation(false);
  };

  const handleConfirmLeave = async () => {
    try {
      // When I leave, I DON'T end the session immediately
      // Partner can choose to stay and work alone, or leave later
      // Session only ends when BOTH have left
      
      // Emit leave event via chat socket to notify partner
      if (chatSocketRef.current) {
        chatSocketRef.current.emit("leave", { 
          room, 
          username
        });
        chatSocketRef.current.disconnect();
      }
      
      // Navigate back to matching page
      navigate('/matching');
    } catch (error) {
      console.error('Failed to leave room:', error);
      // Still navigate even if there's an error
      navigate('/matching');
    }
  };

  // Handle partner left modal
  const handleStayAfterPartnerLeft = () => {
    setShowPartnerLeftModal(false);
  };

  const handleLeaveAfterPartnerLeft = async () => {
    // Partner has left, now I'm leaving too
    // Don't call endSession() - the collaboration service will handle it
    // when the room becomes empty (after INACTIVE_SESSION_TIMEOUT)
    
    // Disconnect socket and navigate
    if (chatSocketRef.current) {
      chatSocketRef.current.emit("leave", { 
        room, 
        username
      });
      chatSocketRef.current.disconnect();
    }
    
    setShowPartnerLeftModal(false);
    navigate('/matching');
  };

  // Callback for partner permanently leaving (explicit leave action)
  const handlePartnerLeft = useCallback((data) => {
    console.log("Received partner-left event:", data);
    
    // Mark that partner has permanently left (not just disconnected)
    if (!partnerHasPermanentlyLeft) {
      setIsPartnerConnected(false);
      setPartnerHasPermanentlyLeft(true);
      setShowPartnerLeftModal(true);
    }
  }, [partnerHasPermanentlyLeft]);

  // Callback for partner temporarily disconnecting (network issue, refresh, etc.)
  const handlePartnerDisconnected = useCallback((data) => {
    console.log("Received partner-disconnected event:", data);
    
    // Only show disconnection status, don't show modal
    // Partner might reconnect
    setIsPartnerConnected(false);
  }, []);

  // Callback for partner rejoining after disconnect
  const handlePartnerRejoined = useCallback((data) => {
    console.log("Received user-joined event:", data);
    
    // If it's the partner, mark them as connected again
    if (data.username === partnerName || data.username !== username) {
      setIsPartnerConnected(true);
      // If they were marked as permanently left but reconnected, reset that
      if (partnerHasPermanentlyLeft) {
        setPartnerHasPermanentlyLeft(false);
        setShowPartnerLeftModal(false);
      }
    }
  }, [partnerName, username, partnerHasPermanentlyLeft]);

  // If no session data, show loading
  if (!sessionData || !sessionId) {
    return (
      <div className="h-screen w-screen flex items-center justify-center bg-background">
        <div className="text-white text-xl">Loading session...</div>
      </div>
    );
  }
  const questionId = "04132e60-9272-4438-a01d-b735bf1a1001" // Mock question ID for testing

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
      <div className="bg-background backdrop-blur-xl border-b border-gray-700 shadow-sm flex-shrink-0">
        <div className="px-4 py-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                <Code2 className="w-4 h-4 text-white" />
              </div>
              <div>
                <h1 className="text-base font-bold text-gray-200">
                  Collaborative Coding
                </h1>
                <p className="text-xs text-gray-400">
                  Room {room} : {username} collaborating with {partnerName}
                </p>
              </div>
            </div>

            {/* Session Timer and Leave Button */}
            <div className="flex items-center gap-3">
              {/* Session Timer */}
              <div className="flex items-center gap-2 bg-gradient-to-r from-slate-800 to-slate-700 px-4 py-2 rounded-lg border border-slate-600 shadow-md h-10">
                <Clock className="w-4 h-4 text-blue-400" />
                <div className="text-sm font-mono font-bold text-blue-400 tracking-wider">
                  {sessionData?.started_at ? formatSessionTime(sessionTime) : "--:--"}
                </div>
                <div className="text-xs text-gray-400 font-medium">
                  SESSION TIME
                </div>
              </div>

              {/* Leave Room Button */}
              <button
                onClick={handleLeaveClick}
                className="flex items-center gap-2 px-4 py-2 h-10 text-sm font-semibold text-gray-300 bg-red-500/10 hover:bg-red-500/20 border border-red-500 rounded-lg transition-colors"
                title="Leave Room"
              >
                <LogOut className="w-4 h-4" />
                Leave Room
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content - Full Height Split */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Panel - Question + Chat with Resizable Split */}
        <div
          ref={leftPanelRef}
          className="w-1/2 flex flex-col border-r border-gray-700"
        >
          {/* Question Panel */}
          <div
            className="overflow-y-auto bg-background"
            style={{ height: `${leftPanelSplit}%` }}
          >
            <QuestionPanel questionData={sessionData} />
          </div>

          {/* Draggable Divider */}
          <div
            onMouseDown={handleMouseDown}
            className={`
              flex items-center justify-center h-2 bg-gray-700
              hover:bg-primary cursor-row-resize
              transition-colors duration-150 group relative
              ${isDragging ? 'bg-primary' : ''}
            `}
          >
            <GripVertical className="w-5 h-5 text-gray-300 group-hover:text-white rotate-90" />
          </div>

          {/* Chat Box */}
          <div
            className="bg-background flex flex-col"
            style={{ height: `${100 - leftPanelSplit}%` }}
          >
            <ChatBox
              room={room}
              currentUsername={username}
              socketRef={chatSocketRef}
              onPartnerLeft={handlePartnerLeft}
              onPartnerDisconnected={handlePartnerDisconnected}
              onPartnerRejoined={handlePartnerRejoined}
            />
          </div>
        </div>

        {/* Right Panel - Code Editor */}
        <div className="w-2/3 overflow-y-auto bg-background">
          <div className="p-2 h-full">
            <div className="bg-background backdrop-blur-xl rounded-lg shadow-xl p-3 h-full flex flex-col">
              <CodeEditor
                room={room}
                currentUsername={username}
                language={language}
                questionId={questionId}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Leave Room Confirmation Modal */}
      {showLeaveConfirmation && (
        <LeaveRoomConfirmation
          onConfirm={handleConfirmLeave}
          onCancel={handleCancelLeave}
        />
      )}

      {/* Partner Left Modal */}
      {showPartnerLeftModal && (
        <PartnerLeftModal
          partnerName={partnerName}
          onStay={handleStayAfterPartnerLeft}
          onLeave={handleLeaveAfterPartnerLeft}
        />
      )}
    </div>
  )
}

export default CollaborationPage;