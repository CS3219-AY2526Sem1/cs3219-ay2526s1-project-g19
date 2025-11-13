import { UserX } from "lucide-react";

const PartnerLeftModal = ({ partnerName, onStay, onLeave }) => {
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75">
            <div className="rounded-lg shadow-lg p-8 max-w-xl w-full relative bg-background-secondary border border-gray-700">
                <div className="text-center">
                    <div className="flex justify-center mb-4">
                        <div className="w-16 h-16 rounded-full bg-red-500/20 flex items-center justify-center">
                            <UserX className="w-8 h-8 text-red-500" />
                        </div>
                    </div>
                    
                    <h3 className="text-gray-200 font-bold text-2xl mb-2">Partner Left</h3>
                    <p className="text-gray-400 p-2 mb-6">
                        <span className="text-primary font-semibold">{partnerName}</span> has left the collaboration room.
                        <br />
                        You can stay to review the code or leave to find a new match.
                    </p>

                    <div className="flex justify-center gap-4">
                        <button
                            onClick={onStay}
                            className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 text-gray-300 hover:bg-primary-dark">
                            Stay
                        </button>
                        <button
                            onClick={onLeave}
                            className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 bg-red-500 hover:bg-red-600">
                            Leave Room
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default PartnerLeftModal;
