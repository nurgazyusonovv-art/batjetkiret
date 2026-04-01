import { useEffect, useState } from 'react';
import { Package, Clock, CheckCircle, XCircle, TrendingUp, Smartphone, Store, Tag, RefreshCw, X, ChevronRight } from 'lucide-react';
import { ordersService, EnterpriseOrder, EnterpriseStats } from '../services/orders';
import { authService } from '../services/auth';
import './DashboardPage.css';

const STATUS_LABELS: Record<string, string> = {
  WAITING_COURIER: 'Жаңы',
  ACCEPTED: 'Кабыл алынды — ишкана',
  PREPARING: 'Даярдалып жатат',
  READY: 'Даяр — Курьер күтүүдө',
  PICKED_UP: 'Кабыл алынды — Курьер',
  IN_TRANSIT: 'Жеткирүүнү баштады',
  ON_THE_WAY: 'Жеткирүүнү баштады',
  DELIVERED: 'Жеткирилди',
  COMPLETED: 'Аяктады',
  CANCELLED: 'Жокко чыгарылды',
};

const STATUS_COLOR: Record<string, string> = {
  WAITING_COURIER: '#d97706',
  ACCEPTED: '#2563eb',
  PREPARING: '#9333ea',
  READY: '#059669',
  PICKED_UP: '#0891b2',
  IN_TRANSIT: '#7c3aed',
  ON_THE_WAY: '#7c3aed',
  DELIVERED: '#059669',
  COMPLETED: '#059669',
  CANCELLED: '#dc2626',
};

// Next status actions enterprise can take
function getStatusActions(status: string): { value: string; label: string; danger?: boolean }[] {
  switch (status) {
    case 'WAITING_COURIER':
      return [
        { value: 'ACCEPTED', label: 'Кабыл алуу' },
        { value: 'CANCELLED', label: 'Жокко чыгаруу', danger: true },
      ];
    case 'ACCEPTED':
      return [
        { value: 'PREPARING', label: 'Даярдоону баштоо' },
        { value: 'CANCELLED', label: 'Жокко чыгаруу', danger: true },
      ];
    case 'PREPARING':
      return [
        { value: 'READY', label: 'Даяр — Курьер чакыруу' },
        { value: 'CANCELLED', label: 'Жокко чыгаруу', danger: true },
      ];
    default:
      return [];
  }
}

function ActiveOrderCard({ order, onClick }: { order: EnterpriseOrder; onClick: () => void }) {
  const color = STATUS_COLOR[order.status] ?? '#6b7280';
  const statusLabel = STATUS_LABELS[order.status] ?? order.status;
  return (
    <button className="active-order-card" onClick={onClick}>
      <div className="aoc-top">
        <span className="aoc-id">#{order.id}</span>
        <span className="aoc-status" style={{ color }}>{statusLabel}</span>
        <span className={`aoc-source ${order.source}`}>{order.source === 'local' ? '🏪 Жергиликтүү' : '📱 Онлайн'}</span>
      </div>
      <div className="aoc-address">{order.to_address}</div>
      <div className="aoc-bottom">
        <span>{order.user_phone}</span>
        <span className="aoc-price">{order.items_total != null ? `${Number(order.items_total).toFixed(0)} сом` : '—'}</span>
      </div>
    </button>
  );
}

interface OrderPopupProps {
  order: EnterpriseOrder;
  onClose: () => void;
  onStatusChange: (orderId: number, status: string) => Promise<void>;
  updating: boolean;
}

function OrderPopup({ order, onClose, onStatusChange, updating }: OrderPopupProps) {
  const color = STATUS_COLOR[order.status] ?? '#6b7280';
  const statusLabel = STATUS_LABELS[order.status] ?? order.status;
  const actions = getStatusActions(order.status);

  return (
    <div className="aop-overlay" onClick={onClose}>
      <div className="aop-popup" onClick={(e) => e.stopPropagation()}>
        <div className="aop-header">
          <div className="aop-title">
            <span className="aop-order-id">Заказ #{order.id}</span>
            <span className="aop-status-badge" style={{ color, background: color + '18' }}>{statusLabel}</span>
          </div>
          <button className="aop-close" onClick={onClose}><X size={18} /></button>
        </div>

        <div className="aop-body">
          <div className="aop-info-row"><span className="aop-lbl">Кардар</span><span>{order.user_phone}</span></div>
          <div className="aop-info-row"><span className="aop-lbl">Дарек</span><span>{order.to_address}</span></div>
          {order.courier_name && (
            <div className="aop-info-row"><span className="aop-lbl">Курьер</span><span>{order.courier_name} · {order.courier_phone}</span></div>
          )}
          <div className="aop-info-row">
            <span className="aop-lbl">Сумма</span>
            <span className="aop-price">{order.items_total != null ? `${Number(order.items_total).toFixed(0)} сом` : '—'}</span>
          </div>
          {order.description && (
            <div className="aop-info-row"><span className="aop-lbl">Эскертүү</span><span>{order.description}</span></div>
          )}
        </div>

        {actions.length > 0 && (
          <div className="aop-actions">
            <div className="aop-actions-label">Статусту өзгөртүү</div>
            {actions.map((a) => (
              <button
                key={a.value}
                className={`aop-action-btn ${a.danger ? 'danger' : 'primary'}`}
                disabled={updating}
                onClick={() => onStatusChange(order.id, a.value)}
              >
                {updating ? 'Жүктөлүүдө...' : (
                  <><span>{a.label}</span><ChevronRight size={15} /></>
                )}
              </button>
            ))}
          </div>
        )}
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
  const [selectedOrder, setSelectedOrder] = useState<EnterpriseOrder | null>(null);
  const [updating, setUpdating] = useState(false);
  const info = authService.getInfo();

  const load = () => {
    setLoading(true);
    ordersService.getStats()
      .then(setStats)
      .catch(console.error)
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleStatusChange = async (orderId: number, newStatus: string) => {
    setUpdating(true);
    try {
      await ordersService.updateStatus(orderId, newStatus);
      setSelectedOrder(null);
      load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      alert(err?.response?.data?.detail ?? 'Ката кетти');
    } finally {
      setUpdating(false);
    }
  };

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
                  <span className="dsc-num">{stats.online_revenue > 0 ? stats.online_revenue.toFixed(0) : '—'}</span>
                  <span className="dsc-lbl">Сом</span>
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
              <div className="dash-section-label">
                Активдүү заказдар
                <span className="dash-badge">{stats.active_orders_list.length}</span>
              </div>
              <div className="active-orders-grid">
                {stats.active_orders_list.map((o: EnterpriseOrder) => (
                  <ActiveOrderCard key={o.id} order={o} onClick={() => setSelectedOrder(o)} />
                ))}
              </div>
            </>
          )}
        </>
      )}

      {selectedOrder && (
        <OrderPopup
          order={selectedOrder}
          onClose={() => setSelectedOrder(null)}
          onStatusChange={handleStatusChange}
          updating={updating}
        />
      )}
    </div>
  );
}
