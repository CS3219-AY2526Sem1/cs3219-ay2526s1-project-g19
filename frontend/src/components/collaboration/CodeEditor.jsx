import { useState, useEffect, useRef, useCallback } from "react"
import io from "socket.io-client"
import CodeMirror from "@uiw/react-codemirror"
import { python } from "@codemirror/lang-python"
import { sublime } from "@uiw/codemirror-theme-sublime"
import { EditorView, Decoration, WidgetType } from "@codemirror/view"
import { StateField } from "@codemirror/state"
import EditorHeader from "./codeeditor/EditorHeader"
import EditorStatsBar from "./codeeditor/EditorCursorBar"
import EditorRunButton from "./codeeditor/EditorRunButton"
import EditorOutputTerminal from "./codeeditor/EditorOutputTerminal"

const CodeEditor = ({ room, currentUsername }) => {
    const [code, setCode] = useState({
        value: "print('hello world')",
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

    const handleBeforeUnload = useCallback(() => {
        if (collabSocketRef.current) {
            collabSocketRef.current.disconnect()
        }
    }, [])

    useEffect(() => {
        // Initialize collaboration socket
        collabSocketRef.current = io(import.meta.env.VITE_COLLABORATION_API)

        collabSocketRef.current.on("connect", () => {
            console.log(`Connected to collab server with SID ${collabSocketRef.current.id}`)
            collabSocketRef.current.emit("join", { room: room })
            setIsConnected(true)
        })

        collabSocketRef.current.on("disconnect", () => {
            setIsConnected(false)
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

    const lineCharToPos = (doc, lineChar) => {
        try {
            if (lineChar.line > doc.lines) return doc.length
            const line = doc.line(lineChar.line)
            return line.from + Math.min(lineChar.ch, line.length)
        } catch {
            return 0
        }
    }

    const posToLineChar = (doc, pos) => {
        const line = doc.lineAt(pos)
        return {
            line: line.number,
            ch: pos - line.from
        }
    }

    class CursorWidget extends WidgetType {
        constructor(userId, color, username) {
            super()
            this.userId = userId
            this.color = color
            this.username = username
        }

        toDOM() {
            const wrapper = document.createElement("span")
            wrapper.className = "remote-cursor-wrapper"
            wrapper.style.cssText = `
                position: relative;
                display: inline-block;
                pointer-events: auto;
            `
            
            const cursor = document.createElement("span")
            cursor.className = "remote-cursor"
            cursor.style.cssText = `
                border-left: 2px solid ${this.color};
                height: 1.2em;
                display: inline-block;
                position: relative;
                margin-left: -1px;
            `
            
            const label = document.createElement("div")
            label.textContent = this.username
            label.className = "cursor-label"
            label.style.cssText = `
                position: absolute;
                bottom: 100%;
                left: 0;
                background: ${this.color};
                color: white;
                padding: 4px 8px;
                border-radius: 4px;
                font-size: 12px;
                font-weight: 500;
                white-space: nowrap;
                z-index: 10000;
                opacity: 0;
                transition: opacity 0.2s ease;
                pointer-events: none;
                box-shadow: 0 2px 8px rgba(0,0,0,0.2);
                margin-bottom: 4px;
            `
            
            wrapper.appendChild(cursor)
            wrapper.appendChild(label)
            
            wrapper.addEventListener('mouseenter', () => {
                label.style.opacity = '1'
            })
            wrapper.addEventListener('mouseleave', () => {
                label.style.opacity = '0'
            })
            
            // Also show on click/touch for better mobile support
            wrapper.addEventListener('click', () => {
                label.style.opacity = '1'
                setTimeout(() => {
                    label.style.opacity = '0'
                }, 2000)
            })
            
            return wrapper
        }

        eq(other) {
            return other instanceof CursorWidget && 
                   this.userId === other.userId && 
                   this.color === other.color &&
                   this.username === other.username
        }

        updateDOM() {
            return false
        }

        get estimatedHeight() {
            return 0
        }

        ignoreEvent() {
            return false
        }
    }

    const cursorsField = StateField.define({
        create() {
            return Decoration.none
        },
        update(cursors, tr) {
            const decorations = []
            const currentCursors = cursorsRef.current
            
            Object.entries(currentCursors).forEach(([userId, cursor]) => {
                const pos = lineCharToPos(tr.state.doc, { line: cursor.line, ch: cursor.ch })
                if (pos >= 0 && pos <= tr.state.doc.length) {
                    const decoration = Decoration.widget({
                        widget: new CursorWidget(userId, cursor.color, cursor.username),
                        side: 1
                    })
                    decorations.push(decoration.range(pos))
                }
            })
            
            return Decoration.set(decorations, true)
        },
        provide: f => EditorView.decorations.from(f)
    })

    const getUserColor = (userId) => {
        const colors = ['#FF4136', '#2ECC40', '#0074D9', '#B10DC9', '#FF851B', '#FFDC00']
        let hash = 0
        for (let i = 0; i < userId.length; i++) {
            hash = ((hash << 5) - hash + userId.charCodeAt(i)) & 0xffffffff
        }
        return colors[Math.abs(hash) % colors.length]
    }

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
                        username: currentUsername,
                        timestamp: Date.now()
                    }
                }))
            }
        })

        collabSocketRef.current.on("user_left", (data) => {
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

    const runCode = async () => {
        setIsRunning(true)
        setOutput("Running...")
        
        try {
            const response = await fetch(`${import.meta.env.VITE_EXECUTION_API}/run`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ code: code.value }),
            })
            
            const data = await response.json()
            setOutput(data.output || data.error)
        } catch (error) {
            setOutput("Error: Could not connect to execution service")
        } finally {
            setIsRunning(false)
        }
    }

    const cursorExtension = [
        cursorsField,
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
                <EditorHeader filename="editor.py" />
                <CodeMirror
                    value={code.value}
                    height="50vh"
                    maxHeight="50vh"
                    onChange={(value) => updateCode(room, value)}
                    extensions={[python(), ...cursorExtension]}
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
            <EditorRunButton onClick={runCode} isRunning={isRunning} />
            {output && <EditorOutputTerminal output={output} />}
        </div>
    )
}

export default CodeEditor