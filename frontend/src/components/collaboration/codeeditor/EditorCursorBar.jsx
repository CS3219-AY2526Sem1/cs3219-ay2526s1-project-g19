import { Users, MapPin } from "lucide-react";

const EditorCursorBar = ({ cursorPosition, remoteCursors }) => (
  <div className="bg-gradient-to-r from-slate-800 via-slate-700 to-slate-800 rounded-xl p-4 shadow-lg border border-slate-600">
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center shadow-md">
            <MapPin className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="text-white font-semibold">Your Position</div>
            <div className="text-slate-300 text-sm font-mono">
              Line {cursorPosition.line}, Col {cursorPosition.ch + 1}
            </div>
          </div>
        </div>
      </div>
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 px-3 py-2 bg-slate-900/50 rounded-lg border border-slate-600">
          <Users className="w-4 h-4 text-slate-300" />
          <span className="text-slate-200 text-sm font-medium">
            {Object.keys(remoteCursors).length + 1} Active
          </span>
        </div>
      </div>
    </div>
    {Object.keys(remoteCursors).length > 0 && (
      <div className="mt-3 pt-3 border-t border-slate-600 flex flex-wrap gap-3">
        {Object.entries(remoteCursors).map(([userId, cursor]) => (
          <div 
            key={userId}
            className="flex items-center gap-2 px-3 py-1.5 bg-slate-900/50 rounded-lg border border-slate-600"
          >
            <div 
              className="w-3 h-3 rounded-full shadow-md"
              style={{ backgroundColor: cursor.color }}
            />
            <span className="text-slate-200 text-sm font-mono">
              User {userId.slice(-4)}: L{cursor.line}:C{cursor.ch + 1}
            </span>
          </div>
        ))}
      </div>
    )}
  </div>
);

export default EditorCursorBar;