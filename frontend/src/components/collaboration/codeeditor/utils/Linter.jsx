import { linter } from "@codemirror/lint"

// Python built-in functions and keywords
const pythonBuiltins = new Set([
    'abs', 'all', 'any', 'ascii', 'bin', 'bool', 'bytearray', 'bytes', 'callable',
    'chr', 'classmethod', 'compile', 'complex', 'delattr', 'dict', 'dir', 'divmod',
    'enumerate', 'eval', 'exec', 'filter', 'float', 'format', 'frozenset', 'getattr',
    'globals', 'hasattr', 'hash', 'help', 'hex', 'id', 'input', 'int', 'isinstance',
    'issubclass', 'iter', 'len', 'list', 'locals', 'map', 'max', 'memoryview', 'min',
    'next', 'object', 'oct', 'open', 'ord', 'pow', 'print', 'property', 'range',
    'repr', 'reversed', 'round', 'set', 'setattr', 'slice', 'sorted', 'staticmethod',
    'str', 'sum', 'super', 'tuple', 'type', 'vars', 'zip', '__import__',
    'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await', 'break',
    'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'finally', 'for',
    'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal', 'not', 'or',
    'pass', 'raise', 'return', 'try', 'while', 'with', 'yield',
    'Exception', 'ValueError', 'TypeError', 'KeyError', 'IndexError', 'AttributeError',
    'self', 'cls', '__name__', '__main__'
])

// JavaScript built-ins and keywords
const javascriptBuiltins = new Set([
    'Array', 'Boolean', 'Date', 'Error', 'Function', 'JSON', 'Math', 'Number', 'Object',
    'RegExp', 'String', 'Symbol', 'parseInt', 'parseFloat', 'isNaN', 'isFinite',
    'encodeURI', 'encodeURIComponent', 'decodeURI', 'decodeURIComponent',
    'console', 'window', 'document', 'undefined', 'null', 'true', 'false',
    'var', 'let', 'const', 'function', 'class', 'if', 'else', 'for', 'while', 'do',
    'switch', 'case', 'default', 'break', 'continue', 'return', 'try', 'catch', 'finally',
    'throw', 'new', 'this', 'super', 'extends', 'import', 'export', 'from', 'as',
    'async', 'await', 'typeof', 'instanceof', 'in', 'of', 'delete', 'void'
])

// Java keywords and common classes
const javaBuiltins = new Set([
    'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char', 'class',
    'const', 'continue', 'default', 'do', 'double', 'else', 'enum', 'extends', 'final',
    'finally', 'float', 'for', 'goto', 'if', 'implements', 'import', 'instanceof', 'int',
    'interface', 'long', 'native', 'new', 'package', 'private', 'protected', 'public',
    'return', 'short', 'static', 'strictfp', 'super', 'switch', 'synchronized', 'this',
    'throw', 'throws', 'transient', 'try', 'void', 'volatile', 'while',
    'String', 'System', 'Object', 'Integer', 'Double', 'Float', 'Long', 'Short', 'Byte',
    'Character', 'Boolean', 'ArrayList', 'HashMap', 'HashSet', 'Scanner', 'Exception',
    'RuntimeException', 'IOException', 'NullPointerException', 'IllegalArgumentException',
    'Math', 'Random', 'Collections', 'Arrays', 'List', 'Map', 'Set', 'Collection',
    'true', 'false', 'null'
])

// C keywords and standard library functions
const cBuiltins = new Set([
    // Keywords
    'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do', 'double', 'else',
    'enum', 'extern', 'float', 'for', 'goto', 'if', 'inline', 'int', 'long', 'register',
    'restrict', 'return', 'short', 'signed', 'sizeof', 'static', 'struct', 'switch',
    'typedef', 'union', 'unsigned', 'void', 'volatile', 'while',
    // Standard library functions
    'printf', 'scanf', 'malloc', 'free', 'calloc', 'realloc', 'sizeof', 'strlen', 'strcpy',
    'strcat', 'strcmp', 'strncmp', 'strstr', 'memcpy', 'memset', 'memmove', 'memcmp',
    'fopen', 'fclose', 'fread', 'fwrite', 'fprintf', 'fscanf', 'fgets', 'fputs',
    'getchar', 'putchar', 'puts', 'gets', 'atoi', 'atof', 'atol', 'itoa',
    'abs', 'labs', 'fabs', 'ceil', 'floor', 'sqrt', 'pow', 'sin', 'cos', 'tan',
    'log', 'log10', 'exp', 'rand', 'srand', 'exit', 'system', 'getenv',
    // Common types
    'FILE', 'NULL', 'size_t', 'ptrdiff_t', 'wchar_t', 'div_t', 'ldiv_t', 'time_t',
    'clock_t', 'tm', 'jmp_buf', 'va_list', 'fpos_t'
])

