import { CheckCircle } from "lucide-react";

const SuccessMessage = ({ title, message, buttonText, onButtonClick }) => {
    return (
        <div className="flex flex-col items-center border border-gray-300 p-8 rounded-lg gap-5 w-150 min-w-[520px] max-w-[550px]">
            <CheckCircle className="w-20 h-20 text-green-500" />
            <h2 className="font-bold text-2xl">{title}</h2>
            <p className="text-gray-600 text-center">
                {message}
            </p>
            {buttonText && onButtonClick && (
                <button
                    onClick={onButtonClick}
                    className="mt-4 w-full text-white font-semibold py-2 rounded-lg transition duration-200 shadow-md bg-indigo-600 hover:bg-indigo-700">
                    {buttonText}
                </button>
            )}
        </div>
    );
};

export default SuccessMessage;
