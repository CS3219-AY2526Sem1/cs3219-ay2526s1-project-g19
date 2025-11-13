import { CheckCircle, Code2, Eye, Target, Trophy, Building2 } from 'lucide-react';

const QuestionHeader = ({ title, difficulty, topics, stats, company_tags }) => (
  <div className="relative bg-gradient-to-r from-primary via-primary to-primary-dark px-8 py-6">
    <div className="absolute inset-0 bg-black/5"></div>
    <div className="relative">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl bg-white/20 backdrop-blur-sm flex items-center justify-center">
          <Code2 className="w-5 h-5 text-white" />
        </div>
        <h1 className="text-2xl font-bold text-white">{title}</h1>
      </div>
      <div className="flex flex-wrap gap-2 mb-4">
        <span className="px-3 py-1.5 rounded-full bg-green-600/90 text-white text-xs font-semibold shadow-sm flex items-center gap-1">
          <CheckCircle className="w-3 h-3" />
          {difficulty}
        </span>
        {topics.map((topic, idx) => (
          <span key={idx} className="px-3 py-1.5 rounded-full bg-white/20 backdrop-blur-sm text-white text-xs font-medium border border-white/30">
            {topic}
          </span>
        ))}
      </div>

      {/* Stats Row */}
      <div className="flex flex-wrap items-center gap-4 text-white/90 text-xs">
        {/* <div className="flex items-center gap-1">
          <Eye className="w-3 h-3" />
          <span>{stats.views.toLocaleString()} views</span>
        </div>
        <div className="flex items-center gap-1">
          <Target className="w-3 h-3" />
          <span>{stats.attempts.toLocaleString()} attempts</span>
        </div>
        <div className="flex items-center gap-1">
          <Trophy className="w-3 h-3" />
          <span>{stats.solved.toLocaleString()} solved ({stats.percentage_solved}%)</span>
        </div> */}
        <div className="flex items-center gap-1">
          <Building2 className="w-3 h-3" />
          <span>{company_tags}</span>
        </div>
      </div>
    </div>
  </div>
);

export default QuestionHeader;