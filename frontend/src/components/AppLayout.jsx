import { Outlet } from 'react-router-dom';

const AppLayout = () => {
  return (
    <div className="min-h-screen bg-gray-50 font-inter">
      <main>
        <Outlet /> 
      </main>
    </div>
  );
};

export default AppLayout;
