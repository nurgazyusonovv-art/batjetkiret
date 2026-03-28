import { ReactNode } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { LayoutDashboard, Package, LogOut, Building2, ShoppingCart, UtensilsCrossed, History, BarChart2, CreditCard, Settings } from 'lucide-react';
import { authService } from '../services/auth';
import './Layout.css';

export default function Layout({ children }: { children: ReactNode }) {
  const location = useLocation();
  const navigate = useNavigate();
  const info = authService.getInfo();

  const handleLogout = () => { authService.logout(); navigate('/login'); };

  const navItems = [
    { path: '/', icon: LayoutDashboard, label: 'Статистика' },
    { path: '/orders', icon: Package, label: 'Заказдар' },
    { path: '/payments', icon: CreditCard, label: 'Төлөмдөр' },
    { path: '/create-order', icon: ShoppingCart, label: 'Заказ түзүү' },
    { path: '/products', icon: UtensilsCrossed, label: 'Меню' },
    { path: '/history', icon: History, label: 'Тарых' },
    { path: '/reports', icon: BarChart2, label: 'Отчет' },
    { path: '/settings', icon: Settings, label: 'Жөндөөлөр' },
  ];

  return (
    <div className="ep-layout">
      <aside className="ep-sidebar">
        <div className="ep-sidebar-header">
          <Building2 size={22} color="#4f46e5" />
          <div>
            <h2>{info?.enterprise_name ?? 'Ишкана'}</h2>
            <p>{info?.category ?? ''}</p>
          </div>
        </div>

        <nav className="ep-nav">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = location.pathname === item.path;
            return (
              <Link key={item.path} to={item.path} className={`ep-nav-item ${active ? 'active' : ''}`}>
                <Icon size={18} />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        <div className="ep-sidebar-footer">
          <div className="ep-user-info">
            <div className="ep-avatar">{info?.phone?.[0] ?? 'E'}</div>
            <span className="ep-phone">{info?.phone}</span>
          </div>
          <button onClick={handleLogout} className="ep-logout-btn">
            <LogOut size={16} />
            <span>Чыгуу</span>
          </button>
        </div>
      </aside>
      <main className="ep-main">{children}</main>
    </div>
  );
}
