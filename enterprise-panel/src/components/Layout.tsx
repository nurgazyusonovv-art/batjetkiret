import { ReactNode, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Package, LogOut, Building2, ShoppingCart,
  UtensilsCrossed, History, BarChart2, CreditCard, Settings,
  ChevronLeft, ChevronRight, Menu, X,
} from 'lucide-react';
import { authService } from '../services/auth';
import './Layout.css';

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

export default function Layout({ children }: { children: ReactNode }) {
  const location = useLocation();
  const navigate = useNavigate();
  const info = authService.getInfo();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleLogout = () => { authService.logout(); navigate('/login'); };

  const SidebarContent = ({ mini }: { mini?: boolean }) => (
    <>
      <div className={`ep-sidebar-header ${mini ? 'mini' : ''}`}>
        <Building2 size={22} color="#4f46e5" className="ep-logo-icon" />
        {!mini && (
          <div className="ep-sidebar-info">
            <h2>{info?.enterprise_name ?? 'Ишкана'}</h2>
            <p>{info?.category ?? ''}</p>
          </div>
        )}
      </div>

      <nav className="ep-nav">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = location.pathname === item.path;
          return (
            <Link
              key={item.path}
              to={item.path}
              className={`ep-nav-item ${active ? 'active' : ''} ${mini ? 'mini' : ''}`}
              title={mini ? item.label : undefined}
              onClick={() => setMobileOpen(false)}
            >
              <Icon size={20} />
              {!mini && <span>{item.label}</span>}
            </Link>
          );
        })}
      </nav>

      <div className={`ep-sidebar-footer ${mini ? 'mini' : ''}`}>
        {!mini && (
          <div className="ep-user-info">
            <div className="ep-avatar">{info?.phone?.[0] ?? 'E'}</div>
            <span className="ep-phone">{info?.phone}</span>
          </div>
        )}
        {mini ? (
          <button onClick={handleLogout} className="ep-logout-btn mini" title="Чыгуу">
            <LogOut size={18} />
          </button>
        ) : (
          <button onClick={handleLogout} className="ep-logout-btn">
            <LogOut size={16} />
            <span>Чыгуу</span>
          </button>
        )}
      </div>
    </>
  );

  return (
    <div className={`ep-layout ${collapsed ? 'sidebar-collapsed' : ''}`}>

      {/* ── Desktop / Tablet sidebar ── */}
      <aside className={`ep-sidebar ${collapsed ? 'collapsed' : ''}`}>
        <button
          className="ep-collapse-btn"
          onClick={() => setCollapsed(!collapsed)}
          title={collapsed ? 'Кеңейтүү' : 'Кичирейтүү'}
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
        <SidebarContent mini={collapsed} />
      </aside>

      {/* ── Mobile top bar ── */}
      <header className="ep-mobile-header">
        <button className="ep-mobile-menu-btn" onClick={() => setMobileOpen(true)}>
          <Menu size={22} />
        </button>
        <div className="ep-mobile-title">
          <Building2 size={18} color="#4f46e5" />
          <span>{info?.enterprise_name ?? 'Ишкана'}</span>
        </div>
      </header>

      {/* ── Mobile drawer ── */}
      {mobileOpen && (
        <div className="ep-mobile-overlay" onClick={() => setMobileOpen(false)}>
          <aside className="ep-mobile-drawer" onClick={(e) => e.stopPropagation()}>
            <button className="ep-drawer-close" onClick={() => setMobileOpen(false)}>
              <X size={20} />
            </button>
            <SidebarContent mini={false} />
          </aside>
        </div>
      )}

      <main className="ep-main">{children}</main>

      {/* ── Mobile bottom navigation ── */}
      <nav className="ep-bottom-nav">
        {navItems.slice(0, 5).map((item) => {
          const Icon = item.icon;
          const active = location.pathname === item.path;
          return (
            <Link
              key={item.path}
              to={item.path}
              className={`ep-bottom-item ${active ? 'active' : ''}`}
            >
              <Icon size={20} />
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
