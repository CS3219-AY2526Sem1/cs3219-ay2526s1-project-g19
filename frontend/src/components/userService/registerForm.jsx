import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Eye, EyeOff, MessageSquareWarning } from "lucide-react";
import { userService } from "../../api/services/userService";
import SuccessMessage from "../common/SuccessMessage";
import PeerPrepLogo from "../../assets/PeerPrepLogoLight.png";

// Validation functions for each field
const validateUsername = (value, errors) => {
    const regex = /^[a-zA-Z0-9 _-]{2,50}$/;

    if (value.length === 0) {
        errors.push("Username is required.");
        return errors;
    }
    
    if (value.length < 2 || value.length > 50) {
        errors.push("Username must be between 2 and 50 characters.");
    } else if (!regex.test(value)) {
        errors.push("Username can only contain letters, numbers, spaces, underscores, and hyphens.");
    }

    return errors;
};

const validateEmail = (value, errors) => {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (value.length === 0) {
        errors.push("Email is required.");
        return errors;
    }

    if (!regex.test(value)) {
        errors.push("Invalid email format.");
    }

    return errors;
};

// Specify password rules that must be met
const validatePassword = (value, errors) => {
    if (value.length === 0) {
        errors.push("Password is required.");
        return errors;
    }

    const allowedCharsRegex = /^[A-Za-z0-9!@#$%^&*(),.?":{}|<>_-]+$/;

    if (!allowedCharsRegex.test(value)) {
        errors.push("Password contains illegal characters. Only letters, numbers, and standard special symbols are allowed.");
    }
    
    if (value.length < 8) {
        errors.push("Password must be at least 8 characters long.");
    }
    if (!/[A-Z]/.test(value)) {
        errors.push("Password must contain at least one uppercase letter.");
    }
    if (!/[a-z]/.test(value)) {
        errors.push("Password must contain at least one lowercase letter.");
    }
    if (!/[0-9]/.test(value)) {
        errors.push("Password must contain at least one number.");
    }
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(value)) {
        errors.push("Password must contain at least one special character.");
    }
    
    return errors;
}

const validateConfirmPassword = (value, errors, passwordValue) => {
    if (value.length === 0) {
        errors.push("Confirm Password is required.");
        return errors;
    }

    if (value !== passwordValue) {
        errors.push("Passwords do not match.");
    }

    return errors;
};

const getValidationErrors = (name, value, passwordValue = null) => {
    const errors = [];

    if (name === "password") {
        return validatePassword(value, errors);
    } 
    
    if (name === "username") {
        return validateUsername(value, errors);
    }

    if (name === "email") {
        return validateEmail(value, errors);
    }

    if (name === "confirmPassword") {
        return validateConfirmPassword(value, errors, passwordValue);
    }
    
    return errors;
}

