import LoginForm from "../components/userService/loginForm";

const LoginPage = () => {
    return (
        <div className="flex w-full h-screen">
            <div className="flex items-center justify-center w-full">
                <LoginForm />
            </div>
        </div>
    );
}

export default LoginPage;