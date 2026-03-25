import { useEffect, useState, useCallback } from 'react';
import { Package, Search, X, RefreshCw, CheckCircle, XCircle, Truck } from 'lucide-react';
import { ordersService, EnterpriseOrder } from '../services/orders';
import './OrdersPage.css';

const STATUS_LABELS: Record<string, string> = {
  PREPARING: 'Даярдалууда',
  WAITING_COURIER: 'Курьер күтүүдө',
  ACCEPTED: 'Кабыл алынды',
  IN_TRANSIT: 'Жолдо',
  ON_THE_WAY: 'Жолдо',
  PICKED_UP: 'Алынды',
  DELIVERED: 'Жеткирилди',
  COMPLETED: 'Аяктады',
  CANCELLED: 'Жокко чыгарылды',
  READY: 'Даяр',
};

const STATUS_COLORS: Record<string, string> = {
  PREPARING: '#9333ea',
  WAITING_COURIER: '#d97706',
  ACCEPTED: '#2563eb',
  IN_TRANSIT: '#7c3aed',
  ON_THE_WAY: '#7c3aed',
  PICKED_UP: '#0891b2',
  DELIVERED: '#059669',
  COMPLETED: '#059669',
  CANCELLED: '#dc2626',
  READY: '#16a34a',
};

const STATUS_BG: Record<string, string> = {
  PREPARING: '#faf5ff',
  WAITING_COURIER: '#fffbeb',
  ACCEPTED: '#eff6ff',
  IN_TRANSIT: '#f5f3ff',
  ON_THE_WAY: '#f5f3ff',
  PICKED_UP: '#ecfeff',
  DELIVERED: '#ecfdf5',
  COMPLETED: '#ecfdf5',
  CANCELLED: '#fef2f2',
  READY: '#f0fdf4',
};

const FILTER_OPTIONS = [
  { value: '', label: 'Баардыгы' },
  { value: 'PREPARING', label: 'Даярдалууда' },
  { value: 'WAITING_COURIER', label: 'Курьер күтүүдө' },
  { value: 'ACCEPTED', label: 'Кабыл алынды' },
  { value: 'READY', label: 'Даяр' },
  { value: 'IN_TRANSIT', label: 'Жолдо' },
];

