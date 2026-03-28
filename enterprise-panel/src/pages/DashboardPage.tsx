import { useEffect, useState } from 'react';
import { Package, Clock, CheckCircle, XCircle, TrendingUp, Smartphone, Store, Tag, RefreshCw } from 'lucide-react';
import { ordersService, EnterpriseStats, EnterpriseOrder } from '../services/orders';
import { authService } from '../services/auth';
import './DashboardPage.css';

const STATUS_LABELS: Record<string, string> = {
  WAITING_COURIER: 'Курьер күтүүдө',
  ACCEPTED: 'Кабыл алынды',
  READY: 'Даяр',
  IN_TRANSIT: 'Жолдо',
  ON_THE_WAY: 'Жолдо',
  DELIVERED: 'Жеткирилди',
  COMPLETED: 'Аяктады',
  CANCELLED: 'Жокко чыгарылды',
};

const STATUS_COLOR: Record<string, string> = {
  WAITING_COURIER: '#d97706',
  ACCEPTED: '#2563eb',
  READY: '#059669',
  IN_TRANSIT: '#7c3aed',
  ON_THE_WAY: '#7c3aed',
  DELIVERED: '#059669',
  COMPLETED: '#059669',
  CANCELLED: '#dc2626',
};

function ActiveOrderCard({ order }: { order: EnterpriseOrder }) {
  const color = STATUS_COLOR[order.status] ?? '#6b7280';
  const statusLabel = (order.order_type === 'dine_in' && order.status === 'WAITING_COURIER')
    ? 'Даярдалууда'
    : (STATUS_LABELS[order.status] ?? order.status);
  return (
    <div className="active-order-card">
      <div className="aoc-top">
        <span className="aoc-id">#{order.id}{order.order_type === 'dine_in' && ' 🍽'}</span>
        <span className="aoc-status" style={{ color }}>{statusLabel}</span>
        <span className={`aoc-source ${order.source}`}>{order.order_type === 'dine_in' ? '🍽 Стол' : order.source === 'local' ? '🏪 Жергиликтүү' : '📱 Онлайн'}</span>
      </div>
      <div className="aoc-address">{order.to_address}</div>
      <div className="aoc-bottom">
        <span>{order.user_phone}</span>
        <span className="aoc-price">{Number(order.price).toFixed(0)} сом</span>
      </div>
    </div>
  );
}

function todayLabel() {
  return new Date().toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', weekday: 'long' });
}

export default function DashboardPage() {
  const [stats, setStats] = useState<EnterpriseStats | null>(null);
  const [loading, setLoading] = useState(true);
  const info = authService.getInfo();

  const load = () => {
    setLoading(true);
    ordersService.getStats()
      .then(setStats)
      .catch(console.error)
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  return (
    <div className="ep-dashboard">
      <div className="ep-dash-header">
        <div>
          <h1>Кош келдиңиз!</h1>
          <p>{info?.enterprise_name}</p>
        </div>
        <button className="ep-refresh-btn" onClick={load} disabled={loading}>
          <RefreshCw size={14} className={loading ? 'spin' : ''} />
          Жаңыртуу
        </button>
      </div>

      {loading && !stats ? (
        <div className="ep-loading">Жүктөлүүдө...</div>
      ) : stats && (
        <>
          {/* Main stats */}
          <div className="dash-section-label">
            Бүгүнкү статистика
            <span className="dash-date-badge">{todayLabel()}</span>
          </div>
          <div className="ep-stats-grid">
            {[
              { label: 'Бардык заказдар', value: stats.total_orders, icon: Package, color: '#4f46e5', bg: '#eef2ff' },
              { label: 'Активдүү', value: stats.active_orders, icon: Clock, color: '#d97706', bg: '#fffbeb' },
              { label: 'Аяктаган', value: stats.completed_orders, icon: CheckCircle, color: '#059669', bg: '#ecfdf5' },
              { label: 'Жокко чыгарылган', value: stats.cancelled_orders, icon: XCircle, color: '#dc2626', bg: '#fef2f2' },
              { label: 'Заказдардын суммасы', value: `${stats.total_revenue.toFixed(0)} сом`, icon: TrendingUp, color: '#7c3aed', bg: '#f5f3ff' },
              { label: 'Менюдагы товарлар', value: stats.products_count, icon: Tag, color: '#0891b2', bg: '#ecfeff' },
            ].map(card => {
              const Icon = card.icon;
              return (
                <div key={card.label} className="ep-stat-card">
                  <div className="ep-stat-icon" style={{ background: card.bg, color: card.color }}><Icon size={20} /></div>
                  <div>
                    <div className="ep-stat-value" style={{ color: card.color }}>{card.value}</div>
                    <div className="ep-stat-label">{card.label}</div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Source comparison */}
          <div className="dash-section-label">Бүгүн каналдар боюнча</div>
          <div className="dash-source-grid">
            <div className="dash-source-card online">
              <div className="dsc-header">
                <Smartphone size={20} />
                <span>Онлайн заказдар</span>
                <span className="dsc-subtitle">(мобилдик тиркеме)</span>
              </div>
              <div className="dsc-stats">
                <div className="dsc-stat">
                  <span className="dsc-num">{stats.online_orders}</span>
                  <span className="dsc-lbl">Заказ</span>
                </div>
                <div className="dsc-divider" />
                <div className="dsc-stat">
                  <span className="dsc-num">{stats.online_revenue.toFixed(0)}</span>
                  <span className="dsc-lbl">Сом (жеткирүү)</span>
                </div>
              </div>
            </div>

            <div className="dash-source-card local">
              <div className="dsc-header">
                <Store size={20} />
                <span>Жергиликтүү заказдар</span>
                <span className="dsc-subtitle">(ишкана панели)</span>
              </div>
              <div className="dsc-stats">
                <div className="dsc-stat">
                  <span className="dsc-num">{stats.local_orders}</span>
                  <span className="dsc-lbl">Заказ</span>
                </div>
                <div className="dsc-divider" />
                <div className="dsc-stat">
                  <span className="dsc-num">{stats.local_revenue.toFixed(0)}</span>
                  <span className="dsc-lbl">Сом киреше</span>
                </div>
              </div>
            </div>
          </div>

          {/* Active orders */}
          {stats.active_orders_list.length > 0 && (
            <>
              <div className="dash-section-label">Активдүү заказдар <span className="dash-badge">{stats.active_orders_list.length}</span></div>
              <div className="active-orders-grid">
                {stats.active_orders_list.map(o => <ActiveOrderCard key={o.id} order={o} />)}
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
