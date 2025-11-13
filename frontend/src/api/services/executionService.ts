/**
 * Execution Service - TypeScript service layer for code execution
 * Handles all execution logic and output formatting
 */

// Language mapping to Judge0 IDs
const LANGUAGE_MAP: Record<string, number> = {
    'Python': 71,
    'Javascript': 63,
    'Java': 62,
    'C++': 54,
    'C': 50,
    'C#': 51,
    'Go': 60,
    'Rust': 73,
    'PHP': 68,
    'Ruby': 72,
    'Swift': 83,
    'Kotlin': 78,
    'Scala': 81,
    'TypeScript': 74,
}

// Default code templates for different languages
const DEFAULT_CODE_TEMPLATES: Record<string, string> = {
    'Python': "print('Hello, World!')",
    'Javascript': "console.log('Hello, World!');",
    'Java': `public class Main {
  public static void main(String[] args) {
    System.out.println("Hello, World!");
  }
}`,
    'C++': `#include <iostream>
using namespace std;

int main() {
  cout << "Hello, World!" << endl;
  return 0;
}`,
    'C': `#include <stdio.h>

int main() {
  printf("Hello, World!\\n");
  return 0;
}`,
    'C#': `using System;

class Program {
    static void Main() {
        Console.WriteLine("Hello, World!");
    }
}`,
    'Go': `package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}`,
    'Rust': `fn main() {
    println!("Hello, World!");
}`,
    'PHP': `<?php
echo "Hello, World!";
?>`,
    'Ruby': `puts "Hello, World!"`,
    'Swift': `print("Hello, World!")`,
    'Kotlin': `fun main() {
    println("Hello, World!")
}`,
    'Scala': `object Main {
  def main(args: Array[String]): Unit = {
    println("Hello, World!")
  }
}`,
    'TypeScript': `console.log('Hello, World!');`
}

// Types
interface ExecutionRequest {
    language_id: number
    source_code: string
    stdin: string
}

interface ExecutionResponse {
    status: string
    stdout: string
    stderr: string
    time: string
    memory: number
    compile_output?: string
}

interface TestCase {
    input: string
    output: string
}

interface TestResult {
    ok: boolean
    status: string
    input: string
    stdout: string
    expected: string
    stderr: string
    time: string
    memory: number
    error?: string
}

interface TestSummary {
    passed: number
    total: number
}

interface TestExecutionResponse {
    summary: TestSummary
    results: TestResult[]
}

interface ServiceResult {
    success: boolean
    outputText: string
    error?: string
}

/**
 * Execution Service Class
 */
class ExecutionService {
    private baseUrl: string

    constructor() {
        this.baseUrl = (import.meta as any).env?.VITE_EXECUTION_SERVICE_URL || '/execution-service-api'
    }

    /**
     * Get Judge0 language ID for a given language name
     */
    getLanguageId(language: string): number {
        return LANGUAGE_MAP[language] || 71 // Default to Python
    }

    /**
     * Get default code template for a language
     */
    getDefaultCode(language: string): string {
        return DEFAULT_CODE_TEMPLATES[language] || DEFAULT_CODE_TEMPLATES['Python']
    }

