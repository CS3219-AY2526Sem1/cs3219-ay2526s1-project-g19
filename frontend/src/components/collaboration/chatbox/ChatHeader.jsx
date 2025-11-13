import { MessageCircle } from "lucide-react";

const ChatHeader = () => (
  <div className="bg-gradient-to-r from-primary via-primary to-blue-700 px-4 py-2 flex-shrink-0">
    <div className="flex items-center gap-2">
      <div className="w-8 h-8 rounded-lg bg-white/20 backdrop-blur-sm flex items-center justify-center">
        <MessageCircle className="w-4 h-4 text-gray-200" />
      </div>
      <div>
        <h2 className="text-base font-bold text-gray-200">Chat</h2>
        <p className="text-xs text-gray-200">Online</p>
      </div>
    </div>
  </div>
);

export default ChatHeader;