import { useState, useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Eye, EyeOff, MessageSquareWarning, Mail} from "lucide-react";
import { userService } from "../../api/services/userService";
import { useAuth } from "../../contexts/AuthContext";
import PeerPrepLogo from "../../assets/PeerPrepLogoLight.png";

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

const validatePassword = (value, errors) => {
    const regex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])([A-Za-z\d!@#$%^&*(),.?":{}|<>]){8,}$/;

    if (value.length === 0) {
        errors.push("Password is required.");
        return errors;
    }

    if (regex.test(value) === false) {
        errors.push("Password format is invalid.");
    }

    return errors;
}

const ErrorMessage = ({ errorsArray }) => {
    if (!errorsArray || errorsArray.length === 0) return null;
    return (
        <div className="!text-red-400 text-xs mt-1 space-y-0.5">
            {errorsArray.map((err, idx) => (
                <p key={idx}> <MessageSquareWarning className="inline w-3 h-3 mr-1 text-red-400"/> {err}</p>
            ))}
        </div>
    );
}

const LoginForm = () => {
    const navigate = useNavigate();
    const { login } = useAuth();
    const [searchParams, setSearchParams] = useSearchParams();

    const [formData, setFormData] = useState({
        email: "",
        password: ""
    });

    const [error, setError] = useState({
        email: [],
        password: []
    });

    const [showPassword, setShowPassword] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [loginError, setLoginError] = useState("");
    const [ssoLoading, setSsoLoading] = useState(false);
    const [ssoMessage, setSsoMessage] = useState("");
    const [showVerificationModal, setShowVerificationModal] = useState(false);

    // Check for verification success on component mount
    useEffect(() => {
        if (searchParams.get('verified') === 'true') {
            setShowVerificationModal(true);
            // Remove the query parameter from URL
            searchParams.delete('verified');
            setSearchParams(searchParams, { replace: true });
        }
    }, [searchParams, setSearchParams]);
    
    const togglePasswordVisibility = () => {
        setShowPassword(!showPassword);
    };

    const inputType = showPassword ? "text" : "password";

    const handleInputChange = (e) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
        
        setError(prev => ({ ...prev, [name]: [] }));
    }
    
    const handleBlur = (e) => {
        const { name, value } = e.target;
        
        const fieldErrors = getValidationErrors(name, value);
        setError(prev => ({ ...prev, [name]: fieldErrors }));
    }

    const handleSubmit = async (e) => {
        e.preventDefault();

        const finalErrors = {};
        let isValid = true;

        Object.keys(formData).forEach(name => {
            const fieldErrors = getValidationErrors(name, formData[name]);

            finalErrors[name] = fieldErrors;

            if (fieldErrors.length > 0) {
                isValid = false;
            }
        });

        setError(finalErrors);

        if (isValid) {
            setIsLoading(true);
            setLoginError("");

            try {
                const response = await userService.login({
                    email: formData.email,
                    password: formData.password
                });
                console.log(response)

                // Data is already unwrapped by the interceptor
                const { user, tokens, session_profile } = response.data;

                // Update auth context (this will also store in localStorage)
                login(user, tokens);

                console.log("Login successful:", { user, tokens, session_profile });

                // Navigate to home page
                navigate('/home');

            } catch (err) {
                console.error("Login failed:", err);

                if (err.response?.status === 401) {
                    setLoginError("Invalid email or password");
                } else if (err.response?.status === 403) {
                    setLoginError("Account is disabled");
                } else if (err.response?.status === 429) {
                    setLoginError("Too many failed login attempts. Please try again later");
                } else if (err.response?.status === 400) {
                    setLoginError("Invalid input data");
                } else {
                    setLoginError("An error occurred. Please try again");
                }
            } finally {
                setIsLoading(false);
            }
        } else {
            console.log("Validation errors.");
        }
    }

    const getValidationErrors = (name, value) => {
        const errors = [];
        if (name === "email") {
            return validateEmail(value, errors);
        }
        if (name === "password") {
            return validatePassword(value, errors);
        }
        return errors;
    }

    const getBorderColor = (name) => {
        const fieldErrors = error[name];

        if (!fieldErrors) return "border-gray-500";

        const hasError = Array.isArray(fieldErrors) && fieldErrors.length > 0;

        return hasError ? "border-red-400" : "border-gray-500";
    }

    const handleEmailSSO = async () => {
        // Validate email first
        const emailErrors = validateEmail(formData.email, []);

        if (emailErrors.length > 0) {
            setError(prev => ({ ...prev, email: emailErrors }));
            return;
        }

        setSsoLoading(true);
        setSsoMessage("");
        setLoginError("");

        try {
            const response = await userService.requestEmailSSO({
                email: formData.email,
                redirect_path: '/home'
            });

            const { account_exists, delivered } = response.data;

            if (account_exists && delivered) {
                setSsoMessage("✓ Sign-in link sent! Check your email.");
            } else if (!account_exists) {
                setSsoMessage("✗ No account found with this email.");
            } else {
                setSsoMessage("✗ Failed to send email. Please try again.");
            }

        } catch (err) {
            console.error("Email SSO request failed:", err);
            setSsoMessage("✗ Failed to send sign-in link. Please try again.");
        } finally {
            setSsoLoading(false);
        }
    }

    return (
        <>
            {/* Verification Success Modal */}
            {showVerificationModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center">
                    {/* Backdrop with blur */}
                    <div
                        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
                        onClick={() => setShowVerificationModal(false)}
                    ></div>

                    {/* Modal Content */}
                    <div className="relative z-10 bg-background-secondary border border-green-500 rounded-lg p-8 max-w-md mx-4 shadow-2xl">
                        <div className="flex flex-col items-center gap-4">
                            <div className="w-16 h-16 rounded-full bg-green-500/20 flex items-center justify-center">
                                <svg className="w-8 h-8 text-green-500" fill="none" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" viewBox="0 0 24 24" stroke="currentColor">
                                    <path d="M5 13l4 4L19 7"></path>
                                </svg>
                            </div>
                            <h3 className="text-xl font-bold text-green-400">Email Verified!</h3>
                            <p className="text-gray-300 text-center">
                                Your email has been successfully verified. You can now sign in to your account.
                            </p>
                            <button
                                onClick={() => setShowVerificationModal(false)}
                                className="mt-4 px-6 py-2 bg-green-500 hover:bg-green-600 text-white rounded transition-colors"
                            >
                                Continue to Sign In
                            </button>
                        </div>
                    </div>
                </div>
            )}

            <div className="flex flex-col items-center border border-gray-700 p-8 rounded-lg gap-5 w-150 min-w-[300px] max-w-[500px] bg-background-secondary shadow-lg">
                <img src={PeerPrepLogo} alt="Peerprep Logo" className="w-40"/>
                <h2 className="font-bold">Welcome Back</h2>
                <p className="text-gray-300">Sign in to continue your peer collaboration journey</p>
            <div className="w-full">
                <form className="flex flex-col gap-4 text-gray-300" onSubmit={handleSubmit}>

                    {/* Email Field */}
                    <div className="flex flex-col gap-1">
                        <label className="font-ubuntu">Email</label>
                        <div className={`flex items-center w-full border ${getBorderColor("email")} p-2 rounded focus-within:border-primary focus-within:border-2 h-10 bg-background-secondary`}>
                        <input 
                            type="text"
                            name="email"
                            placeholder="your.email@example.com" 
                            value={formData.email}
                            required
                            onChange={handleInputChange}
                            onBlur={handleBlur}
                            className="focus:outline-none flex-grow bg-transparent" />
                        </div>
                        <ErrorMessage errorsArray={error.email} />
                    </div>

                    {/* Password Field */}
                    <div className="flex flex-col gap-1">
                        <label className="font-ubuntu">Password</label>
                        <div className={`flex items-center w-full border ${getBorderColor("password")} p-2 rounded focus-within:border-primary focus-within:border-2 h-10 bg-background-secondary`}>
                            <input 
                                type={inputType} 
                                name="password"
                                placeholder="Password"
                                value={formData.password}
                                required
                                onChange={handleInputChange}
                                onBlur={handleBlur}
                                className="focus:outline-none flex-grow bg-transparent"/>
                            <button
                                type="button"
                                onClick={togglePasswordVisibility}
                                className="focus:outline-none bg-transparent hover:bg-transparent hover:text-gray-100 text-gray-300">
                            {showPassword?
                                <Eye className="w-5 h-5"/>
                                :
                                <EyeOff className="w-5 h-5"/>
                            }
                            </button>
                        </div>
                        <ErrorMessage errorsArray={error.password} />
                    </div>

                    {/* Login Error Message */}
                    {loginError && (
                        <div className="text-red-400 text-sm text-center p-2 bg-red-900/20 border border-red-800 rounded">
                            <MessageSquareWarning className="inline w-4 h-4 mr-1"/>
                            {loginError}
                        </div>
                    )}

                    <button 
                        type="submit" 
                        disabled={isLoading}
                        className="w-full bg-primary hover:bg-primary-dark text-white font-medium py-2 px-4 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {isLoading ? "Signing In..." : "Sign In"}
                    </button>
                </form>

                {/* Email SSO Section */}
                <div className="w-full mt-4">
                    <div className="relative">
                        <div className="absolute inset-0 flex items-center">
                            <div className="w-full border-t border-gray-600"></div>
                        </div>
                        <div className="relative flex justify-center text-sm">
                            <span className="px-2 bg-background-secondary text-gray-400">Or</span>
                        </div>
                    </div>

                    <button
                        type="button"
                        onClick={handleEmailSSO}
                        disabled={ssoLoading}
                        className="w-full mt-4 flex items-center justify-center gap-2 border border-gray-600 text-gray-300 hover:bg-gray-800 py-2 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        <Mail className="w-4 h-4"/>
                        {ssoLoading ? "Sending link..." : "Sign in with Email Link"}
                    </button>

                    {/* SSO Message */}
                    {ssoMessage && (
                        <div className={`text-sm text-center mt-2 p-2 rounded ${
                            ssoMessage.includes("✓") ? "text-green-400 bg-green-900/20" : "text-red-400 bg-red-900/20"
                        }`}>
                            {ssoMessage}
                        </div>
                    )}
                </div>
            </div>
            <div className="flex flex-col items-center gap-2 text-sm ">
                <p className="text-gray-300">Don't have an account? <a href="/register">Create one</a></p>
            </div>
        </div>
        </>
    )
}

export default LoginForm;
