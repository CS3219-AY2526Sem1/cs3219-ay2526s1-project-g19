import { Terminal } from "lucide-react";

const EditorOutputTerminal = ({ output }) => (
  <div className="rounded-xl shadow-2xl border border-slate-700 bg-slate-900">
    <div className="bg-gradient-to-r from-slate-800 to-slate-700 px-4 py-2 flex items-center gap-2 border-b border-slate-600 rounded-t-xl">
      <Terminal className="w-4 h-4 text-emerald-400" />
      <span className="text-slate-300 text-sm font-semibold">Output</span>
    </div>
    <div className="p-4 font-mono text-sm text-slate-100 whitespace-pre-wrap max-h-60 overflow-y-auto">
      {output}
    </div>
  </div>
);

export default EditorOutputTerminal;