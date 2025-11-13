const LeaveRoomConfirmation = ({ onConfirm, onCancel }) => {
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75">
            <div className="rounded-lg shadow-lg p-8 max-w-xl w-full relative bg-background-secondary border border-gray-700">
                <div className="text-center">
                    <h3 className="text-gray-200 font-bold text-2xl mb-2">Leave Collaboration Room?</h3>
                    <p className="text-gray-400 p-2 mb-6">
                        Are you sure you want to leave?
                        <br />
                        Your partner will be notified and can choose to stay or leave.
                    </p>

                    <div className="flex justify-center gap-4">
                        <button
                            onClick={onCancel}
                            className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 text-gray-300 hover:bg-primary-dark">
                            No, Stay
                        </button>
                        <button
                            onClick={onConfirm}
                            className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 bg-red-500 hover:bg-red-600">
                            Yes, Leave Room
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default LeaveRoomConfirmation;
