
const MATCHING_STATUS = {
    CONFIRM_CANCEL: 'confirm_cancel',
    CONFIRM_LEAVE: 'confirm_leave',
};

const CancelConfirmation = ({ actionType, onConfirm, onCancel }) => {
    const isLeave = actionType === MATCHING_STATUS.CONFIRM_LEAVE;
    const title = isLeave ? "Leave Match?" : "Cancel Matching?";
    const message = isLeave 
        ? (
            <>
                Are you sure you want to leave the found match?
                <br />
                This will end your current session.
            </>
        )
        : (
            <>
                Are you sure you want to cancel the matching process?
                <br />
                You will need to start over to find a new match.
            </>
        );
    const confirmText = isLeave ? "Leave Match" : "Cancel Matching";

    return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75">
        <div className = "rounded-lg shadow-lg p-8 max-w-xl w-full relative bg-background-secondary border border-gray-700">
            <div className="text-center">
                <h3 className="text-gray-200 font-bold text-2xl mb-2">{title}</h3>
                <p className="text-gray-400 p-2 mb-6">{message}</p>

                <div className="flex justify-center gap-4">
                    <button
                        onClick={onCancel}
                        className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 text-gray-300 hover:bg-primary-dark">
                        No, Stay
                    </button>
                    <button
                        onClick={onConfirm}
                        className="w-1/2 text-lg font-bold py-3 rounded-lg border-2 bg-red-500 hover:bg-red-600">
                        {confirmText}
                    </button>
                </div>
            </div>
        </div>
    </div>
    )
}

export default CancelConfirmation;