    /**
     * Execute code and return formatted result
     */
    async execute(language: string, sourceCode: string, stdin: string = ""): Promise<ServiceResult> {
        try {
            const request: ExecutionRequest = {
                language_id: this.getLanguageId(language),
                source_code: sourceCode,
                stdin: stdin
            }

            const response = await fetch(`${this.baseUrl}/api/execute`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(request),
            })

            const data: ExecutionResponse = await response.json()
            
            if (response.ok) {
                return {
                    success: true,
                    outputText: this.formatExecutionOutput(data)
                }
            } else {
                return {
                    success: false,
                    outputText: `Error: ${data.status || 'Execution failed'}`,
                    error: data.status
                }
            }
        } catch (error) {
            return {
                success: false,
                outputText: `Error: Could not connect to execution service - ${error instanceof Error ? error.message : 'Unknown error'}`,
                error: error instanceof Error ? error.message : 'Unknown error'
            }
        }
    }

    /**
     * Execute code against test cases
     */
    async runTests(language: string, sourceCode: string, questionId: string): Promise<ServiceResult> {
        if (!questionId) {
            return {
                success: false,
                outputText: "Error: No question selected for testing",
                error: "No question ID provided"
            }
        }

        try {
            const request = {
                language_id: this.getLanguageId(language),
                source_code: sourceCode,
                question_id: questionId
            }

            const response = await fetch(`${this.baseUrl}/api/execute/tests`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(request),
            })

            const data: TestExecutionResponse = await response.json()
            
            if (response.ok) {
                return {
                    success: true,
                    outputText: this.formatTestOutput(data)
                }
            } else {
                return {
                    success: false,
                    outputText: `Error: ${data.summary ? 'Test execution failed' : 'Unknown error'}`,
                    error: 'Test execution failed'
                }
            }
        } catch (error) {
            return {
                success: false,
                outputText: `Error: Could not connect to execution service - ${error instanceof Error ? error.message : 'Unknown error'}`,
                error: error instanceof Error ? error.message : 'Unknown error'
            }
        }
    }

    /**
     * Format execution output for display
     */
    private formatExecutionOutput(data: ExecutionResponse): string {
        let outputText = ""
        
        if (data.stdout) {
            outputText += `Output:\n${data.stdout}`
        }
        if (data.stderr) {
            outputText += `\n\nErrors:\n${data.stderr}`
        }
        if (data.compile_output) {
            outputText += `\n\nCompile Output:\n${data.compile_output}`
        }
        if (data.time) {
            outputText += `\n\nTime: ${data.time}s`
        }
        if (data.memory) {
            outputText += ` | Memory: ${data.memory}KB`
        }
        
        return outputText || `Status: ${data.status}`
    }

    /**
     * Format test execution output for display
     */
    private formatTestOutput(data: TestExecutionResponse): string {
        const { summary, results } = data
        let outputText = `Test Results: ${summary.passed}/${summary.total} tests passed\n\n`
        
        results.forEach((result, index) => {
            const status = result.ok ? "✅ PASS" : "❌ FAIL"
            outputText += `Test ${index + 1}: ${status}\n`
            outputText += `  Status: ${result.status}\n`
            
            if (result.input !== undefined) {
                outputText += `  Input: ${result.input}\n`
            }
            if (result.stdout) {
                outputText += `  Output: ${result.stdout}\n`
            }
            if (result.expected) {
                outputText += `  Expected: ${result.expected}\n`
            }
            if (result.stderr) {
                outputText += `  Error: ${result.stderr}\n`
            }
            if (result.time) {
                outputText += `  Time: ${result.time}s\n`
            }
            outputText += "\n"
        })
        
        return outputText
    }

    /**
     * Get supported languages
     */
    async getSupportedLanguages(): Promise<ServiceResult> {
        try {
            const response = await fetch(`${this.baseUrl}/api/languages`)
            const data = await response.json()
            
            if (response.ok) {
                return {
                    success: true,
                    outputText: JSON.stringify(data.languages, null, 2)
                }
            } else {
                return {
                    success: false,
                    outputText: `Error: ${data.error || 'Failed to fetch languages'}`,
                    error: data.error || 'Failed to fetch languages'
                }
            }
        } catch (error) {
            return {
                success: false,
                outputText: `Error: Could not connect to execution service - ${error instanceof Error ? error.message : 'Unknown error'}`,
                error: error instanceof Error ? error.message : 'Unknown error'
            }
        }
    }
}

// Create and export a singleton instance
const executionService = new ExecutionService()
export default executionService

// Export the class for testing purposes
export { ExecutionService }
export type { ServiceResult, ExecutionRequest, ExecutionResponse, TestExecutionResponse }
