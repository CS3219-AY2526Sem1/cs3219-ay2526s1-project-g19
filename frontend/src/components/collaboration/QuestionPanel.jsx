import QuestionHeader from "./questionpanel/QuestionHeader";
import QuestionDescription from "./questionpanel/QuestionDescription";

export default function QuestionPanel() {
  // Dummy data
  const question = {
    title: "Two Sum",
    difficulty: "Easy",
    topics: ["Array", "Hash Table"],
    statement: `Given an array of integers nums and an integer target, return indices of the two numbers such that they add up to target.`,
    examples: [
      {
        input: "nums = [2,7,11,15], target = 9",
        output: "[0,1]",
        explanation: "Because nums[0] + nums[1] == 9, we return [0, 1]."
      }
    ],
    constraints: [
      "2 ≤ nums.length ≤ 10⁴",
      "-10⁹ ≤ nums[i] ≤ 10⁹",
      "-10⁹ ≤ target ≤ 10⁹",
      "Only one valid answer exists."
    ],
    timeComplexity: "O(n)",
    spaceComplexity: "O(n)"
  };

  return (
    <div className="p-2 max-w-5xl">
      <div className="bg-white/80 dark:bg-gray-900/80 backdrop-blur-xl rounded-3xl shadow-2xl border border-gray-200/50 dark:border-gray-800/50 overflow-hidden">
        <QuestionHeader
          title={question.title}
          difficulty={question.difficulty}
          topics={question.topics}
        />
        <QuestionDescription
          statement={question.statement}
          examples={question.examples}
          constraints={question.constraints}
        />
      </div>
      {/* Footer (Optional) */}
      <div className="my-2 text-center">
        <p className="text-sm text-gray-500 dark:text-gray-400">
          Time Complexity: {question.timeComplexity} • Space Complexity: {question.spaceComplexity}
        </p>
      </div>
    </div>
  );
}