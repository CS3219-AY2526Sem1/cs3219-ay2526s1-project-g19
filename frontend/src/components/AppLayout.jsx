import { Outlet } from 'react-router-dom';
import NavBar from './common/NavBar';

const AppLayout = () => {
  return (
    <div className="w-screen min-h-screen bg-background font-inter">
      <NavBar />
      <main className="w-full">
        <Outlet /> 
      </main>
    </div>
  );
};

export default AppLayout;