// C++ keywords and standard library
const cppBuiltins = new Set([
    // C keywords
    ...cBuiltins,
    // C++ specific keywords
    'alignas', 'alignof', 'and', 'and_eq', 'asm', 'bitand', 'bitor', 'bool', 'catch',
    'class', 'compl', 'constexpr', 'const_cast', 'decltype', 'delete', 'dynamic_cast',
    'explicit', 'export', 'false', 'friend', 'mutable', 'namespace', 'new', 'noexcept',
    'not', 'not_eq', 'nullptr', 'operator', 'or', 'or_eq', 'private', 'protected',
    'public', 'reinterpret_cast', 'static_assert', 'static_cast', 'template', 'this',
    'thread_local', 'throw', 'true', 'try', 'typeid', 'typename', 'using', 'virtual',
    'wchar_t', 'xor', 'xor_eq', 'override', 'final',
    // Standard library
    'cout', 'cin', 'cerr', 'clog', 'endl', 'flush', 'string', 'vector', 'list', 'deque',
    'set', 'map', 'stack', 'queue', 'priority_queue', 'bitset', 'array', 'tuple',
    'pair', 'make_pair', 'shared_ptr', 'unique_ptr', 'weak_ptr', 'function',
    'std', 'ios', 'istream', 'ostream', 'iostream', 'fstream', 'stringstream',
    'iterator', 'begin', 'end', 'size', 'empty', 'push_back', 'pop_back',
    'insert', 'erase', 'find', 'sort', 'reverse', 'max', 'min', 'swap'
])

export const createPythonLinter = () => {
    return linter((view) => {
        const diagnostics = []
        const text = view.state.doc.toString()
        const lines = text.split('\n')

        // Track defined variables
        const definedNames = new Set(pythonBuiltins)

        // First pass: collect all definitions
        lines.forEach((line) => {
            const trimmed = line.trim()
            if (trimmed.startsWith('#') || trimmed.length === 0) return

            // Function/class definitions
            const funcMatch = trimmed.match(/^def\s+(\w+)/)
            if (funcMatch) definedNames.add(funcMatch[1])

            const classMatch = trimmed.match(/^class\s+(\w+)/)
            if (classMatch) definedNames.add(classMatch[1])

            // Import statements
            const importMatch = trimmed.match(/^import\s+([\w, ]+)/)
            if (importMatch) {
                importMatch[1].split(',').forEach(name => definedNames.add(name.trim()))
            }
            const fromImportMatch = trimmed.match(/^from\s+\w+\s+import\s+(.+)/)
            if (fromImportMatch) {
                fromImportMatch[1].split(',').forEach(name => {
                    const cleaned = name.trim().split(' as ')[0].trim()
                    if (cleaned !== '*') definedNames.add(cleaned)
                })
            }

            // Variable assignments
            const assignMatch = trimmed.match(/^(\w+)\s*=/)
            if (assignMatch) definedNames.add(assignMatch[1])

            // For loop variables
            const forMatch = trimmed.match(/^for\s+(\w+)\s+in/)
            if (forMatch) definedNames.add(forMatch[1])

            // Function parameters
            const paramMatch = trimmed.match(/^def\s+\w+\s*\((.*?)\)/)
            if (paramMatch && paramMatch[1]) {
                paramMatch[1].split(',').forEach(param => {
                    const name = param.trim().split('=')[0].split(':')[0].trim()
                    if (name && name !== '*' && name !== '**') {
                        definedNames.add(name.replace('*', ''))
                    }
                })
            }

            // Multiple assignments: a, b = 1, 2
            const multiMatch = trimmed.match(/^([\w\s,]+)=/)
            if (multiMatch && multiMatch[1].includes(',')) {
                multiMatch[1].split(',').forEach(v => definedNames.add(v.trim()))
            }
        })

        // Second pass: check for errors
        lines.forEach((line, lineIndex) => {
            const from = view.state.doc.line(lineIndex + 1).from
            const to = view.state.doc.line(lineIndex + 1).to

            // Missing colon after if, for, while, def, class
            if (/^\s*(if|elif|while|for|def|class|with|try|except|finally)\s+.*[^:]$/.test(line) &&
                !line.trim().endsWith('\\') && line.trim().length > 0) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Missing colon at end of statement'
                })
            }

            // Unmatched parentheses, brackets, braces
            const openParens = (line.match(/\(/g) || []).length
            const closeParens = (line.match(/\)/g) || []).length
            const openBrackets = (line.match(/\[/g) || []).length
            const closeBrackets = (line.match(/\]/g) || []).length
            const openBraces = (line.match(/\{/g) || []).length
            const closeBraces = (line.match(/\}/g) || []).length

            if (openParens !== closeParens || openBrackets !== closeBrackets || openBraces !== closeBraces) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Unmatched parentheses, brackets, or braces'
                })
            }

            // Unmatched quotes (simple check)
            const singleQuotes = (line.match(/'/g) || []).length
            const doubleQuotes = (line.match(/"/g) || []).length
            if (singleQuotes % 2 !== 0 || doubleQuotes % 2 !== 0) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Unmatched quotes'
                })
            }

            // Check for undefined variables - strict checking
            const trimmed = line.trim()
            if (trimmed.startsWith('#') || trimmed.length === 0) return

            // Extract all identifiers from the line
            const identifierRegex = /\b([a-zA-Z_]\w*)\b/g
            let match
            const checkedPositions = new Set()

            while ((match = identifierRegex.exec(line)) !== null) {
                const identifier = match[1]
                const matchPos = match.index

                if (checkedPositions.has(matchPos)) continue
                checkedPositions.add(matchPos)

                // Skip if it's being defined on this line
                const isDefinition = (
                    new RegExp(`^\\s*def\\s+${identifier}\\b`).test(trimmed) ||
                    new RegExp(`^\\s*class\\s+${identifier}\\b`).test(trimmed) ||
                    new RegExp(`^\\s*${identifier}\\s*=`).test(trimmed) ||
                    new RegExp(`^\\s*for\\s+${identifier}\\s+in`).test(trimmed) ||
                    new RegExp(`^\\s*import\\s+.*\\b${identifier}\\b`).test(trimmed) ||
                    new RegExp(`^\\s*from\\s+.*import\\s+.*\\b${identifier}\\b`).test(trimmed)
                )

                // Skip if in string or comment
                const beforeMatch = line.substring(0, matchPos)
                const singleQuotes = (beforeMatch.match(/'/g) || []).length
                const doubleQuotes = (beforeMatch.match(/"/g) || []).length
                const inString = singleQuotes % 2 !== 0 || doubleQuotes % 2 !== 0
                const inComment = beforeMatch.includes('#')

                // Check if undefined
                if (!isDefinition && !definedNames.has(identifier) && !inString && !inComment) {
                    const pos = from + matchPos
                    diagnostics.push({
                        from: pos,
                        to: pos + identifier.length,
                        severity: 'error',
                        message: `Undefined name '${identifier}'`
                    })
                }
            }
        })

        return diagnostics
    })
}

