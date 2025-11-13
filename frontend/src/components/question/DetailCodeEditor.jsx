import { useState, useEffect, useRef } from "react"
import CodeMirror from "@uiw/react-codemirror"
import { python } from "@codemirror/lang-python"
import { java } from "@codemirror/lang-java"
import { javascript } from "@codemirror/lang-javascript"
import { cpp } from "@codemirror/lang-cpp"
import { sublime } from "@uiw/codemirror-theme-sublime"
import { EditorView } from "@codemirror/view"
import { createLinter } from "../collaboration/codeeditor/utils/Linter"
import { posToLineChar } from "../collaboration/codeeditor/utils/CursorWidget"
import EditorHeader from "../collaboration/codeeditor/EditorHeader"
import EditorRunButton from "../collaboration/codeeditor/EditorRunButton"
import EditorRunTestsButton from "../collaboration/codeeditor/EditorRunTestsButton"
import EditorOutputTerminal from "../collaboration/codeeditor/EditorOutputTerminal"
import executionService from "../../api/services/executionService"

const DetailCodeEditor = ({ language, questionId }) => {
    // Normalize language to match executionService format
    const normalizeLanguage = (lang) => {
        const langMap = {
            'python': 'Python',
            'javascript': 'Javascript',
            'java': 'Java',
            'cpp': 'C++',
            'c': 'C'
        }
        return langMap[lang.toLowerCase()] || 'Python'
    }

    const normalizedLanguage = normalizeLanguage(language)

    const [code, setCode] = useState({
        value: executionService.getDefaultCode(normalizedLanguage),
        isReceived: false,
    })
    const [output, setOutput] = useState("")
    const [isRunning, setIsRunning] = useState(false)
    const [cursorPosition, setCursorPosition] = useState({ line: 1, ch: 0 })
    const editorViewRef = useRef(null)
    const cursorsRef = useRef({})

    const getLanguageExtension = (lang) => {
        switch (lang.toLowerCase()) {
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

    // Update code when language changes
    useEffect(() => {
        const normalizedLang = normalizeLanguage(language)
        setCode({
            value: executionService.getDefaultCode(normalizedLang),
            isReceived: false,
        })
        setOutput("") // Clear output when language changes
    }, [language])

    function updateCode(value) {
        setCode({ value: value, isReceived: false })
    }

    const runCode = async () => {
        setIsRunning(true)
        setOutput("Running...")

        try {
            const result = await executionService.execute(normalizedLanguage, code.value, "")
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
            const result = await executionService.runTests(normalizedLanguage, code.value, questionId)
            setOutput(result.outputText)
        } catch (error) {
            setOutput(`Error: ${error.message}`)
        } finally {
            setIsRunning(false)
        }
    }

    const currentLinter = getLinter(language)

    const cursorExtension = [
        ...(currentLinter ? [currentLinter] : []),
        EditorView.updateListener.of((update) => {
            if (update.selectionSet) {
                const pos = update.state.selection.main.head
                const lineChar = posToLineChar(update.state.doc, pos)
                setCursorPosition(lineChar)
            }
        })
    ]

    return (
        <div className="w-full max-w-6xl mx-auto p-6 space-y-4">
            <div className="rounded-xl overflow-hidden shadow-2xl border border-slate-700">
                <EditorHeader
                    language={language}
                />
                <CodeMirror
                    key={language}
                    value={code.value}
                    height="50vh"
                    maxHeight="50vh"
                    onChange={(value) => updateCode(value)}
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

export default DetailCodeEditor
