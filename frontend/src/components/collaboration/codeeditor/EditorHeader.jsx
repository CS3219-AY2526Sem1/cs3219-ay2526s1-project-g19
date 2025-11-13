const EditorHeader = ({ language }) => (
  <div className="bg-gradient-to-r from-slate-800 to-slate-700 px-4 py-2 flex items-center justify-between border-b border-slate-600">
    <div className="flex items-center gap-2">
      <div className="flex gap-1.5">
        <div className="w-3 h-3 rounded-full bg-red-500"></div>
        <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
        <div className="w-3 h-3 rounded-full bg-green-500"></div>
      </div>
      <span className="ml-2 text-slate-300 text-sm font-medium">Editor</span>
    </div>

    <div className="flex items-center gap-2">
      <span className="text-sm text-slate-400">Language:</span>
      <span className="text-sm font-medium text-slate-200 capitalize px-2 py-1 bg-slate-700 rounded">
        {language}
      </span>
    </div>
  </div>
);

export default EditorHeader;