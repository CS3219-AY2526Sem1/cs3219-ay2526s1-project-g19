import { CheckCircle, Code2 } from 'lucide-react';

const QuestionHeader = ({ title, difficulty, topics }) => (
  <div className="relative bg-gradient-to-r from-emerald-500 via-teal-500 to-cyan-500 px-8 py-6">
    <div className="absolute inset-0 bg-black/5"></div>
    <div className="relative">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl bg-white/20 backdrop-blur-sm flex items-center justify-center">
          <Code2 className="w-5 h-5 text-white" />
        </div>
        <h1 className="text-2xl font-bold text-white">{title}</h1>
      </div>
      <div className="flex flex-wrap gap-2">
        <span className="px-3 py-1.5 rounded-full bg-white/90 text-emerald-700 text-xs font-semibold shadow-sm flex items-center gap-1">
          <CheckCircle className="w-3 h-3" />
          {difficulty}
        </span>
        {topics.map((topic, idx) => (
          <span key={idx} className="px-3 py-1.5 rounded-full bg-white/20 backdrop-blur-sm text-white text-xs font-medium border border-white/30">
            {topic}
          </span>
        ))}
      </div>
    </div>
  </div>
);

export default QuestionHeader;