export const createJavaScriptLinter = () => {
    return linter((view) => {
        const diagnostics = []
        const text = view.state.doc.toString()
        const lines = text.split('\n')

        // Track defined variables
        const definedNames = new Set(javascriptBuiltins)

        // First pass: collect definitions
        lines.forEach((line) => {
            const trimmed = line.trim()
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.length === 0) return

            // Function declarations
            const funcMatch = trimmed.match(/^function\s+(\w+)/)
            if (funcMatch) definedNames.add(funcMatch[1])

            // Arrow functions and variables
            const varMatch = trimmed.match(/^(?:var|let|const)\s+(\w+)/)
            if (varMatch) definedNames.add(varMatch[1])

            // Class declarations
            const classMatch = trimmed.match(/^class\s+(\w+)/)
            if (classMatch) definedNames.add(classMatch[1])

            // Function parameters (simplified)
            const paramMatch = trimmed.match(/^function\s+\w+\s*\((.*?)\)/)
            if (paramMatch && paramMatch[1]) {
                paramMatch[1].split(',').forEach(param => {
                    const name = param.trim().split('=')[0].trim()
                    if (name) definedNames.add(name)
                })
            }

            // For loop variables
            const forMatch = trimmed.match(/^for\s*\(\s*(?:var|let|const)?\s*(\w+)/)
            if (forMatch) definedNames.add(forMatch[1])

            // Import statements
            const importMatch = trimmed.match(/^import\s+(?:\{([^}]+)\}|\*\s+as\s+(\w+)|(\w+))/)
            if (importMatch) {
                if (importMatch[1]) { // Named imports
                    importMatch[1].split(',').forEach(name => {
                        const cleaned = name.trim().split(' as ')[0].trim()
                        definedNames.add(cleaned)
                    })
                } else if (importMatch[2]) { // Namespace import
                    definedNames.add(importMatch[2])
                } else if (importMatch[3]) { // Default import
                    definedNames.add(importMatch[3])
                }
            }
        })

        // Second pass: check for errors
        lines.forEach((line, lineIndex) => {
            const from = view.state.doc.line(lineIndex + 1).from
            const to = view.state.doc.line(lineIndex + 1).to

            // Missing semicolons (warning)
            const trimmed = line.trim()
            if (trimmed.length > 0 &&
                !trimmed.endsWith(';') &&
                !trimmed.endsWith('{') &&
                !trimmed.endsWith('}') &&
                !trimmed.startsWith('//') &&
                !trimmed.startsWith('/*') &&
                !/^(if|else|for|while|do|switch|try|catch|finally|function|class)\b/.test(trimmed)) {
                diagnostics.push({
                    from: to - 1,
                    to,
                    severity: 'warning',
                    message: 'Missing semicolon'
                })
            }

            // Unmatched braces/parentheses
            const openBraces = (line.match(/\{/g) || []).length
            const closeBraces = (line.match(/\}/g) || []).length
            const openParens = (line.match(/\(/g) || []).length
            const closeParens = (line.match(/\)/g) || []).length

            if (openBraces !== closeBraces || openParens !== closeParens) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Unmatched braces or parentheses'
                })
            }

            // Assignment in condition (= instead of ==)
            if (/^\s*if\s*\([^)]*[^=!<>]=[^=]/.test(line)) {
                const equalPos = line.indexOf('=')
                if (equalPos > 0) {
                    diagnostics.push({
                        from: from + equalPos,
                        to: from + equalPos + 1,
                        severity: 'warning',
                        message: 'Assignment in condition. Did you mean == or ===?'
                    })
                }
            }
        })

        return diagnostics
    })
}

