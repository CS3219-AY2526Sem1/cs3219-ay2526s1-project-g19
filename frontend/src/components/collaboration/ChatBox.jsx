import React, { useState, useRef, useEffect, useCallback } from "react";
import io from "socket.io-client";
import ChatHeader from "./chatbox/ChatHeader";
import ChatMessagesList from "./chatbox/ChatMessagesList";
import ChatInput from "./chatbox/ChatInput";

const ChatBox = ({ room, currentUsername }) => {
  const [messages, setMessages] = useState([]);
  const [message, setMessage] = useState("");
  const messagesEndRef = useRef(null);
  const chatSocketRef = useRef(null);

  const handleBeforeUnload = useCallback(() => {
    if (chatSocketRef.current) {
      chatSocketRef.current.emit("leave", { username: currentUsername, room });
      chatSocketRef.current.disconnect();
    }
  }, [currentUsername, room]);

  useEffect(() => {
    // Initialize chat socket
    chatSocketRef.current = io(import.meta.env.VITE_CHAT_API);

    chatSocketRef.current.on("connect", () => {
      console.log(`Connected to chat server with SID ${chatSocketRef.current.id}`);
      chatSocketRef.current.emit("join", { username: currentUsername, room });
    });

    chatSocketRef.current.on("receive", (data) => {
      setMessages((prev) => [...prev, data]);
    });

    window.addEventListener("beforeunload", handleBeforeUnload);
    window.addEventListener("unload", handleBeforeUnload);

    return () => {
      handleBeforeUnload();
      window.removeEventListener("beforeunload", handleBeforeUnload);
      window.removeEventListener("unload", handleBeforeUnload);
    };
  }, [room, currentUsername, handleBeforeUnload]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = (e) => {
    e.preventDefault();
    if (message.trim() && chatSocketRef.current) {
      chatSocketRef.current.emit("send", {
        room,
        username: currentUsername,
        message,
        __createdtime__: Date.now()
      });
      setMessage("");
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage(e);
  };

  return (
    <div className="h-full w-full flex flex-col">
      <ChatHeader />
      <div className="flex-1 flex flex-col min-h-0 bg-white dark:bg-gray-900">
        <ChatMessagesList
          messages={messages}
          currentUsername={currentUsername}
          messagesEndRef={messagesEndRef}
        />
        <ChatInput
          message={message}
          setMessage={setMessage}
          handleSubmit={handleSubmit}
        />
      </div>
    </div>
  );
};

export default ChatBox;