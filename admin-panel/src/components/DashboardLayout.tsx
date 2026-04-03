import { ReactNode, useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Package,
  Users,
  Wallet,
  LogOut,
  BarChart3,
  Bell,
  Building2,
  MessageSquare,
  MapPin,
  Settings,
  AlertTriangle,
  Info,
  Image,
} from 'lucide-react';
import api from '@/services/api';
import { authService } from '@/services/auth';
import { notificationsService } from '@/services/notifications';
import { cancelRequestsService } from '@/services/cancelRequests';
import './DashboardLayout.css';

interface DashboardLayoutProps {
  children: ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const user = authService.getStoredUser();
  const [unreadCount, setUnreadCount] = useState(0);
  const [unreadSupportCount, setUnreadSupportCount] = useState(0);
  const [cancelRequestCount, setCancelRequestCount] = useState(0);

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

  useEffect(() => {
    const checkSupportUnread = async () => {
      try {
        const res = await api.get<{ unread_count: number }[]>('/admin/support-chats', { params: { limit: 100 } });
        const total = res.data.reduce((s, c) => s + (c.unread_count ?? 0), 0);
        setUnreadSupportCount(total);
      } catch (_) {}
    };
    checkSupportUnread();
    const interval = setInterval(checkSupportUnread, 15000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const checkCancelRequests = async () => {
      try {
        const count = await cancelRequestsService.count();
        setCancelRequestCount(count);
      } catch (_) {}
    };
    checkCancelRequests();
    const interval = setInterval(checkCancelRequests, 20000);
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
    { path: '/enterprises', icon: Building2, label: 'Ишканалар' },
    { path: '/support-chats', icon: MessageSquare, label: 'Колдоо чаттары', badge: unreadSupportCount },
    { path: '/intercity', icon: MapPin, label: 'Шаарлар аралык' },
    { path: '/cancel-requests', icon: AlertTriangle, label: 'Отмена суроолору', badge: cancelRequestCount },
    { path: '/settings', icon: Settings, label: 'Жөндөөлөр' },
    { path: '/banners', icon: Image, label: 'Реклама баннерлери' },
    { path: '/about', icon: Info, label: 'Программа жөнүндө' },
  ];

  return (
    <div className="dashboard-layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <img src="/logo.png" alt="Баткен Экспресс" className="sidebar-logo" />
          <p>Админ панель</p>
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
