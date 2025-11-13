import { useState, useEffect, useRef, useCallback } from "react"
import io from "socket.io-client"
import CodeMirror from "@uiw/react-codemirror"
import { python } from "@codemirror/lang-python"
import { java } from "@codemirror/lang-java"
import { javascript } from "@codemirror/lang-javascript"
import { cpp } from "@codemirror/lang-cpp"
import { sublime } from "@uiw/codemirror-theme-sublime"
import { EditorView } from "@codemirror/view"
import { createLinter } from "./codeeditor/utils/Linter"
import { createCursorsField, posToLineChar, getUserColor } from "./codeeditor/utils/CursorWidget"
import EditorHeader from "./codeeditor/EditorHeader"
import EditorStatsBar from "./codeeditor/EditorCursorBar"
import EditorRunButton from "./codeeditor/EditorRunButton"
import EditorRunTestsButton from "./codeeditor/EditorRunTestsButton"
import EditorOutputTerminal from "./codeeditor/EditorOutputTerminal"
import executionService from "../../api/services/executionService"

const CodeEditor = ({ room, currentUsername, language, questionId }) => {
    // Use service layer for default code
    const getDefaultCode = (lang) => {
        return executionService.getDefaultCode(lang)
    }
    const [code, setCode] = useState({
        value: getDefaultCode(language),
        isReceived: false,
    })
    const [output, setOutput] = useState("")
    const [isRunning, setIsRunning] = useState(false)
    const [cursorPosition, setCursorPosition] = useState({ line: 1, ch: 0 })
    const [remoteCursors, setRemoteCursors] = useState({})
    const [isConnected, setIsConnected] = useState(false)
    const editorViewRef = useRef(null)
    const collabSocketRef = useRef(null)
    const cursorsRef = useRef({})
    const lastEmitTime = useRef(0)

    const getLanguageExtension = (lang) => {
        switch (lang) {
            case "python":
                return python()
            case "javascript":
                return javascript()
            case "java":
                return java()
            case "c":
            case "C":
                return cpp() // C uses cpp extension
            case "cpp":
            case "C++":
                return cpp()
            default:
                return python()
        }
    }

    const getLinter = (lang) => {
        return createLinter(lang)
    }

    // Create cursors field using the abstracted function
    const cursorsField = createCursorsField(cursorsRef)

    const handleBeforeUnload = useCallback(() => {
        if (collabSocketRef.current) {
            collabSocketRef.current.emit("leave", { room: room })
            collabSocketRef.current.disconnect()
        }
    }, [room])

    useEffect(() => {
        // Initialize collaboration socket
        // When using proxy paths, Socket.IO needs the path option set correctly
        // This tells Socket.IO to connect to `ws://<host>/collaboration-service-api/socket.io`
        const socketPath = `${import.meta.env.VITE_COLLABORATION_SERVICE_URL || "/collaboration-service-api"}/socket.io`;
        collabSocketRef.current = io(window.location.origin, { path: socketPath });
        console.log("Connecting to Socket.IO with path:", socketPath);

        collabSocketRef.current.on("connect", () => {
            console.log(`Connected to collab server with SID ${collabSocketRef.current.id}`)
            collabSocketRef.current.emit("join", { room: room })
            setIsConnected(true)
        })

        collabSocketRef.current.on("disconnect", () => {
            console.log("Disconnected from collaboration server")
            setIsConnected(false)
            setRemoteCursors({}) // Clear all cursors on disconnect
        })

        window.addEventListener("beforeunload", handleBeforeUnload)
        window.addEventListener("unload", handleBeforeUnload)

        return () => {
            handleBeforeUnload()
            window.removeEventListener("beforeunload", handleBeforeUnload)
            window.removeEventListener("unload", handleBeforeUnload)
        }
    }, [room, handleBeforeUnload])

    useEffect(() => {
        cursorsRef.current = remoteCursors
    }, [remoteCursors])

    const emitCursorPosition = (lineChar) => {
        const now = Date.now()
        if (now - lastEmitTime.current < 100) return

        lastEmitTime.current = now
        if (collabSocketRef.current && collabSocketRef.current.connected) {
            collabSocketRef.current.emit("cursor", {
                room: room,
                line: lineChar.line,
                ch: lineChar.ch,
                userId: collabSocketRef.current.id,
                username: currentUsername
            })
        }
    }

    useEffect(() => {
        if (editorViewRef.current) {
            editorViewRef.current.dispatch({})
        }
    }, [remoteCursors])

    useEffect(() => {
        if (!collabSocketRef.current) return

        collabSocketRef.current.on("receive", (payload) => {
            console.log("Received code update:", payload.code)
            setCode({ value: payload.code, isReceived: true })
        })

        collabSocketRef.current.on("cursor", (data) => {
            console.log("Received cursor update:", data)

            if (data.userId !== collabSocketRef.current.id) {
                setRemoteCursors(prev => ({
                    ...prev,
                    [data.userId]: {
                        line: data.line,
                        ch: data.ch,
                        color: getUserColor(data.userId),
                        username: data.username,
                        timestamp: Date.now()
                    }
                }))
            }
        })

        collabSocketRef.current.on("user_left", (data) => {
            console.log("User left:", data)
            setRemoteCursors(prev => {
                const newCursors = { ...prev }
                delete newCursors[data.userId]
                return newCursors
            })
        })

        return () => {
            collabSocketRef.current.off("receive")
            collabSocketRef.current.off("cursor")
            collabSocketRef.current.off("user_left")
        }
    }, [collabSocketRef.current])

    useEffect(() => {
        const interval = setInterval(() => {
            const now = Date.now()
            setRemoteCursors(prev => {
                const filtered = {}
                let hasChanges = false

                Object.entries(prev).forEach(([userId, cursor]) => {
                    if (now - cursor.timestamp < 60000) {
                        filtered[userId] = cursor
                    } else {
                        hasChanges = true
                    }
                })

                return hasChanges ? filtered : prev
            })
        }, 10000)

        return () => clearInterval(interval)
    }, [])

    function updateCode(room, value) {
        if (!collabSocketRef.current) return

        if (!code.isReceived) {
            collabSocketRef.current.emit("change", { room: room, code: value })
        }
        setCode({ value: value, isReceived: false })
    }

    // Use service layer for language mapping
    const getLanguageId = (lang) => {
        return executionService.getLanguageId(lang)
    }

    const runCode = async () => {
        setIsRunning(true)
        setOutput("Running...")

        try {
            const result = await executionService.execute(language, code.value, "")
            setOutput(result.outputText)
        } catch (error) {
            setOutput(`Error: ${error.message}`)
        } finally {
            setIsRunning(false)
        }
    }

    const runTests = async () => {
        setIsRunning(true)
        setOutput("Running tests...")

        try {
            const result = await executionService.runTests(language, code.value, questionId)
            setOutput(result.outputText)
        } catch (error) {
            setOutput(`Error: ${error.message}`)
        } finally {
            setIsRunning(false)
        }
    }

    const currentLinter = getLinter(language)

    const cursorExtension = [
        cursorsField,
        ...(currentLinter ? [currentLinter] : []),
        EditorView.updateListener.of((update) => {
            if (update.selectionSet) {
                const pos = update.state.selection.main.head
                const lineChar = posToLineChar(update.state.doc, pos)
                setCursorPosition(lineChar)
                emitCursorPosition(lineChar)
            }
        })
    ]

    if (!isConnected) {
        return (
            <div className="flex items-center justify-center h-full">
                <div className="text-center">
                    <div className="w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
                    <p className="text-gray-600 dark:text-gray-400 text-sm font-medium">
                        Connecting to collaboration server...
                    </p>
                </div>
            </div>
        )
    }

    return (
        <div className="w-full max-w-6xl mx-auto p-6 space-y-4">
            <EditorStatsBar cursorPosition={cursorPosition} remoteCursors={remoteCursors} />
            <div className="rounded-xl overflow-hidden shadow-2xl border border-slate-700">
                <EditorHeader
                    language={language}
                />
                <CodeMirror
                    value={code.value}
                    height="50vh"
                    maxHeight="50vh"
                    onChange={(value) => updateCode(room, value)}
                    extensions={[getLanguageExtension(language), ...cursorExtension]}
                    theme={sublime}
                    onCreateEditor={(view) => {
                        editorViewRef.current = view
                    }}
                    basicSetup={{
                        lineNumbers: true,
                        foldGutter: true,
                        dropCursor: false,
                        allowMultipleSelections: false,
                        indentOnInput: true,
                        bracketMatching: true,
                        closeBrackets: true,
                        autocompletion: true,
                        highlightSelectionMatches: false
                    }}
                />
            </div>
            <div className="flex gap-3">
                <EditorRunButton onClick={runCode} isRunning={isRunning} />
                <EditorRunTestsButton 
                    onClick={runTests} 
                    isRunning={isRunning} 
                    disabled={!questionId}
                />
            </div>
            {output && <EditorOutputTerminal output={output} />}
        </div>
    )
}

export default CodeEditor
