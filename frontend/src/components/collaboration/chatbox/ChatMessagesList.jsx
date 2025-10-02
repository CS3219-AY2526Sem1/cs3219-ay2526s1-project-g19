import ChatMessage from "./ChatMessage";

const ChatMessagesList = ({ messages, currentUsername, messagesEndRef }) => (
  <div className="flex-1 overflow-y-auto p-3 space-y-3 bg-gradient-to-b from-gray-50 to-white dark:from-gray-800 dark:to-gray-900 min-h-0">
    {messages.map((msg, index) => (
      <ChatMessage
        key={index}
        msg={msg}
        isCurrentUser={msg.username === currentUsername}
      />
    ))}
    <div ref={messagesEndRef} />
  </div>
);

export default ChatMessagesList;