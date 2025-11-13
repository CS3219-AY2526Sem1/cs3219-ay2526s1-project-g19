import { BookOpen, Lightbulb, Shield } from 'lucide-react';

const QuestionDescription = ({ statement, examples, constraints }) => (
  <section className="group p-8">
    {/* Problem Statement */}
    <div className="flex items-center gap-3 mb-4">
      <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary to-indigo-600 flex items-center justify-center">
        <BookOpen className="w-4 h-4 text-white" />
      </div>
      <h2 className="font-bold text-lg text-gray-300">
        Problem Statement
      </h2>
    </div>
    <div className="pl-11 mb-8">
      <p className="text-gray-400 leading-relaxed text-base">
        {statement}
      </p>
    </div>

    {/* Example(s) */}
    <div className="flex items-center gap-3 mb-4">
      <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-amber-700 to-orange-600 flex items-center justify-center">
        <Lightbulb className="w-4 h-4 text-white" />
      </div>
      <h2 className="font-bold text-lg text-gray-300">
        {examples.length > 1 ? 'Examples' : 'Example'}
      </h2>
    </div>
    <div className="pl-11 mb-8">
      {examples.map((ex, i) => (
        <div key={i} className="bg-gradient-to-br from-background to-background-secondary p-6 rounded-2xl border border-gray-700 shadow-sm mb-4">
          {examples.length > 1 && (
            <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-3 uppercase tracking-wide">
              Example {i + 1}
            </div>
          )}
          <div className="font-mono text-sm space-y-3">
            <div>
              <span className="text-gray-100 text-xs font-semibold uppercase tracking-wide">
                Input
              </span>
              <p className="text-gray-300">{ex.input}</p>
            </div>
            <div>
              <span className="text-gray-100 text-xs font-semibold uppercase tracking-wide">
                Output
              </span>
              <p className="text-emerald-400 font-semibold">{ex.output}</p>
            </div>
            {ex.explanation && (
              <div className="pt-2 border-t border-gray-600">
                <span className="text-gray-300 text-xs font-semibold uppercase tracking-wide">
                  Explanation
                </span>
                <p className="text-gray-300">{ex.explanation}</p>
              </div>
            )}
          </div>
        </div>
      ))}
    </div>

    {/* Constraints */}
    <div className="flex items-center gap-3 mb-4">
      <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-rose-500 to-pink-600 flex items-center justify-center">
        <Shield className="w-4 h-4 text-white" />
      </div>
      <h2 className="font-bold text-lg text-gray-100">
        Constraints
      </h2>
    </div>
    <div className="pl-11">
      <div className="space-y-3">
        {constraints.map((constraint, i) => (
          <div key={i} className="flex items-start gap-3 group/item">
            <div className="w-1.5 h-1.5 rounded-full bg-gradient-to-r from-primary to-primary-light mt-2 flex-shrink-0"></div>
            <p className="text-gray-300 font-mono text-sm leading-relaxed">
              {constraint}
            </p>
          </div>
        ))}
      </div>
    </div>
  </section>
);

export default QuestionDescription;