import { useEffect, useState, useCallback } from 'react';
import { History, Trash2, X, RefreshCw, CheckCircle, XCircle } from 'lucide-react';
import { ordersService, EnterpriseOrder } from '../services/orders';
import { parseUtc, bishkekDateKey } from '../utils/date';
import './HistoryPage.css';

const TZ = 'Asia/Bishkek';

const STATUS_LABELS: Record<string, string> = {
  COMPLETED: 'Аяктады',
  DELIVERED: 'Жеткирилди',
  CANCELLED: 'Жокко чыгарылды',
};

const STATUS_COLORS: Record<string, string> = {
  COMPLETED: '#059669',
  DELIVERED: '#059669',
  CANCELLED: '#dc2626',
};

// Дата жарлыгын кайтарат: Бүгүн / Кечээ / 12 март жана т.б.
function dateGroupLabel(dateStr: string): string {
  const d = parseUtc(dateStr);
  if (!d) return dateStr;
  const todayKey = new Date().toLocaleDateString('sv-SE', { timeZone: TZ });
  const yest = new Date();
  yest.setDate(yest.getDate() - 1);
  const yesterdayKey = yest.toLocaleDateString('sv-SE', { timeZone: TZ });
  const key = bishkekDateKey(dateStr);
  if (key === todayKey) return 'Бүгүн';
  if (key === yesterdayKey) return 'Кечээ';
  return d.toLocaleDateString('ru-RU', { timeZone: TZ, day: 'numeric', month: 'long', year: 'numeric' });
}

function getDateKey(dateStr: string): string {
  return bishkekDateKey(dateStr); // YYYY-MM-DD in Bishkek time
}

// Заказдарды датага жараша топтоо
function groupByDate(orders: EnterpriseOrder[]): { label: string; key: string; orders: EnterpriseOrder[] }[] {
  const map = new Map<string, EnterpriseOrder[]>();
  for (const o of orders) {
    const key = getDateKey(o.created_at);
    if (!map.has(key)) map.set(key, []);
    map.get(key)!.push(o);
  }
  return Array.from(map.entries())
    .sort(([a], [b]) => b.localeCompare(a)) // жаңысы биринчи
    .map(([key, orders]) => ({ key, label: dateGroupLabel(orders[0].created_at), orders }));
}

