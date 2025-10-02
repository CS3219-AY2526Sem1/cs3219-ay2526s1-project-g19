import { MessageCircle } from "lucide-react";

const ChatHeader = () => (
  <div className="bg-gradient-to-r from-blue-600 via-indigo-600 to-purple-600 px-4 py-2 flex-shrink-0">
    <div className="flex items-center gap-2">
      <div className="w-8 h-8 rounded-lg bg-white/20 backdrop-blur-sm flex items-center justify-center">
        <MessageCircle className="w-4 h-4 text-white" />
      </div>
      <div>
        <h2 className="text-base font-bold text-white">Chat</h2>
        <p className="text-xs text-white/80">Online</p>
      </div>
    </div>
  </div>
);

export default ChatHeader;