export const createJavaLinter = () => {
    return linter((view) => {
        const diagnostics = []
        const text = view.state.doc.toString()
        const lines = text.split('\n')

        // Track defined variables and classes
        const definedNames = new Set(javaBuiltins)

        // First pass: collect definitions
        lines.forEach((line) => {
            const trimmed = line.trim()
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.length === 0) return

            // Class declarations
            const classMatch = trimmed.match(/^(?:public\s+)?(?:abstract\s+)?(?:final\s+)?class\s+(\w+)/)
            if (classMatch) definedNames.add(classMatch[1])

            // Interface declarations
            const interfaceMatch = trimmed.match(/^(?:public\s+)?interface\s+(\w+)/)
            if (interfaceMatch) definedNames.add(interfaceMatch[1])

            // Method declarations
            const methodMatch = trimmed.match(/^(?:public|private|protected)?\s*(?:static\s+)?(?:final\s+)?(?:\w+(?:<[^>]+>)?)\s+(\w+)\s*\(/)
            if (methodMatch && !javaBuiltins.has(methodMatch[1])) {
                definedNames.add(methodMatch[1])
            }

            // Variable declarations (including generics)
            const varMatch = trimmed.match(/^(?:public|private|protected)?\s*(?:static\s+)?(?:final\s+)?(?:int|double|float|long|short|byte|char|boolean|String|[\w<>]+)\s+(\w+)\s*[=;]/)
            if (varMatch) definedNames.add(varMatch[1])

            // For loop variables
            const forMatch = trimmed.match(/^for\s*\(\s*(?:int|double|float|String|var|\w+)\s+(\w+)/)
            if (forMatch) definedNames.add(forMatch[1])

            // Enhanced for loop
            const enhancedForMatch = trimmed.match(/^for\s*\(\s*(?:\w+)\s+(\w+)\s*:/)
            if (enhancedForMatch) definedNames.add(enhancedForMatch[1])

            // Try-catch variables
            const catchMatch = trimmed.match(/^catch\s*\(\s*\w+\s+(\w+)\s*\)/)
            if (catchMatch) definedNames.add(catchMatch[1])

            // Import statements
            const importMatch = trimmed.match(/^import\s+(?:static\s+)?[\w.]+\.(\w+|\*)/)
            if (importMatch && importMatch[1] !== '*') {
                definedNames.add(importMatch[1])
            }
        })

        // Check overall brace balance
        const totalOpenBraces = (text.match(/\{/g) || []).length
        const totalCloseBraces = (text.match(/\}/g) || []).length
        
        if (totalOpenBraces !== totalCloseBraces) {
            for (let i = lines.length - 1; i >= 0; i--) {
                if (lines[i].includes('{') || lines[i].includes('}')) {
                    const from = view.state.doc.line(i + 1).from
                    const to = view.state.doc.line(i + 1).to
                    diagnostics.push({
                        from,
                        to,
                        severity: 'error',
                        message: `Unmatched braces: ${totalOpenBraces} opening, ${totalCloseBraces} closing`
                    })
                    break
                }
            }
        }

        // Second pass: check for errors
        lines.forEach((line, lineIndex) => {
            const from = view.state.doc.line(lineIndex + 1).from
            const to = view.state.doc.line(lineIndex + 1).to
            const trimmed = line.trim()

            // Skip empty lines, comments, and annotations
            if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*') || trimmed.startsWith('@')) return

            // Check what type of statement this is
            const endsWithSemicolon = trimmed.endsWith(';')
            const endsWithBrace = trimmed.endsWith('{') || trimmed.endsWith('}')
            const endsWithColon = trimmed.endsWith(':')
            
            // Keywords that DON'T need semicolons
            const controlKeywords = /^(if|else|for|while|do|switch|try|catch|finally|synchronized)\s*[\(\{]/.test(trimmed)
            const declarationKeywords = /^(public|private|protected|abstract|final|static|class|interface|enum)\s/.test(trimmed)
            const packageOrImport = /^(package|import)\s/.test(trimmed)
            const caseOrDefault = /^(case\s+.+|default)\s*:/.test(trimmed)
            
            // Check if line is inside a method body (count braces before this line)
            const textBeforeLine = text.substring(0, from)
            const openBracesBeforeLine = (textBeforeLine.match(/\{/g) || []).length
            const closeBracesBeforeLine = (textBeforeLine.match(/\}/g) || []).length
            const isInsideMethod = openBracesBeforeLine > closeBracesBeforeLine
            
            // Statements that NEED semicolons
            const isVariableDeclaration = /^(?:public|private|protected)?\s*(?:static|final)?\s*(?:int|double|float|long|short|byte|char|boolean|String|var|\w+(?:<[^>]+>)?)\s+\w+(?:\s*=\s*.+)?$/.test(trimmed)
            const isAssignment = /^\w+(?:\[\w*\]|\.\w+)*\s*[+\-*/%&|^]?=\s*.+$/.test(trimmed) && !trimmed.includes('(')
            const isReturnStatement = /^return\b/.test(trimmed)
            const isThrowStatement = /^throw\b/.test(trimmed)
            const isBreakOrContinue = /^(break|continue)\b/.test(trimmed)
            const isMethodCall = /^\w+(?:\.\w+)*\s*\([^)]*\)$/.test(trimmed) || /^(?:this|super)\.\w+\s*\([^)]*\)$/.test(trimmed)
            const isObjectCreation = /^new\s+\w+(?:<[^>]+>)?\s*\([^)]*\)$/.test(trimmed)
            const isArrayInit = /^\w+\s*\[\s*\w*\s*\]\s*=\s*new\s+/.test(trimmed)
            const isIncrementDecrement = /^(?:\+\+|--)\w+$|^\w+(?:\+\+|--)$/.test(trimmed)
            const isSystemOut = /^System\.(?:out|err)\.\w+\s*\([^)]*\)$/.test(trimmed)
            const isAssertStatement = /^assert\s+/.test(trimmed)
            
            // Check if this is a method declaration (has parameters and opens a brace on same or next line)
            const isMethodDeclaration = /^(?:public|private|protected)?\s*(?:static|final)?\s*\w+(?:<[^>]+>)?\s+\w+\s*\([^)]*\)(?:\s*throws\s+[\w,\s]+)?$/.test(trimmed)
            
            // Check if next non-empty line starts with a brace (indicates method declaration)
            let nextNonEmptyLine = ''
            for (let i = lineIndex + 1; i < lines.length; i++) {
                const nextTrimmed = lines[i].trim()
                if (nextTrimmed.length > 0 && !nextTrimmed.startsWith('//') && !nextTrimmed.startsWith('/*')) {
                    nextNonEmptyLine = nextTrimmed
                    break
                }
            }
            const nextLineStartsWithBrace = nextNonEmptyLine.startsWith('{')
            
            // Comprehensive semicolon check
            const needsSemicolon = (
                !endsWithSemicolon &&
                !endsWithBrace &&
                !endsWithColon &&
                !controlKeywords &&
                !declarationKeywords &&
                !packageOrImport &&
                !caseOrDefault &&
                !(isMethodDeclaration && (endsWithBrace || nextLineStartsWithBrace)) &&
                isInsideMethod &&
                (
                    isVariableDeclaration ||
                    isAssignment ||
                    isReturnStatement ||
                    isThrowStatement ||
                    isBreakOrContinue ||
                    isMethodCall ||
                    isObjectCreation ||
                    isArrayInit ||
                    isIncrementDecrement ||
                    isSystemOut ||
                    isAssertStatement
                )
            )

            if (needsSemicolon) {
                diagnostics.push({
                    from: to - 1,
                    to,
                    severity: 'error',
                    message: 'Missing semicolon'
                })
            }

            // Check for unmatched parentheses
            const openParens = (line.match(/\(/g) || []).length
            const closeParens = (line.match(/\)/g) || []).length

            if (openParens !== closeParens) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Unmatched parentheses'
                })
            }

            // Assignment in condition (= instead of ==)
            if (/^\s*if\s*\([^)]*[^=!<>]=[^=]/.test(line)) {
                const equalPos = line.indexOf('=')
                if (equalPos > 0 && line[equalPos + 1] !== '=' && line[equalPos - 1] !== '!') {
                    diagnostics.push({
                        from: from + equalPos,
                        to: from + equalPos + 1,
                        severity: 'warning',
                        message: 'Assignment in condition. Did you mean ==?'
                    })
                }
            }

            // String comparison using ==
            if (/\bString\s+\w+/.test(text) && /==\s*["']|["']\s*==/.test(line)) {
                const eqPos = line.indexOf('==')
                if (eqPos >= 0) {
                    diagnostics.push({
                        from: from + eqPos,
                        to: from + eqPos + 2,
                        severity: 'warning',
                        message: 'Use .equals() for String comparison instead of =='
                    })
                }
            }

            // Missing break in switch case
            if (/^case\s+.+:/.test(trimmed) || /^default\s*:/.test(trimmed)) {
                const nextLines = lines.slice(lineIndex + 1, Math.min(lineIndex + 6, lines.length))
                const hasBreak = nextLines.some(l => /^\s*(break|return|throw)\b/.test(l))
                const hasNextCase = nextLines.some(l => /^\s*(case\s+|default\s*:|})/.test(l))
                
                if (!hasBreak && hasNextCase) {
                    const nextCaseIndex = nextLines.findIndex(l => /^\s*(case\s+|default\s*:)/.test(l))
                    if (nextCaseIndex > 0) {
                        diagnostics.push({
                            from,
                            to,
                            severity: 'warning',
                            message: 'Missing break statement in switch case (potential fall-through)'
                        })
                    }
                }
            }

            // Unused imports (simple check)
            const importMatch = trimmed.match(/^import\s+(?:static\s+)?([\w.]+)\.(\w+|\*);/)
            if (importMatch && importMatch[2] !== '*') {
                const importedName = importMatch[2]
                const regex = new RegExp(`\\b${importedName}\\b`)
                const restOfCode = lines.slice(lineIndex + 1).join('\n')
                if (!regex.test(restOfCode)) {
                    diagnostics.push({
                        from,
                        to,
                        severity: 'info',
                        message: `Unused import: ${importedName}`
                    })
                }
            }

            // Potential NullPointerException
            const hasNullableMethodCall = /\w+\.\w+\s*\(/.test(trimmed) && !trimmed.includes('null')
            if (hasNullableMethodCall && isInsideMethod) {
                const variableName = trimmed.match(/^(\w+)\./)?.[1]
                if (variableName && !javaBuiltins.has(variableName)) {
                    const precedingLines = lines.slice(Math.max(0, lineIndex - 5), lineIndex).join('\n')
                    const hasNullCheck = new RegExp(`${variableName}\\s*[!=]=\\s*null`).test(precedingLines)
                    
                    if (!hasNullCheck) {
                        diagnostics.push({
                            from,
                            to,
                            severity: 'info',
                            message: `Consider null-checking '${variableName}' before method call`
                        })
                    }
                }
            }
        })

        return diagnostics
    })
}

