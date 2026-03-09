import { ReactNode, useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Package, 
  Users, 
  Wallet, 
  LogOut,
  BarChart3,
  Bell
} from 'lucide-react';
import { authService } from '@/services/auth';
import { notificationsService } from '@/services/notifications';
import './DashboardLayout.css';

interface DashboardLayoutProps {
  children: ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const user = authService.getStoredUser();
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    const checkUnread = async () => {
      try {
        const count = await notificationsService.getUnreadCount();
        setUnreadCount(count);
      } catch (e) {
        console.error('Error fetching unread count:', e);
      }
    };

    checkUnread();
    const interval = setInterval(checkUnread, 30000); // Check every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const handleLogout = () => {
    authService.logout();
    navigate('/login');
  };

  const navItems: Array<{
    path: string;
    icon: any;
    label: string;
    badge?: number;
  }> = [
    { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/orders', icon: Package, label: 'Заказдар' },
    { path: '/users', icon: Users, label: 'Колдонуучулар' },
    { path: '/topup', icon: Wallet, label: 'Топап' },
    { path: '/stats', icon: BarChart3, label: 'Статистика' },
    { path: '/notifications', icon: Bell, label: 'Билдирүүлөр', badge: unreadCount },
  ];

  return (
    <div className="dashboard-layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <h2>BATJETKIRET</h2>
          <p>Admin Panel</p>
        </div>

        <nav className="sidebar-nav">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            const badge = item.badge ?? 0;

            return (
              <Link
                key={item.path}
                to={item.path}
                className={`nav-item ${isActive ? 'active' : ''}`}
              >
                <div className="nav-item-content">
                  <Icon size={20} />
                  <span>{item.label}</span>
                </div>
                {badge > 0 && (
                  <span className="nav-badge">{badge}</span>
                )}
              </Link>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <div className="user-info">
            <div className="user-avatar">
              {user?.name?.[0] || user?.phone?.[0] || 'A'}
            </div>
            <div className="user-details">
              <p className="user-name">{user?.name || 'Admin'}</p>
              <p className="user-phone">{user?.phone}</p>
            </div>
          </div>
          <button onClick={handleLogout} className="logout-button">
            <LogOut size={18} />
            <span>Чыгуу</span>
          </button>
        </div>
      </aside>

      <main className="main-content">
        {children}
      </main>
    </div>
  );
}
