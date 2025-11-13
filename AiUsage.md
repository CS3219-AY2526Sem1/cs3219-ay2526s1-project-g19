# Usage of AI Tools in PeerPrep Project

## Introduction

Multiple AI tools were utilized throughout the development of PeerPrep. The AI tools used in this project include ChatGPT, Claude, Gemini, GitHub Copilot, Cursor, and Lovable. These tools provided guidance, suggestion, and support throughout the project development process.

The strategic and responsible integration of AI tools - ChatGPT, Claude, GitHub Copilot, Cursor, Gemini, and Lovable - significantly enhanced the PeerPrep development process in meaningful and measurable ways. These tools served as intelligent assistants that provided valuable guidance, suggestions, and support, enabling the team to tackle a more ambitious project scope while maintaining high quality standards.

Usage of these AI tools significantly improved productivity, code quality, learning outcomes, and problem-solving efficiency. This allowed the team to focus on the more complex and critical aspects of the project such as architecture design and implementation, identifying key requirements, evaluating user needs, and more.

## Responsible AI Usage Practices
### What AI is Not Used For
To ensure responsible and ethical use of AI tools in the development process, the team established clear boundaries regarding what AI is not used for, including:

- **Requirements Work**: Process such as gathering project requirements, user stories, acceptance criteria, consolidating backlog, sprint planning, and feature prioritization were conducted through team collaboration and dicussion with various iterations of meetings to consolidate and finalize the project scope. Avoiding using AI for these tasks ensure that the team truly understand the project needs and user expectations, and able to make informed decisions about the project design and implementation.

- **Architecture and Design Decisions**: All system architecture decisions, technology stack selections, and design pattern choices are discussed and finalized by the team through collaborative decision-making. This allow the team to iteratively refine and optimize the architecture and design based on knowledge taught in the module rather than relying on AI-generated suggestions.

- **Decision rationales**: The team ensured that critical decisions involving drafting trade-off analyses, risk or justificion mentions are made by team members through discussion and peer feedbacks. This helps the team to develop reasoning and technical decision-making skill that are essential in developing software systems.

Through these clear boundaries, the team are able to maintain ownership and accountability for the critical aspects of the project while leveraging AI tools to improve productivity and efficiency in some of the non-decision-making or routine tasks. This also aid the team to stay relevant to the project requirements and learning objectives of the module.

### Key Responsible Practices Followed
Some key practices of responsible AI usage is followed by the team to ensure ethical and effective integration of AI tools in the project development process:

- **Understand Before Implementing**: The team members ensure to understand the context, logic, implication, and trade-off of any AI generated code or suggestion before implementing the output into the project. This helps to prevent blind implementation of AI outputs and ensure that the team had thorough understanding of the codebase logic and implementation details. This also avoid the risk of going out of scope, creating maintainability issues, or introducing bugs vulnerabilities.

- **Validation and Verification**: All AI outputs are validated and verified ensure reliable and creditable resources to ensure the correctness and relevance of the generated suggestions. This includes cross-referencing with official documentation, testing AI-influenced code thoroughly, and active discussion within team members to evaluate the suitability of AI suggestions within different services and components.

- **Use AI When Necessary**: The team strategically use AI tools to enhance productivity and accelerate routine tasks while preserving opportunities for skill development and creative problem-solving. This includes using AI for boilerplate code generation, documentation enhancement, debugging assistance, and learning support, while ensuring that critical thinking and independent judgment remain focused on the development process.

- **Focus on Skill Development**: The team consciously limit the usage of AI as an assistant tool to develop fundamental skills instead of over-relying on AI for problem-solving and code implementation without understanding the underlying concepts. This ensure that the team members are able to develop and maintain their software engineering skills while leveraging AI tools for enhanced productivity.

- **Incremental Integration**: AI suggestions are implemented in small, testable chunks incrementally rather than adopting large code blocks. This helps in ensuring that each change is verified and understood clearly.

- **Transparency in AI Usage**: Last but not least, the team ensure to document the usage of AI tools to acknowledge the role of AI in the development process. This help to keep track of contributions made by AI tools and maintain transparency about the extent of AI assistance in the project.

By practicing these responsible AI usage practices, the team are able to integrate AI tools into the development process in a way that enhanced productivity, maintained code quality, and preserved learning objectives.

## AI Tools Used
### 1. Lovable

At first, a draft sketch of the user interface was created with Excalidraw to visualize initial design concepts. To enhance the readability and presentation quality of these designs, the team discovered Lovable, an AI-powered design tool that can transform rough sketches into high-quality visual mockups.

The detailed and polished mockup generated by Lovable based on the initial sketches facilitated the team discussion and visualization of the user interface before actual implementation. This helped the team to align on feature design decisions and provided a clear reference for frontend development.

### 2. ChatGPT, Gemini, Claude and Cursor

