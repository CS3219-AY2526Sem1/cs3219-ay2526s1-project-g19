import { useNavigate } from "react-router-dom";
import { Code2, Users, Zap } from "lucide-react";
import PeerPrepLogo from "../assets/PeerPrepLogoLight.png";

const LandingPage = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen w-full bg-background flex items-center justify-center p-4">
      <div className="max-w-4xl w-full text-center space-y-8">
        <div className="flex justify-center">
          <div className="relative">
            <div className="absolute bg-primary opacity-50 rounded-full"></div>
            <img src={PeerPrepLogo} alt="PeerPrep Logo" className="relative w-50 h-20 mx-auto" />
          </div>
        </div>

        <div className="space-y-4">
          <h1 className="text-6xl md:text-7xl font-bold text-white">
            Welcome to <span className="text-primary">PeerPrep</span>
          </h1>
          <p className="text-xl md:text-2xl text-gray-300 max-w-2xl mx-auto">
            Your hub to match with fellow coders, sharpen your skills,
          </p>
          <p className="text-xl md:text-2xl text-gray-300 max-w-2xl mx-auto">
            and ace technical interviews together
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 py-8">
          <div className="bg-white/10 backdrop-blur-lg rounded-xl p-6 border border-white/20">
            <Users className="w-12 h-12 text-primary mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-white mb-2">Find Your Match</h3>
            <p className="text-gray-300 text-sm">Connect with peers at your skill level</p>
          </div>
          
          <div className="bg-white/10 backdrop-blur-lg rounded-xl p-6 border border-white/20">
            <Code2 className="w-12 h-12 text-primary mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-white mb-2">Code Together</h3>
            <p className="text-gray-300 text-sm">Collaborate in real-time on coding challenges</p>
          </div>
          
          <div className="bg-white/10 backdrop-blur-lg rounded-xl p-6 border border-white/20">
            <Zap className="w-12 h-12 text-primary mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-white mb-2">Level Up</h3>
            <p className="text-gray-300 text-sm">Improve your skills through practice</p>
          </div>
        </div>

        <div className="pt-4">
          <button
            onClick={() => navigate('/register')}
            className="group relative inline-flex items-center justify-center gap-3 px-8 py-4 text-lg font-bold text-white bg-primary hover:bg-primary/90 rounded-full transition-all duration-300 transform hover:scale-105"
          >
            <span>Start Matching</span>
            <svg
              className="w-5 h-5 transition-transform group-hover:translate-x-1"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M13 7l5 5m0 0l-5 5m5-5H6"
              />
            </svg>
          </button>
        </div>

        <p className="text-gray-400 text-sm">
          Already have an account?{" "}
          <button
            onClick={() => navigate('/login')}
            className="text-gray-300 hover:text-gray-100 font-semibold rounded-full px-3 bg-transparent underline"
          >
            Sign in here
          </button>
        </p>
      </div>
    </div>
  );
};

export default LandingPage;
