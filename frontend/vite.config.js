import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // Load env file based on mode (development, production)
  // and the project root, which is one level up.
  const env = loadEnv(mode, path.resolve(__dirname, '..'), '')

  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    server: {
      port: 5173,
      // Proxy API requests to Docker backend services
      // This allows local Vite dev server to reach services running in Docker
      proxy: {
        '/user-service-api': {
          target: `http://localhost:${env.USER_SERVICE_PORT || 8004}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/user-service-api/, ''),
        },
        '/question-service-api': {
          target: `http://localhost:${env.QUESTION_SERVICE_PORT || 8001}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/question-service-api/, ''),
        },
        '/matching-service-api': {
          target: `http://localhost:${env.MATCHING_SERVICE_PORT || 8002}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/matching-service-api/, ''),
          ws: true, // Enable WebSocket proxying for matching service
        },
        '/history-service-api': {
          target: `http://localhost:${env.HISTORY_SERVICE_PORT || 8003}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/history-service-api/, ''),
        },
        '/session-service-api': {
          target: `http://localhost:${env.SESSION_SERVICE_PORT || 8003}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/session-service-api/, ''),
        },
        '/collaboration-service-api': {
          target: `http://localhost:${env.COLLABORATION_SERVICE_PORT || 8005}`,
          changeOrigin: true,
          // Rewrite to remove the /collaboration-service-api prefix
          rewrite: (path) => path.replace(/^\/collaboration-service-api/, ''),
          ws: true, // Enable WebSocket proxying for Socket.IO
        },
        '/chat-service-api': {
          target: `http://localhost:${env.CHAT_SERVICE_PORT || 8006}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/chat-service-api/, ''),
          ws: true, // Enable WebSocket proxying for Socket.IO
        },
        '/execution-service-api': {
          target: `http://localhost:${env.EXECUTION_SERVICE_PORT || 8007}`,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/execution-service-api/, ''),
        },
      },
    },
  }
})
