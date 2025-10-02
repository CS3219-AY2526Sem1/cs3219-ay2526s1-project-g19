const EditorHeader = ({ filename }) => (
  <div className="bg-gradient-to-r from-slate-800 to-slate-700 px-4 py-2 flex items-center gap-2 border-b border-slate-600">
    <div className="flex gap-1.5">
      <div className="w-3 h-3 rounded-full bg-red-500"></div>
      <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
      <div className="w-3 h-3 rounded-full bg-green-500"></div>
    </div>
    <span className="ml-2 text-slate-300 text-sm font-medium">{filename}</span>
  </div>
);

export default EditorHeader;