export const createCLinter = () => {
    return linter((view) => {
        const diagnostics = []
        const text = view.state.doc.toString()
        const lines = text.split('\n')

        // Track defined variables and functions
        const definedNames = new Set(cBuiltins)

        // First pass: collect definitions
        lines.forEach((line) => {
            const trimmed = line.trim()
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.length === 0) return

            // Function declarations/definitions
            const funcMatch = trimmed.match(/^(?:static\s+)?(?:inline\s+)?(?:\w+\s+\*?\s*)?(\w+)\s*\([^)]*\)\s*[{;]/)
            if (funcMatch && !cBuiltins.has(funcMatch[1])) {
                definedNames.add(funcMatch[1])
            }

            // Variable declarations
            const varMatch = trimmed.match(/^(?:static\s+)?(?:const\s+)?(?:unsigned\s+)?(?:int|char|float|double|long|short|void)\s+\*?\s*(\w+)/)
            if (varMatch) definedNames.add(varMatch[1])

            // Struct/enum declarations
            const structMatch = trimmed.match(/^(?:typedef\s+)?struct\s+(\w+)/)
            if (structMatch) definedNames.add(structMatch[1])

            const enumMatch = trimmed.match(/^(?:typedef\s+)?enum\s+(\w+)/)
            if (enumMatch) definedNames.add(enumMatch[1])

            // Typedef declarations
            const typedefMatch = trimmed.match(/^typedef\s+.+\s+(\w+);/)
            if (typedefMatch) definedNames.add(typedefMatch[1])

            // #define macros
            const defineMatch = trimmed.match(/^#define\s+(\w+)/)
            if (defineMatch) definedNames.add(defineMatch[1])

            // For loop variables
            const forMatch = trimmed.match(/^for\s*\(\s*(?:int|char|float|double)\s+(\w+)/)
            if (forMatch) definedNames.add(forMatch[1])
        })

        // Check overall brace balance for the entire file
        const totalOpenBraces = (text.match(/\{/g) || []).length
        const totalCloseBraces = (text.match(/\}/g) || []).length
        
        if (totalOpenBraces !== totalCloseBraces) {
            // Find the last line with a brace to show the error
            for (let i = lines.length - 1; i >= 0; i--) {
                if (lines[i].includes('{') || lines[i].includes('}')) {
                    const from = view.state.doc.line(i + 1).from
                    const to = view.state.doc.line(i + 1).to
                    diagnostics.push({
                        from,
                        to,
                        severity: 'error',
                        message: `Unmatched braces: ${totalOpenBraces} opening, ${totalCloseBraces} closing`
                    })
                    break
                }
            }
        }

        // Second pass: check for other errors
        lines.forEach((line, lineIndex) => {
            const from = view.state.doc.line(lineIndex + 1).from
            const to = view.state.doc.line(lineIndex + 1).to
            const trimmed = line.trim()

            // Skip empty lines and comments
            if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('/*')) return

            // Check for invalid standalone identifiers/statements
            const isControlStructure = /^(if|else|for|while|do|switch|case|default|break|continue)\b/.test(trimmed)
            const isPreprocessor = trimmed.startsWith('#')
            const isDeclaration = /^(typedef|struct|enum|union)\b/.test(trimmed) || 
                                 /^(?:static\s+)?(?:const\s+)?(?:unsigned\s+)?(?:int|char|float|double|long|short|void|auto)\b/.test(trimmed)
            const isFunctionDef = /\w+\s*\([^)]*\)\s*\{?\s*$/.test(trimmed)
            const endsWithBrace = trimmed.endsWith('{') || trimmed.endsWith('}')
            const endsWithSemicolon = trimmed.endsWith(';')
            const isLabel = trimmed.endsWith(':') && !trimmed.includes('?') // Exclude ternary operator

            // Check if it's a standalone identifier that doesn't belong
            if (!isControlStructure && 
                !isPreprocessor && 
                !isDeclaration && 
                !isFunctionDef && 
                !endsWithBrace && 
                !endsWithSemicolon && 
                !isLabel &&
                trimmed.length > 0) {
                
                // If it's just an identifier or expression without semicolon
                if (/^[a-zA-Z_]\w*$/.test(trimmed) || // standalone identifier
                    /^\w+[\w\s\+\-\*\/\%\=\<\>\!\&\|\^]*$/.test(trimmed)) { // expression without semicolon
                    
                    diagnostics.push({
                        from,
                        to,
                        severity: 'error',
                        message: `Invalid statement: '${trimmed}' - missing semicolon or invalid syntax`
                    })
                }
            }

            // Original semicolon checking for specific statements
            const needsSemicolon = (
                trimmed.length > 0 && 
                !trimmed.endsWith(';') && 
                !trimmed.endsWith('{') && 
                !trimmed.endsWith('}') &&
                !trimmed.startsWith('#') &&
                !isControlStructure &&
                // Check if it's a statement that should end with semicolon
                (/^(return|printf|scanf|malloc|free|exit|break|continue)\b/.test(trimmed) ||
                 /^\w+\s*=/.test(trimmed) || // assignments
                 /^\w+\s*\([^)]*\)\s*$/.test(trimmed)) // function calls without semicolon
            )

            if (needsSemicolon) {
                diagnostics.push({
                    from: to - 1,
                    to,
                    severity: 'error',
                    message: 'Missing semicolon'
                })
            }

            // Check for unmatched parentheses only (not braces, as they span multiple lines)
            const openParens = (line.match(/\(/g) || []).length
            const closeParens = (line.match(/\)/g) || []).length

            if (openParens !== closeParens) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Unmatched parentheses'
                })
            }

            // Assignment in condition (= instead of ==)
            if (/^\s*if\s*\([^)]*[^=!<>]=[^=]/.test(line)) {
                const equalPos = line.indexOf('=')
                if (equalPos > 0) {
                    diagnostics.push({
                        from: from + equalPos,
                        to: from + equalPos + 1,
                        severity: 'warning',
                        message: 'Assignment in condition. Did you mean ==?'
                    })
                }
            }

            // Missing #include for standard functions
            if (!text.includes('#include <stdio.h>') && /\b(printf|scanf|getchar|putchar)\b/.test(line)) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Missing #include <stdio.h> for I/O functions'
                })
            }

            if (!text.includes('#include <stdlib.h>') && /\b(malloc|free|exit|system)\b/.test(line)) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Missing #include <stdlib.h> for standard functions'
                })
            }

            if (!text.includes('#include <string.h>') && /\b(strlen|strcpy|strcmp|strcat)\b/.test(line)) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Missing #include <string.h> for string functions'
                })
            }

            // Potential memory leaks (malloc without free)
            if (/\bmalloc\s*\(/.test(line) && !text.includes('free(')) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Potential memory leak: malloc without corresponding free'
                })
            }
        })

        return diagnostics
    })
}

