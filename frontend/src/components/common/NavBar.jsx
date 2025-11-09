import { LogOut, UserCircle2 } from "lucide-react";
import { useAuth } from "../../contexts/AuthContext";
import { useNotification } from "../../contexts/NotificationContext";
import { useNavigate } from "react-router-dom";
import PeerPrepLogo from "../../assets/PeerPrepLogoLight.png";

const Link = ({ to, children }) => {
    return (
        <a href={to} className="text-primary-light text-bold text-2xl hover:primary">
            {children}
        </a>
    ); 
};

const NavBar = () => {
    const navigate = useNavigate();

    const navPages = [
        { name: 'Home', path: '/home' },
        { name: 'Matching', path: '/matching' },
    ]

    return (
        <nav className="flex justify-between items-center bg-background shadow-md border-b border-gray-600 w-full min-w-7xl p-4">
            <div className="flex items-center space-x-2">
                <img src={PeerPrepLogo} alt="PeerPrep Logo" className="h-10 ml-4"/>
            </div>

            <div className="flex space-x-10">
                {navPages.map((page) => (
                    <Link key={page.name} to={page.path}>
                        {page.name}
                    </Link>
                ))}
            </div>

            <div className="flex items-center space-x-4">
                <button
                    onClick={() => navigate('/profile')}
                    className="bg-primary text-white hover:bg-primary-dark font-semibold py-2 px-4 rounded">
                    <UserCircle2 className="inline-block mr-2" />
                    Profile
                </button>

            </div>
        </nav>

    );
};

export default NavBar;
