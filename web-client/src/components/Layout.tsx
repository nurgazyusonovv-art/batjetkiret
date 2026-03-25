import { ReactNode, useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { authService } from '../services/auth';
import api from '../services/api';
import './Layout.css';

interface Props { children: ReactNode; }

export default function Layout({ children }: Props) {
  const navigate = useNavigate();
  const user = authService.getCachedUser();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [unreadNotifs, setUnreadNotifs] = useState(0);

  useEffect(() => {
    api.get('/notifications/unread-count')
      .then(r => setUnreadNotifs(r.data.unread || 0))
      .catch(() => {});

    const interval = setInterval(() => {
      api.get('/notifications/unread-count')
        .then(r => setUnreadNotifs(r.data.unread || 0))
        .catch(() => {});
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  function handleLogout() {
    authService.logout();
    navigate('/login');
  }

  const navItems = [
    { to: '/', label: 'Башкы бет', icon: '🏠', end: true, badge: 0 },
    { to: '/orders', label: 'Заказдар', icon: '📦', badge: 0 },
    { to: '/notifications', label: 'Билдирүүлөр', icon: '🔔', badge: unreadNotifs },
    { to: '/profile', label: 'Профиль', icon: '👤', badge: 0 },
  ];

  return (
    <div className="layout">
      {/* Mobile header */}
      <header className="mobile-header">
        <button className="burger" onClick={() => setSidebarOpen(true)}>☰</button>
        <span className="mobile-title">Batken Express</span>
        <div className="mobile-balance">
          {user ? `${user.balance.toFixed(0)} с` : ''}
        </div>
      </header>

      {/* Sidebar overlay */}
      {sidebarOpen && <div className="sidebar-overlay" onClick={() => setSidebarOpen(false)} />}

      {/* Sidebar */}
      <aside className={`sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="sidebar-header">
          <div className="sidebar-logo">🚀 Batken Express</div>
          <button className="sidebar-close" onClick={() => setSidebarOpen(false)}>✕</button>
        </div>

        {user && (
          <div className="sidebar-user">
            <div className="user-avatar">{user.name.charAt(0).toUpperCase()}</div>
            <div>
              <div className="user-name">{user.name}</div>
              <div className="user-balance">{user.balance.toFixed(2)} сом</div>
            </div>
          </div>
        )}

        <nav className="sidebar-nav">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
              onClick={() => setSidebarOpen(false)}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
              {item.badge > 0 && <span className="nav-badge">{item.badge}</span>}
            </NavLink>
          ))}
        </nav>

        <button className="sidebar-logout" onClick={handleLogout}>
          🚪 Чыгуу
        </button>
      </aside>

      {/* Main content */}
      <main className="main-content">
        {children}
      </main>

      {/* Bottom nav (mobile) */}
      <nav className="bottom-nav">
        {navItems.map(item => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => `bottom-nav-item ${isActive ? 'active' : ''}`}
          >
            <span style={{ position: 'relative', display: 'inline-block' }}>
              {item.icon}
              {item.badge > 0 && (
                <span className="bottom-nav-badge">{item.badge}</span>
              )}
            </span>
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
