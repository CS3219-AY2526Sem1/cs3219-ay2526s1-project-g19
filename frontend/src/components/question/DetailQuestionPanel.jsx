import QuestionHeader from "../collaboration/questionpanel/QuestionHeader";
import QuestionDescription from "../collaboration/questionpanel/QuestionDescription";

function DetailQuestionPanel({ question: questionData }) {
  // Helper function to parse topics (can be string or array)
  const parseTopics = (topics) => {
    if (!topics) return [];
    if (Array.isArray(topics)) return topics;
    if (typeof topics === 'string') {
      try {
        const parsed = JSON.parse(topics);
        return Array.isArray(parsed) ? parsed : [topics];
      } catch {
        // If not valid JSON, split by comma or return as single item
        return topics.includes(',') ? topics.split(',').map(t => t.trim()) : [topics];
      }
    }
    return [];
  };

  // Helper function to parse examples (can be string or array)
  const parseExamples = (examples) => {
    if (!examples) return [];
    if (Array.isArray(examples)) return examples;
    if (typeof examples === 'string') {
      try {
        return JSON.parse(examples);
      } catch {
        return [];
      }
    }
    return [];
  };

  // Helper function to parse constraints (can be string or array)
  const parseConstraints = (constraints) => {
    if (!constraints) return [];
    if (Array.isArray(constraints)) return constraints;
    if (typeof constraints === 'string') {
      try {
        return JSON.parse(constraints);
      } catch {
        // Split by newline or return as single item
        return constraints.includes('\n') ? constraints.split('\n').filter(c => c.trim()) : [constraints];
      }
    }
    return [];
  };

  const question = questionData ? {
    title: questionData.title || "Untitled Question",
    difficulty: questionData.difficulty || "unknown",
    topics: parseTopics(questionData.topics),
    statement_md: questionData.statement_md || "No description available",
    examples: parseExamples(questionData.examples),
    constraints: parseConstraints(questionData.constraints),
    assets: questionData.assets || [],
    company_tags: questionData.company_tags || "None",
    stats: questionData.stats || {
      views: 0,
      attempts: 0,
      solved: 0,
      percentage_solved: 0,
      last_activity_at: new Date().toISOString()
    }
  } : {
    // Fallback
    title: "Reverse String",
    difficulty: "easy",
    topics: ["Array", "Two Pointers", "String"],
    statement_md: `Write a function that reverses a string. The input string is given as an array of characters s.

    You must do this by modifying the input array in-place with O(1) extra memory.`,
    examples: [
      {
        input: 's = ["h","e","l","l","o"]',
        output: '["o","l","l","e","h"]',
        explanation: "The string is reversed in-place."
      },
      {
        input: 's = ["H","a","n","n","a","h"]',
        output: '["h","a","n","n","a","H"]',
        explanation: "The palindrome is reversed in-place."
      }
    ],
    constraints: [
      "1 ≤ s.length ≤ 10⁵",
      "s[i] is a printable ascii character"
    ],
    assets: "No additional assets required",
    company_tags: "Amazon, Google, Microsoft",
    stats: {
      views: 125430,
      attempts: 89234,
      solved: 78901,
      percentage_solved: 88.4,
      last_activity_at: "2025-10-10T13:57:48.968Z"
    }
  };

  return (
      <div className="bg-primary-secondary/80 backdrop-blur-xl h-full">
        <QuestionHeader
          title={question.title}
          difficulty={question.difficulty}
          topics={question.topics}
          stats={question.stats}
          company_tags={question.company_tags}
        />
        <QuestionDescription
          statement={question.statement_md}
          examples={question.examples}
          constraints={question.constraints}
        />
      </div>
  );
}

export default DetailQuestionPanel;