const RegisterForm = () => {
    const navigate = useNavigate();

    const [formData, setFormData] = useState({
        username: '',
        email: '',
        password: '',
        confirmPassword: ''
    });

    const [error, setError] = useState({});
    const [isLoading, setIsLoading] = useState(false);
    const [registerError, setRegisterError] = useState("");
    const [registrationSuccess, setRegistrationSuccess] = useState(false);

    // Password visibility states
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);


    const handleInputChange = (e) => {
        const { name, value } = e.target;

        setFormData(prev => ({ ...prev, [name]: value }));

        if (name === "password" || name === "confirmPassword") {
            const currentPassword = (name === "password" ? value : formData.password);
            const currentConfirmPassword = (name === "confirmPassword" ? value : formData.confirmPassword);
            
            const confirmErrors = getValidationErrors(
                "confirmPassword", 
                currentConfirmPassword, 
                currentPassword
            );
            setError(prev => ({ ...prev, confirmPassword: confirmErrors }));

        } else {
             setError(prev => ({ ...prev, [name]: [] }));
        }
    }

    const handleBlur = (e) => {
        const { name, value } = e.target;

        if (name === "username" || name === "email" || name === "password") {
            const fieldErrors = getValidationErrors(name, value);
            setError(prev => ({ ...prev, [name]: fieldErrors }));
        }
    }

    const handleSubmit = async (e) => {
        e.preventDefault();

        const finalErrors = {};
        let isValid = true;

        Object.keys(formData).forEach(name => {
            const isConfirm = name === "confirmPassword";

            const fieldErrors = getValidationErrors(
                name,
                formData[name],
                isConfirm ? formData.password : null
            );

            finalErrors[name] = fieldErrors;

            if (fieldErrors.length > 0) {
                isValid = false;
            }
        });

        setError(finalErrors);

        if (isValid) {
            setIsLoading(true);
            setRegisterError("");

            try {
                const response = await userService.register({
                    email: formData.email,
                    password: formData.password,
                    display_name: formData.username
                });

                console.log("Registration successful:", response.data);

                // Show success message instead of immediate redirect
                setRegistrationSuccess(true);

            } catch (err) {
                console.error("Registration failed:", err);

                if (err.response?.status === 400) {
                    const errorMessage = err.response?.data?.error?.message || "Invalid input data";
                    setRegisterError(errorMessage);
                } else {
                    setRegisterError("An error occurred during registration. Please try again");
                }
            } finally {
                setIsLoading(false);
            }
        } else {
            console.log("Validation errors.");
        }
    }

    const getBorderColor = (name) => {
        const fieldErrors = error[name];

        if (!fieldErrors) return "border-gray-500";

        const hasError = Array.isArray(fieldErrors) && fieldErrors.length > 0;
        
        return hasError ? "border-red-400" : "border-gray-500";
    }

    const ErrorMessage = ({ errorsArray }) => {
        if (!errorsArray || errorsArray.length === 0) return null;
        return (
            <div className="text-red-400 text-xs mt-1 space-y-0.5">
                {errorsArray.map((err, idx) => (
                    <p key={idx}> <MessageSquareWarning className="inline w-3 h-3 mr-1"/> {err}</p>
                ))}
            </div>
        );
    }

    // Show success screen if registration was successful
    if (registrationSuccess) {
        return (
            <SuccessMessage
                title="Registration Successful!"
                message="Your account has been created successfully. You can now log in with your credentials."
                buttonText="Go to Login"
                onButtonClick={() => navigate('/login')}
            />
        );
    }

    return (
        <div className="flex flex-col items-center border border-gray-700 p-8 rounded-lg gap-3 w-150 min-w-[520px] max-w-[550px] bg-background-secondary shadow-lg">
            <img src={PeerPrepLogo} alt="PeerPrep Logo" className="w-40 rounded-lg"/>
            <h2 className="font-bold">Sign Up</h2>
            <p className="text-gray-300">Create your PeerPrep account today!</p>
            <div className="w-full">
                <form className="flex flex-col gap-4 text-gray-300" onSubmit={handleSubmit}> 

                    {/* Username Field */}
                    <div className="flex flex-col gap-1">
                        <label className="font-ubuntu text-sm font-medium">Username</label>
                        <div className={`flex items-center w-full border ${getBorderColor("username")} p-2 rounded focus-within:border-primary focus-within:border-2 h-10 bg-background-secondary`}>
                        <input 
                            type="text"
                            name="username"
                            placeholder="Your username" 
                            required
                            value={formData.username}
                            onChange={handleInputChange}
                            onBlur={handleBlur}
                            className="focus:outline-none flex-grow bg-transparent" />
                        </div>
                        <ErrorMessage errorsArray={error.username} />
                    </div>
                    
                    {/* Email Field */}
                    <div className="flex flex-col gap-1">
                        <label className="font-ubuntu text-sm font-medium">Email</label>
                        <div className={`flex items-center w-full border ${getBorderColor("email")} p-2 rounded focus-within:border-primary focus-within:border-2 h-10 bg-background-secondary`}>
                            <input 
                                type="text" 
                                name="email"
                                placeholder="your.email@example.com"
                                required
                                value={formData.email}
                                onChange={handleInputChange}
                                onBlur={handleBlur}
                                className="focus:outline-none flex-grow bg-transparent" />
                        </div>    
                        <ErrorMessage errorsArray={error.email} />
                    </div>
                    
                    {/* Password Field */}
                    <div className="flex flex-col gap-1">
                        <label className="font-ubuntu text-sm font-medium">Password</label>
                        <div className={`flex items-center w-full border ${getBorderColor("password")} p-2 rounded-lg focus-within:ring-2 focus-within:ring-primary focus-within:border-secondary transition duration-150 h-10`}>
                            <input 
                                type={showPassword ? "text" : "password"} 
                                name="password"
                                placeholder="Password" 
                                required
                                value={formData.password}
                                onChange={handleInputChange} 
                                onBlur={handleBlur}         
                                className="focus:outline-none flex-grow bg-transparent" />
                            <button
                                type="button"
                                onClick={() => setShowPassword(prev => !prev)}
                                className="focus:outline-none bg-transparent hover:bg-transparent text-gray-300 p-1 hover:text-gray-100">
                                {showPassword ? <Eye className="w-5 h-5"/> : <EyeOff className="w-5 h-5"/>}
                            </button>
                        </div>
                        
                        <ErrorMessage errorsArray={error.password} />
                    </div>
                    
                    {/* Confirm Password Field */}
                    <div className="flex flex-col gap-1">
                        <label className="font-ubuntu text-sm font-medium">Confirm Password</label>
                        <div className={`flex items-center w-full border ${getBorderColor("confirmPassword")} p-2 rounded-lg focus-within:ring-2 focus-within:ring-indigo-200 focus-within:border-indigo-500 transition duration-150 h-10`}>
                            <input 
                                type={showConfirmPassword ? "text" : "password"} 
                                name="confirmPassword"
                                placeholder="Confirm Password" 
                                required
                                value={formData.confirmPassword}
                                onChange={handleInputChange}
                                onBlur={handleBlur}
                                className="focus:outline-none flex-grow bg-transparent" />
                            <button
                                type="button"
                                onClick={() => setShowConfirmPassword(prev => !prev)}
                                className="focus:outline-none bg-transparent hover:bg-transparent text-gray-300 p-1 hover:text-gray-100">
                                {showConfirmPassword ? 
                                    <Eye className="w-5 h-5"/> : 
                                    <EyeOff className="w-5 h-5"/>}
                            </button>
                        </div>
                        
                        <ErrorMessage errorsArray={error.confirmPassword} />
                    </div>

                    {/* Registration Error Message */}
                    {registerError && (
                        <div className="text-red-500 text-sm text-center p-2 bg-red-50 rounded">
                            <MessageSquareWarning className="inline w-4 h-4 mr-1 text-red-400"/>
                            {registerError}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={isLoading}
                        className="mt-4 w-full text-white font-semibold py-2 rounded-lg transition duration-200 shadow-md">
                        {isLoading ? "Creating Account..." : "Sign Up"}
                    </button>
                </form>
            </div>
            
            <div className="flex flex-col items-center gap-2 text-sm mt-4">
                <p className="text-gray-300">Already have an account? 
                    <a href="/login" className="font-medium ml-1">
                        Log in
                    </a>
                </p>
            </div>
        </div>
    )
}

export default RegisterForm;