// Statuses shown when order is still being prepared (not yet sent to couriers)
const PREPARING_STATUSES = [
  { value: 'WAITING_COURIER', label: 'Даяр — курьер чакыруу' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

const DELIVERY_STATUSES = [
  { value: 'ACCEPTED', label: 'Кабыл алынды' },
  { value: 'READY', label: 'Даяр (курьер күтүп жатат)' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

const DINE_IN_STATUSES = [
  { value: 'READY', label: 'Даяр' },
  { value: 'COMPLETED', label: 'Жабылды' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

export default function OrdersPage() {
  const [orders, setOrders] = useState<EnterpriseOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState('');
  const [search, setSearch] = useState('');
  const [updatingId, setUpdatingId] = useState<number | null>(null);
  const [expandedId, setExpandedId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await ordersService.getOrders(filterStatus ? { status: filterStatus } : {});
      setOrders(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, [filterStatus]);

  useEffect(() => { load(); }, [load]);

  const filtered = orders.filter((o) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      String(o.id).includes(q) ||
      o.from_address.toLowerCase().includes(q) ||
      o.to_address.toLowerCase().includes(q) ||
      (o.user_phone ?? '').toLowerCase().includes(q)
    );
  });

  const handleStatusUpdate = async (orderId: number, newStatus: string) => {
    setUpdatingId(orderId);
    try {
      await ordersService.updateStatus(orderId, newStatus);
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      alert(err?.response?.data?.detail ?? 'Ката кетти');
    } finally {
      setUpdatingId(null);
    }
  };

  return (
    <div className="ep-orders">
      <div className="ep-orders-header">
        <div className="ep-orders-title">
          <Package size={22} />
          <h1>Заказдар</h1>
          <span className="ep-orders-count">{filtered.length}</span>
        </div>
        <button className="ep-refresh-btn" onClick={load} disabled={loading}>
          <RefreshCw size={15} className={loading ? 'spin' : ''} />
          Жаңыртуу
        </button>
      </div>

      <div className="ep-orders-filters">
        <div className="ep-orders-search">
          <Search size={15} />
          <input
            type="text"
            placeholder="Издөө (ID, дарек, телефон)..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="ep-search-clear" onClick={() => setSearch('')}>
              <X size={13} />
            </button>
          )}
        </div>
        <div className="ep-filter-tabs">
          {FILTER_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              className={`ep-filter-tab ${filterStatus === opt.value ? 'active' : ''}`}
              onClick={() => setFilterStatus(opt.value)}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="ep-loading">Жүктөлүүдө...</div>
      ) : filtered.length === 0 ? (
        <div className="ep-empty">
          <Package size={48} opacity={0.2} />
          <p>Заказ табылган жок</p>
        </div>
      ) : (
        <div className="ep-orders-list">
          {filtered.map((order) => {
            const isExpanded = expandedId === order.id;
            const color = STATUS_COLORS[order.status] ?? '#6b7280';
            const bg = STATUS_BG[order.status] ?? '#f9fafb';
            const statusLabel = STATUS_LABELS[order.status] ?? order.status;
            return (
              <div key={order.id} className="ep-order-card">
                <div
                  className="ep-order-header"
                  onClick={() => setExpandedId(isExpanded ? null : order.id)}
                >
                  <div className="ep-order-id">
                    #{order.id}
                    {order.order_type === 'dine_in' && <span className="ep-dine-badge">🍽 Стол</span>}
                  </div>
                  <div className="ep-order-addresses">
                    {order.order_type === 'dine_in' ? (
                      <span className="ep-order-from">🍽 {order.table_number ? `Стол №${order.table_number}` : order.to_address}</span>
                    ) : (
                      <>
                        <span className="ep-order-from">📍 {order.from_address}</span>
                        <span className="ep-order-arrow">→</span>
                        <span className="ep-order-to">{order.to_address}</span>
                      </>
                    )}
                  </div>
                  <div className="ep-order-right">
                    <span
                      className="ep-order-status"
                      style={{ color, background: bg }}
                    >
                      {statusLabel}
                    </span>
                    <span className="ep-order-price">{Number(order.price).toFixed(0)} сом</span>
                    <span className="ep-order-date">
                      {new Date(order.created_at).toLocaleDateString('ru-RU')}
                    </span>
                  </div>
                </div>

                {isExpanded && (
                  <div className="ep-order-detail">
                    <div className="ep-detail-grid">
                      <div className="ep-detail-item">
                        <span className="ep-detail-label">Кардар</span>
                        <span>{order.user_name || order.user_phone}</span>
                      </div>
                      <div className="ep-detail-item">
                        <span className="ep-detail-label">Телефон</span>
                        <span>{order.user_phone}</span>
                      </div>
                      {order.order_type === 'dine_in' && order.table_number && (
                        <div className="ep-detail-item">
                          <span className="ep-detail-label">Стол</span>
                          <span>№{order.table_number}</span>
                        </div>
                      )}
                      <div className="ep-detail-item">
                        <span className="ep-detail-label">Категория</span>
                        <span>{order.category}</span>
                      </div>
                      <div className="ep-detail-item">
                        <span className="ep-detail-label">Сүрөттөмө</span>
                        <span>{order.description}</span>
                      </div>
                    </div>

                    {order.status !== 'COMPLETED' && order.status !== 'CANCELLED' && (
                      <div className="ep-status-actions">
                        <span className="ep-actions-label">Статусту өзгөртүү:</span>
                        <div className="ep-status-btns">
                          {(order.order_type === 'dine_in'
                            ? DINE_IN_STATUSES
                            : order.status === 'PREPARING'
                              ? PREPARING_STATUSES
                              : DELIVERY_STATUSES
                          ).map((s) => (
                            <button
                              key={s.value}
                              className={`ep-status-btn ${order.status === s.value ? 'current' : ''}`}
                              disabled={order.status === s.value || updatingId === order.id}
                              onClick={() => handleStatusUpdate(order.id, s.value)}
                            >
                              {s.value === 'WAITING_COURIER' && <Truck size={13} />}
                              {s.value === 'ACCEPTED' && <CheckCircle size={13} />}
                              {s.value === 'READY' && <Truck size={13} />}
                              {s.value === 'COMPLETED' && <CheckCircle size={13} />}
                              {s.value === 'CANCELLED' && <XCircle size={13} />}
                              {s.label}
                            </button>
                          ))}
                        </div>
                        {updatingId === order.id && (
                          <span className="ep-updating">Жаңыртылууда...</span>
                        )}
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
