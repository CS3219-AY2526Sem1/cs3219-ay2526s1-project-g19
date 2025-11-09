import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { sessionService } from '../api/services/sessionService';
import { questionService } from '../api/services/questionService';
import { userService } from '../api/services/userService';
import SessionStatusCard from '../components/home/SessionStatusCard';

const HomePage = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [activeSession, setActiveSession] = useState(null);
  const [isCheckingSession, setIsCheckingSession] = useState(true);

  useEffect(() => {
    const checkActiveSession = async () => {
      if (!user?.id) {
        setIsCheckingSession(false);
        return;
      }

      try {
        const sessionData = await sessionService.getActiveSession();
        
        if (sessionData && sessionData.id && !sessionData.ended_at) {
          let enrichedSession = {
            ...sessionData,
            session_id: sessionData.id
          };

          // Fetch and merge question data if question_id exists
          if (sessionData.question_id) {
            try {
              const questionData = await questionService.getQuestion(sessionData.question_id);
              if (questionData) {
                const { id: questionInternalId, ...safeQuestionData } = questionData;
                enrichedSession = {
                  ...enrichedSession,
                  ...safeQuestionData,  // Merge question data (title, description, etc.)
                };
              }
            } catch (error) {
              console.error('Failed to fetch question details:', error);
            }
          }

          // Fetch and merge matched user profile if matched_user_id exists
          if (sessionData.matched_user_id) {
            try {
              const partnerProfile = await userService.getPublicProfile(sessionData.matched_user_id);
              if (partnerProfile?.data?.user) {
                enrichedSession = {
                  ...enrichedSession,
                  partner_name: partnerProfile.data.user.display_name,
                  partner_email: partnerProfile.data.user.email,
                  // Add any other partner fields you need
                };
              }
            } catch (error) {
              console.error('Failed to fetch partner profile:', error);
            }
          }

          setActiveSession(enrichedSession);
        }
      } catch (error) {
        console.error('Failed to check active session:', error);
      } finally {
        setIsCheckingSession(false);
      }
    };

    checkActiveSession();
  }, [user?.id]);

  const handleReconnect = () => {
    if (activeSession) {
      navigate(`/collaboration/${activeSession.id}`, {
        state: { sessionData: activeSession }
      });
    }
  };

  const handleStartNewSession = () => {
    navigate('/matching');
  };

  return (
    <div className="w-full min-h-screen p-8 bg-background">
      <div className="max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-4 text-white">Welcome to PeerPrep!</h1>
          <p className="text-lg text-gray-300">Your one-stop platform for peer-to-peer coding practice.</p>
        </div>

        <SessionStatusCard
          isChecking={isCheckingSession}
          activeSession={activeSession}
          onReconnect={handleReconnect}
          onStartNew={handleStartNewSession}
        />
      </div>
    </div>
  );
};

export default HomePage;
