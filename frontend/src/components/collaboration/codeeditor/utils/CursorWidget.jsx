import { Decoration, EditorView, WidgetType } from "@codemirror/view"
import { StateField } from "@codemirror/state"

export class CursorWidget extends WidgetType {
    constructor(userId, color, username, line) {
        super()
        this.userId = userId
        this.color = color
        this.username = username
        this.line = line
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
        
        // Smart positioning based on line number
        const labelPosition = this.getLabelPosition()
        label.style.cssText = `
            ${labelPosition}
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
        `
        
        wrapper.appendChild(cursor)
        wrapper.appendChild(label)
        
        this.addEventListeners(wrapper, label)
        
        return wrapper
    }

    getLabelPosition() {
        // If on line 1 or 2, show label below cursor
        if (this.line <= 2) {
            return `
                position: absolute;
                top: 100%;
                left: 0;
                margin-top: 4px;
            `
        }
        // Otherwise, show label above cursor
        return `
            position: absolute;
            bottom: 100%;
            left: 0;
            margin-bottom: 4px;
        `
    }

    addEventListeners(wrapper, label) {
        wrapper.addEventListener('mouseenter', () => {
            label.style.opacity = '1'
        })
        
        wrapper.addEventListener('mouseleave', () => {
            label.style.opacity = '0'
        })
        
        wrapper.addEventListener('click', () => {
            label.style.opacity = '1'
            setTimeout(() => {
                label.style.opacity = '0'
            }, 2000)
        })
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

export const lineCharToPos = (doc, lineChar) => {
    try {
        if (lineChar.line > doc.lines) return doc.length
        const line = doc.line(lineChar.line)
        return line.from + Math.min(lineChar.ch, line.length)
    } catch {
        return 0
    }
}

export const posToLineChar = (doc, pos) => {
    const line = doc.lineAt(pos)
    return {
        line: line.number,
        ch: pos - line.from
    }
}

export const getUserColor = (userId) => {
    const colors = ['#FF4136', '#2ECC40', '#0074D9', '#B10DC9', '#FF851B', '#FFDC00']
    let hash = 0
    for (let i = 0; i < userId.length; i++) {
        hash = ((hash << 5) - hash + userId.charCodeAt(i)) & 0xffffffff
    }
    return colors[Math.abs(hash) % colors.length]
}

export const createCursorsField = (cursorsRef) => {
    return StateField.define({
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
                        widget: new CursorWidget(userId, cursor.color, cursor.username, cursor.line),
                        side: 1
                    })
                    decorations.push(decoration.range(pos))
                }
            })
            
            return Decoration.set(decorations, true)
        },
        provide: f => EditorView.decorations.from(f)
    })
}