These AI tools were primarily used for problem-solving guidance, code explanation, and technical learning support.

#### Applications Examples

**Implementation Code Guidance**
- Provided guidance on implementing some key features such as WebSocket connection handling for collaboration service real-time chat functionality.
- Assisted with React component structure suggestions for complex UI elements like the collaborative code editor interface, session history table, and matching service modal, providing guidance on state management patterns and component composition.
- Helped explore different approaches to implementing language selection and code template management in the question practice feature, enabling language switching while ensuring proper state updates and component re-renders.

**Debugging Assistance**
- Provided detailed explanations for complex Kafka-related errors such as schema compatibility issues, consumer group rebalancing problems, and message serialization failures with Avro format, helping team to understand root causes and potential solutions for bug fixes.
- Offered debugging strategies for Redis connection and WebSocket state synchronization issues between frontend and backend, suggested debugging approaches using browser developer tools and backend logging.
- Assisted in troubleshooting Docker networking issues between microservices, explaining container DNS resolution and network bridge configurations.
- Provided explanations for PostgreSQL query performance issues and migration errors, suggesting query optimization approaches and schema modification strategies.

**Technical Documentation Enhancement**
- Assisted in refining document files with clear setup instructions, dependency explanations, and troubleshooting guides to help team members and future contributors to understand the project setup and requirements.

**Learning and Conceptual Understanding**
- Assisted in understanding WebSocket protocol details, including connection states, and event-driven communication patterns.
- Explained Kafka's schema registry concepts, including schema evolution, compatibility modes, and best practices for managing schemas across multiple services.
- Provided explanations of Docker container architecture, build processes, and debugging techniques which are essential for the development and troubleshooting process.

**Code Comprehension and Analysis**
- Helped team members understand complex codebases written by other team members efficiently, to accelerate collaboration and integration across different services.
- Assisted in understanding microservices communication patterns and how different services interact through Kafka events and REST API calls.

**Code Refactoring Guidance and Suggestions**
- Suggested approaches for splitting the large CollaborationPage component into smaller, more manageable sub-components (CodeEditor, ChatBox, QuestionPanel, SessionTimer), providing explanations of the benefits of component composition and separation of concerns.
- Assisted in identifying code duplication across microservices and suggesting strategies for creating shared utility functions while respecting service boundaries.
- Provided guidance on improving error handling consistency across frontend components, suggesting patterns for centralized error logging and user-friendly error message display with the NotificationContext component.

### 3. GitHub Copilot

Copilot are the real-time coding assistants throughout the development process, providing inline suggestions and autocompletion that accelerated routine coding tasks. GitHub Copilot provide a clear context-aware coding assistance by clear display of code changes and suggestions, allowing the team to maintain full control over implementation decisions.

#### Applications Examples
**Code Completion and Suggestions**
- Provided real-time code implementation suggestions based on function names and project comments, offering multiple alternative approaches and different code snippets for developers to review and select from.
- Offered completion suggestions for based on existing code patterns that accelerated coding speed and maintained consistency.
- Provided inline suggestions for bug fixes and improvements based on code analysis, helping developers identify potential issues and optimize code performance.


**Repetitive Code Pattern Acceleration**
- Accelerated creation of similar code patterns such as API route handlers, database model field definitions, and Pydantic schema definitions with similar field structures maintaining consistency in the codebase.

## Key Improvements Through AI Assistance
- **Accelerated Development**: AI tools significangtly reduced time spent on routine coding tasks, boilerplate creation, and documentation writing, allowing the team to focus cognitive energy on complex architectural design and core aspects of the project.
- **Enhanced Code Quality**: Consistent patterns and early issue detection throughout the codebase improved the overall code quality.
- **Learning Improvement**: The team gained proficiency with unfamiliar technologies (Kafka, Redis, FastAPI, microservices patterns, WebSocket protocols) through contextual explanations, examples, and guidance tailored to our specific use cases.
- **Debugging Efficiency**: AI allowed the team to debug faster, implement more comprehensive error handling, and adopt systematic approaches to resolving complex issues.


### Looking Forward
This experience demonstrated that when AI tools are used responsibly with appropriate boundaries, they can be powerful assistants in software development that enhance rather than diminish the learning and development experience.

Developers had to establish clear principles and boundaries about what decisions remain human-controlled and use these tools to as a support rather than a replace for fundamental software engineering skills and critical thinking capabilities. 

## Conclusion

The strategic integration of ChatGPT, Claude, GitHub Copilot, Cursor, Gemini, and Lovable significantly enhanced the PeerPrep development process. The team learned how to effectively leverage AI tools to achieve project objectives while maintaining responsibility and accountability for the critical aspects of the project. This is a valuable experience for the team as future software engineers in understanding how to responsibly and effectively integrate AI tools into the software development lifecycle.
