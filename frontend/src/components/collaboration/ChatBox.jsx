import React, { useState, useRef, useEffect, useCallback } from "react";
import io from "socket.io-client";
import ChatHeader from "./chatbox/ChatHeader";
import ChatMessagesList from "./chatbox/ChatMessagesList";
import ChatInput from "./chatbox/ChatInput";

const ChatBox = ({ room, currentUsername, socketRef, onPartnerLeft, onPartnerDisconnected, onPartnerRejoined }) => {
  const [messages, setMessages] = useState([]);
  const [message, setMessage] = useState("");
  const messagesEndRef = useRef(null);
  const chatSocketRef = socketRef || useRef(null);

  const handleBeforeUnload = useCallback(() => {
    if (chatSocketRef.current) {
      chatSocketRef.current.emit("leave", { username: currentUsername, room });
      chatSocketRef.current.disconnect();
    }
  }, [currentUsername, room]);

  useEffect(() => {
    // Initialize chat socket
    // The first argument is the namespace, which we don't use.
    // The options object contains the path, which should be the proxy path.
    // This tells Socket.IO to connect to `ws://<host>/chat-service-api/socket.io`
    const socketPath = `${import.meta.env.VITE_CHAT_SERVICE_URL || "/chat-service-api"}/socket.io`;
    
    // If socket already exists and is connected, disconnect it first
    if (chatSocketRef.current && chatSocketRef.current.connected) {
      console.log("Disconnecting existing socket before creating new one");
      chatSocketRef.current.disconnect();
    }
    
    chatSocketRef.current = io(window.location.origin, { path: socketPath });
    console.log("Connecting to chat Socket.IO with path:", socketPath);

    const handleConnect = () => {
      console.log(`Connected to chat server with SID ${chatSocketRef.current.id}`);
      chatSocketRef.current.emit("join", { username: currentUsername, room });
    };

    const handleReceive = (data) => {
      setMessages((prev) => [...prev, data]);
    };

    const handlePartnerLeft = (data) => {
      console.log("Partner left:", data);
      if (onPartnerLeft) {
        onPartnerLeft(data);
      }
    };

    const handlePartnerDisconnected = (data) => {
      console.log("Partner disconnected:", data);
      if (onPartnerDisconnected) {
        onPartnerDisconnected(data);
      }
    };

    const handleUserJoined = (data) => {
      console.log("User joined:", data);
      if (onPartnerRejoined) {
        onPartnerRejoined(data);
      }
    };

    chatSocketRef.current.on("connect", handleConnect);
    chatSocketRef.current.on("receive", handleReceive);
    chatSocketRef.current.on("partner-left", handlePartnerLeft);
    chatSocketRef.current.on("partner-disconnected", handlePartnerDisconnected);
    chatSocketRef.current.on("user-joined", handleUserJoined);

    window.addEventListener("beforeunload", handleBeforeUnload);
    window.addEventListener("unload", handleBeforeUnload);

    return () => {
      // Clean up event listeners
      if (chatSocketRef.current) {
        chatSocketRef.current.off("connect", handleConnect);
        chatSocketRef.current.off("receive", handleReceive);
        chatSocketRef.current.off("partner-left", handlePartnerLeft);
        chatSocketRef.current.off("partner-disconnected", handlePartnerDisconnected);
        chatSocketRef.current.off("user-joined", handleUserJoined);
      }
      
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
      <div className="flex-1 flex flex-col min-h-0 bg-background">
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
