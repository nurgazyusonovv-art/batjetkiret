import { ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Package, LogOut, ShoppingCart,
  UtensilsCrossed, History, BarChart2, CreditCard, Settings,
  X, Info, MoreHorizontal,
} from 'lucide-react';
import { authService } from '../services/auth';
import { ordersService } from '../services/orders';
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
  { path: '/about', icon: Info, label: 'Жөнүндө' },
];

// Bottom nav: first 4 main items + "More" button
const bottomPrimary = navItems.slice(0, 4);
const bottomMore = navItems.slice(4);

export default function Layout({ children }: { children: ReactNode }) {
  const location = useLocation();
  const navigate = useNavigate();
  const info = authService.getInfo();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [newOrderCount, setNewOrderCount] = useState(0);
  const knownOrderIds = useRef<Set<number>>(new Set());
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const handleLogout = () => { authService.logout(); navigate('/login'); };

  // ── New order polling ──────────────────────────────────────────
  const requestNotifPermission = useCallback(async () => {
    if ('Notification' in window && Notification.permission === 'default') {
      await Notification.requestPermission();
    }
  }, []);

  const pollOrders = useCallback(async () => {
    try {
      const stats = await ordersService.getStats();
      const currentIds = new Set(stats.active_orders_list.map((o) => o.id));

      if (knownOrderIds.current.size === 0) {
        // First poll — seed without notifying
        currentIds.forEach((id) => knownOrderIds.current.add(id));
        return;
      }

      const newIds: number[] = [];
      currentIds.forEach((id) => {
        if (!knownOrderIds.current.has(id)) newIds.push(id);
      });

      if (newIds.length > 0) {
        newIds.forEach((id) => knownOrderIds.current.add(id));
        setNewOrderCount((c) => c + newIds.length);

        // Browser notification
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('🛎 Жаңы заказ!', {
            body: newIds.length === 1
              ? `Заказ #${newIds[0]} түштү`
              : `${newIds.length} жаңы заказ түштү`,
            icon: '/logo.png',
          });
        }
      }
    } catch {
      // silently ignore poll errors
    }
  }, []);

  useEffect(() => {
    requestNotifPermission();
    pollOrders(); // immediate first poll
    pollRef.current = setInterval(pollOrders, 30_000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [pollOrders, requestNotifPermission]);

  // Clear badge when user visits orders page
  useEffect(() => {
    if (location.pathname === '/orders' || location.pathname === '/') {
      setNewOrderCount(0);
    }
  }, [location.pathname]);

  // ── Sidebar content ────────────────────────────────────────────
  const SidebarContent = () => (
    <>
      <div className="ep-sidebar-header">
        <img src="/logo.png" alt="Баткен Экспресс" className="ep-logo-img" />
        <div className="ep-sidebar-info">
          <h2>{info?.enterprise_name ?? 'Ишкана'}</h2>
          <p>{info?.category ?? ''}</p>
        </div>
      </div>

      <nav className="ep-nav">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = location.pathname === item.path;
          const showBadge = (item.path === '/orders' || item.path === '/') && newOrderCount > 0;
          return (
            <Link
              key={item.path}
              to={item.path}
              className={`ep-nav-item ${active ? 'active' : ''}`}
              onClick={() => { setMobileOpen(false); setMoreOpen(false); }}
            >
              <span className="ep-nav-icon-wrap">
                <Icon size={20} />
                {showBadge && <span className="ep-nav-badge">{newOrderCount}</span>}
              </span>
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
    </>
  );

  return (
    <div className="ep-layout">

      {/* ── Desktop sidebar ── */}
      <aside className="ep-sidebar">
        <SidebarContent />
      </aside>

      {/* ── Mobile top bar ── */}
      <header className="ep-mobile-header">
        <div className="ep-mobile-title">
          <img src="/logo.png" alt="Баткен Экспресс" style={{ width: 28, height: 28, borderRadius: '50%', objectFit: 'contain' }} />
          <span>{info?.enterprise_name ?? 'Ишкана'}</span>
        </div>
        {newOrderCount > 0 && (
          <span className="ep-mobile-badge">{newOrderCount} жаңы</span>
        )}
      </header>

      {/* ── Mobile slide-in drawer (from bottom More button) ── */}
      {mobileOpen && (
        <div className="ep-mobile-overlay" onClick={() => setMobileOpen(false)}>
          <aside className="ep-mobile-drawer" onClick={(e) => e.stopPropagation()}>
            <button className="ep-drawer-close" onClick={() => setMobileOpen(false)}>
              <X size={20} />
            </button>
            <SidebarContent />
          </aside>
        </div>
      )}

      {/* ── More sheet (bottom sheet for extra nav items) ── */}
      {moreOpen && (
        <div className="ep-more-overlay" onClick={() => setMoreOpen(false)}>
          <div className="ep-more-sheet" onClick={(e) => e.stopPropagation()}>
            <div className="ep-more-handle" />
            {bottomMore.map((item) => {
              const Icon = item.icon;
              const active = location.pathname === item.path;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={`ep-more-item ${active ? 'active' : ''}`}
                  onClick={() => setMoreOpen(false)}
                >
                  <Icon size={22} />
                  <span>{item.label}</span>
                </Link>
              );
            })}
            <button className="ep-more-logout" onClick={handleLogout}>
              <LogOut size={20} />
              <span>Чыгуу</span>
            </button>
          </div>
        </div>
      )}

      <main className="ep-main">{children}</main>

      {/* ── Mobile bottom navigation ── */}
      <nav className="ep-bottom-nav">
        {bottomPrimary.map((item) => {
          const Icon = item.icon;
          const active = location.pathname === item.path;
          const showBadge = (item.path === '/orders' || item.path === '/') && newOrderCount > 0;
          return (
            <Link
              key={item.path}
              to={item.path}
              className={`ep-bottom-item ${active ? 'active' : ''}`}
            >
              <span className="ep-nav-icon-wrap">
                <Icon size={22} />
                {showBadge && <span className="ep-nav-badge">{newOrderCount}</span>}
              </span>
              <span>{item.label}</span>
            </Link>
          );
        })}
        <button
          className={`ep-bottom-item ${moreOpen ? 'active' : ''}`}
          onClick={() => setMoreOpen((v) => !v)}
        >
          <MoreHorizontal size={22} />
          <span>Дагы</span>
        </button>
      </nav>
    </div>
  );
}