export const createCppLinter = () => {
    return linter((view) => {
        const diagnostics = []
        const text = view.state.doc.toString()
        const lines = text.split('\n')

        // Track defined variables, functions, and classes
        const definedNames = new Set(cppBuiltins)

        // First pass: collect definitions
        lines.forEach((line) => {
            const trimmed = line.trim()
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.length === 0) return

            // Class/struct declarations
            const classMatch = trimmed.match(/^(?:class|struct)\s+(\w+)/)
            if (classMatch) definedNames.add(classMatch[1])

            // Function declarations/definitions
            const funcMatch = trimmed.match(/^(?:virtual\s+)?(?:static\s+)?(?:inline\s+)?(?:\w+::\s*)?(?:\w+\s+)?(\w+)\s*\([^)]*\)\s*(?:const\s*)?[{;]/)
            if (funcMatch && !cppBuiltins.has(funcMatch[1]) && funcMatch[1] !== 'if' && funcMatch[1] !== 'for') {
                definedNames.add(funcMatch[1])
            }

            // Variable declarations
            const varMatch = trimmed.match(/^(?:static\s+)?(?:const\s+)?(?:mutable\s+)?(?:\w+::\s*)?(?:\w+\s+\*?\s*&?\s*)?(\w+)\s*[=;]/)
            if (varMatch && !cppBuiltins.has(varMatch[1])) {
                definedNames.add(varMatch[1])
            }

            // Namespace declarations
            const namespaceMatch = trimmed.match(/^namespace\s+(\w+)/)
            if (namespaceMatch) definedNames.add(namespaceMatch[1])

            // Template declarations
            const templateMatch = trimmed.match(/^template\s*<.*>\s*(?:class|struct|typename)\s+(\w+)/)
            if (templateMatch) definedNames.add(templateMatch[1])

            // Using declarations
            const usingMatch = trimmed.match(/^using\s+(?:namespace\s+)?(\w+)/)
            if (usingMatch) definedNames.add(usingMatch[1])

            // Auto variables
            const autoMatch = trimmed.match(/^auto\s+(\w+)\s*=/)
            if (autoMatch) definedNames.add(autoMatch[1])

            // For loop variables (including range-based)
            const forMatch = trimmed.match(/^for\s*\(\s*(?:auto|int|char|float|double|const\s+\w+)\s+(\w+)/)
            if (forMatch) definedNames.add(forMatch[1])
        })

        // Check overall brace balance for the entire file
        const totalOpenBraces = (text.match(/\{/g) || []).length
        const totalCloseBraces = (text.match(/\}/g) || []).length
        
        if (totalOpenBraces !== totalCloseBraces) {
            // Find the last line with a brace to show the error
            for (let i = lines.length - 1; i >= 0; i--) {
                if (lines[i].includes('{') || lines[i].includes('}')) {
                    const from = view.state.doc.line(i + 1).from
                    const to = view.state.doc.line(i + 1).to
                    diagnostics.push({
                        from,
                        to,
                        severity: 'error',
                        message: `Unmatched braces: ${totalOpenBraces} opening, ${totalCloseBraces} closing`
                    })
                    break
                }
            }
        }

        // Second pass: check for other errors
        lines.forEach((line, lineIndex) => {
            const from = view.state.doc.line(lineIndex + 1).from
            const to = view.state.doc.line(lineIndex + 1).to
            const trimmed = line.trim()

            // Skip empty lines and comments
            if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('/*')) return

            // Missing semicolons (less strict than C)
            const needsSemicolon = (
                trimmed.length > 0 && 
                !trimmed.endsWith(';') && 
                !trimmed.endsWith('{') && 
                !trimmed.endsWith('}') &&
                !trimmed.endsWith(':') &&
                !trimmed.startsWith('#') &&
                !/^(if|else|for|while|do|switch|case|default|class|struct|namespace|template|public|private|protected)\b/.test(trimmed) &&
                (/^(int|char|float|double|long|short|void|static|const|unsigned|return|cout|cin)\b/.test(trimmed) ||
                 /^\w+\s*=/.test(trimmed) || // assignments
                 /^\w+\s*\(.*\);\s*$/.test(trimmed)) && // function calls
                !trimmed.endsWith(';')
            )

            if (needsSemicolon) {
                diagnostics.push({
                    from: to - 1,
                    to,
                    severity: 'error',
                    message: 'Missing semicolon'
                })
            }

            // Check for unmatched parentheses only (not braces)
            const openParens = (line.match(/\(/g) || []).length
            const closeParens = (line.match(/\)/g) || []).length

            if (openParens !== closeParens) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'error',
                    message: 'Unmatched parentheses'
                })
            }

            // Assignment in condition
            if (/^\s*if\s*\([^)]*[^=!<>]=[^=]/.test(line)) {
                const equalPos = line.indexOf('=')
                if (equalPos > 0) {
                    diagnostics.push({
                        from: from + equalPos,
                        to: from + equalPos + 1,
                        severity: 'warning',
                        message: 'Assignment in condition. Did you mean ==?'
                    })
                }
            }

            // Missing using namespace std or std:: prefix
            if (/\b(cout|cin|cerr|endl|string|vector|map|set)\b/.test(line) && 
                !text.includes('using namespace std') && 
                !line.includes('std::')) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Consider using std:: prefix or "using namespace std;"'
                })
            }

            // Missing includes
            if (!text.includes('#include <iostream>') && /\b(cout|cin|cerr|clog)\b/.test(line)) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Missing #include <iostream> for I/O streams'
                })
            }

            if (!text.includes('#include <vector>') && /\bvector\b/.test(line)) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Missing #include <vector> for vector container'
                })
            }

            if (!text.includes('#include <string>') && /\bstring\b/.test(line) && !line.includes('char*')) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Missing #include <string> for string class'
                })
            }

            // Raw pointers without smart pointers (suggestion)
            if (/\bnew\s+\w+/.test(line) && !text.includes('delete') && !text.includes('unique_ptr') && !text.includes('shared_ptr')) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'info',
                    message: 'Consider using smart pointers instead of raw pointers'
                })
            }

            // Missing virtual destructor in base class
            if (/^class\s+\w+/.test(trimmed) && text.includes('virtual') && !text.includes('virtual ~')) {
                diagnostics.push({
                    from,
                    to,
                    severity: 'warning',
                    message: 'Consider adding virtual destructor for polymorphic base class'
                })
            }
        })

        return diagnostics
    })
}

// Factory function to create linters
export const createLinter = (language) => {
    switch (language) {
        case 'Python':
            return createPythonLinter()
        case 'Javascript':
            return createJavaScriptLinter()
        case 'Java':
            return createJavaLinter()
        case 'C':
            return createCLinter()
        case 'C++':
        case 'Cpp':
            return createCppLinter()
        default:
            return null
    }
}