export default function HistoryPage() {
  const [orders, setOrders] = useState<EnterpriseOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [deleteError, setDeleteError] = useState('');
  const [clearing, setClearing] = useState(false);
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await ordersService.getHistory({ limit: 200 });
      setOrders(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (orderId: number) => {
    setDeletingId(orderId);
    setDeleteError('');
    try {
      await ordersService.deleteHistoryOrder(orderId);
      setOrders(prev => prev.filter(o => o.id !== orderId));
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setDeleteError(err?.response?.data?.detail ?? 'Өчүрүү мүмкүн болгон жок');
    } finally {
      setDeletingId(null);
    }
  };

  const handleClearAll = async () => {
    setClearing(true);
    try {
      await ordersService.clearHistory();
      setOrders([]);
    } catch (e) {
      console.error(e);
    } finally {
      setClearing(false);
      setConfirmClear(false);
    }
  };

  const groups = groupByDate(orders);

  const OrderCard = ({ order }: { order: EnterpriseOrder }) => {
    const isExpanded = expandedId === order.id;
    const color = STATUS_COLORS[order.status] ?? '#6b7280';
    const statusLabel = STATUS_LABELS[order.status] ?? order.status;

    return (
      <div className="ep-history-card">
        <div
          className="ep-history-row"
          onClick={() => setExpandedId(isExpanded ? null : order.id)}
        >
          <div className="ep-history-left">
            <span className="ep-history-id">
              #{order.id}
              {order.order_type === 'dine_in' && <span className="ep-dine-badge">🍽</span>}
            </span>
            <div className="ep-history-info">
              {order.order_type === 'dine_in' ? (
                <span>{order.table_number ? `Стол №${order.table_number}` : order.to_address}</span>
              ) : (
                <span>{order.to_address}</span>
              )}
              <span className="ep-history-time">
                {parseUtc(order.created_at)?.toLocaleTimeString('ru-RU', { timeZone: TZ, hour: '2-digit', minute: '2-digit' })}
              </span>
            </div>
          </div>
          <div className="ep-history-right">
            <span className="ep-history-status" style={{ color }}>
              {order.status === 'CANCELLED' ? <XCircle size={13} /> : <CheckCircle size={13} />}
              {statusLabel}
            </span>
            <span className="ep-history-price" title={order.items_total == null ? 'Жеткирүү акысы' : 'Заказдын суммасы'}>
              {order.items_total != null
                ? `${Number(order.items_total).toFixed(0)} сом`
                : <span style={{ color: '#9ca3af', fontSize: 12 }}>{Number(order.price).toFixed(0)} сом <em>(жеткирүү)</em></span>
              }
            </span>
            <button
              className="ep-history-del"
              onClick={e => { e.stopPropagation(); handleDelete(order.id); }}
              disabled={deletingId === order.id}
              title="Өчүрүү"
            >
              {deletingId === order.id ? <RefreshCw size={13} className="spin" /> : <X size={13} />}
            </button>
          </div>
        </div>

        {isExpanded && (
          <div className="ep-history-detail">
            <div className="ep-detail-grid">
              <div className="ep-detail-item">
                <span className="ep-detail-label">Кардар</span>
                <span>{order.user_name || order.user_phone || '—'}</span>
              </div>
              <div className="ep-detail-item">
                <span className="ep-detail-label">Телефон</span>
                <span>{order.user_phone || '—'}</span>
              </div>
              {order.order_type === 'dine_in' && order.table_number && (
                <div className="ep-detail-item">
                  <span className="ep-detail-label">Стол</span>
                  <span>№{order.table_number}</span>
                </div>
              )}
              <div className="ep-detail-item">
                <span className="ep-detail-label">Сүрөттөмө</span>
                <span>{order.description}</span>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="ep-history">
      <div className="ep-history-header">
        <div className="ep-history-title">
          <History size={22} />
          <h1>Тарых</h1>
          <span className="ep-orders-count">{orders.length}</span>
        </div>
        <div className="ep-history-actions">
          <button className="ep-refresh-btn" onClick={load} disabled={loading}>
            <RefreshCw size={14} className={loading ? 'spin' : ''} />
            Жаңыртуу
          </button>
          {orders.length > 0 && (
            <button
              className="ep-clear-btn"
              onClick={() => setConfirmClear(true)}
              disabled={clearing}
            >
              <Trash2 size={14} />
              Тарыхты тазалоо
            </button>
          )}
        </div>
      </div>

      {deleteError && (
        <div className="ep-error-banner" onClick={() => setDeleteError('')}>
          {deleteError} <X size={14} style={{ verticalAlign: 'middle', cursor: 'pointer' }} />
        </div>
      )}

      {loading ? (
        <div className="ep-loading">Жүктөлүүдө...</div>
      ) : orders.length === 0 ? (
        <div className="ep-empty">
          <History size={48} opacity={0.2} />
          <p>Тарых бош</p>
        </div>
      ) : (
        <div className="ep-history-groups">
          {groups.map(group => {
            const groupRevenue = group.orders
              .filter(o => o.status !== 'CANCELLED')
              .reduce((s, o) => s + (o.items_total != null ? Number(o.items_total) : 0), 0);

            return (
              <div key={group.key} className="ep-history-group">
                <div className="ep-history-group-header">
                  <span className="ep-history-group-label">{group.label}</span>
                  <span className="ep-history-group-meta">
                    {group.orders.length} заказ
                    {groupRevenue > 0 && ` · ${groupRevenue.toFixed(0)} сом`}
                  </span>
                </div>
                <div className="ep-history-list">
                  {group.orders.map(order => (
                    <OrderCard key={order.id} order={order} />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {confirmClear && (
        <div className="ep-confirm-overlay" onClick={() => setConfirmClear(false)}>
          <div className="ep-confirm-modal" onClick={e => e.stopPropagation()}>
            <h3>Тарыхты тазалоо</h3>
            <p>Бардык аяктаган жана жокко чыгарылган заказдар тарыхтан өчүрүлөт. Уланасызбы?</p>
            <div className="ep-confirm-btns">
              <button className="ep-btn-cancel-sm" onClick={() => setConfirmClear(false)}>Жок</button>
              <button className="ep-btn-danger" onClick={handleClearAll} disabled={clearing}>
                {clearing ? 'Тазалануудa...' : 'Ооба, тазала'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
