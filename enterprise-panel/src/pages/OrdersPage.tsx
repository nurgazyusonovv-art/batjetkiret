import { useEffect, useState, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Package, Search, X, RefreshCw, CheckCircle, XCircle, Truck, CreditCard } from 'lucide-react';
import { ordersService, EnterpriseOrder } from '../services/orders';
import { fmtDate } from '../utils/date';
import './OrdersPage.css';

/** Play a short alert beep via Web Audio API (no audio file needed). */
function playOrderSound() {
  try {
    const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const times = [0, 0.35, 0.7];
    times.forEach((t) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type = 'sine';
      osc.frequency.value = 880;
      gain.gain.setValueAtTime(0.6, ctx.currentTime + t);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + t + 0.28);
      osc.start(ctx.currentTime + t);
      osc.stop(ctx.currentTime + t + 0.3);
    });
  } catch (_) {}
}

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
  { value: 'WAITING_COURIER', label: 'Жаңы' },
  { value: 'ACCEPTED', label: 'Кабыл алынды — ишкана' },
  { value: 'PREPARING', label: 'Даярдалып жатат' },
  { value: 'READY', label: 'Даяр — Курьер күтүүдө' },
  { value: 'PICKED_UP', label: 'Кабыл алынды — Курьер' },
  { value: 'ON_THE_WAY', label: 'Жеткирүүнү баштады' },
];

// ACCEPTED → enterprise starts preparing
const ACCEPTED_STATUSES = [
  { value: 'PREPARING', label: 'Даярдалып жатат' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

// PREPARING → enterprise marks ready for courier
const PREPARING_STATUSES = [
  { value: 'READY', label: 'Даяр — курьер чакыруу' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

// WAITING_COURIER (non-enterprise or after courier cancel)
const WAITING_STATUSES = [
  { value: 'ACCEPTED', label: 'Кабыл алынды' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

const DINE_IN_STATUSES = [
  { value: 'READY', label: 'Даяр' },
  { value: 'COMPLETED', label: 'Жабылды' },
  { value: 'CANCELLED', label: 'Жокко чыгаруу' },
];

const POLL_INTERVAL_MS = 20_000; // poll every 20 seconds

export default function OrdersPage() {
  const navigate = useNavigate();
  const [orders, setOrders] = useState<EnterpriseOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState('');
  const [search, setSearch] = useState('');
  const [updatingId, setUpdatingId] = useState<number | null>(null);
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const [newOrderAlert, setNewOrderAlert] = useState(false);
  const [highlightId, setHighlightId] = useState<number | null>(null);

  // Tracks ALL known order IDs — always uses unfiltered list so detection works
  // regardless of which status filter the user has active.
  const knownIdsRef = useRef<Set<number> | null>(null);
  const alertTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // ── Fetch displayed orders (respects active filter) ────────────────────────
  const loadDisplay = useCallback(async (showSpinner = false) => {
    if (showSpinner) setLoading(true);
    try {
      const data = await ordersService.getOrders(filterStatus ? { status: filterStatus } : {});
      setOrders(data);
    } catch (e) {
      console.error(e);
    } finally {
      if (showSpinner) setLoading(false);
    }
  }, [filterStatus]);

  // ── Background poll — always fetches ALL orders for new-order detection ────
  const pollForNewOrders = useCallback(async () => {
    try {
      const all = await ordersService.getOrders({});
      const incoming = new Set(all.map((o) => o.id));

      if (knownIdsRef.current !== null) {
        const hasNew = all.some((o) => !knownIdsRef.current!.has(o.id));
        if (hasNew) {
          playOrderSound();
          setNewOrderAlert(true);
          if (alertTimerRef.current) clearTimeout(alertTimerRef.current);
          alertTimerRef.current = setTimeout(() => setNewOrderAlert(false), 6000);
          // Also refresh the display list so the new order appears
          await loadDisplay(false);
        }
      }
      knownIdsRef.current = incoming;
    } catch (_) {}
  }, [loadDisplay]);

  // ── Initial load ───────────────────────────────────────────────────────────
  useEffect(() => {
    const init = async () => {
      setLoading(true);
      try {
        const all = await ordersService.getOrders({});
        knownIdsRef.current = new Set(all.map((o) => o.id));
        // Apply active filter for display
        const display = filterStatus ? all.filter((o) => o.status === filterStatus) : all;
        setOrders(display);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, [filterStatus]);

  // ── Background polling ─────────────────────────────────────────────────────
  useEffect(() => {
    const id = setInterval(pollForNewOrders, POLL_INTERVAL_MS);
    return () => clearInterval(id);
  }, [pollForNewOrders]);

  // ── SW message: notification click → highlight that order ─────────────────
  useEffect(() => {
    const handler = (e: MessageEvent) => {
      if (e.data?.type === 'OPEN_ORDER' && e.data.order_id) {
        const oid = Number(e.data.order_id);
        setHighlightId(oid);
        setExpandedId(oid);
        setFilterStatus(''); // show all so the order is visible
        setTimeout(() => {
          document.getElementById(`order-${oid}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }, 300);
        setTimeout(() => setHighlightId(null), 3000);
      }
    };
    navigator.serviceWorker?.addEventListener('message', handler);
    return () => navigator.serviceWorker?.removeEventListener('message', handler);
  }, []);

  // ── Also handle ?order_id= query param (notification opens new tab) ────────
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const oid = params.get('order_id');
    if (oid) {
      const id = Number(oid);
      setHighlightId(id);
      setExpandedId(id);
      setTimeout(() => {
        document.getElementById(`order-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 800);
      setTimeout(() => setHighlightId(null), 3000);
      // Clean up URL without re-render
      window.history.replaceState({}, '', '/orders');
    }
  }, []);

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
      await loadDisplay(false);
      // Sync knownIds after status update (no new orders, just refresh)
      const all = await ordersService.getOrders({});
      knownIdsRef.current = new Set(all.map((o) => o.id));
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      alert(err?.response?.data?.detail ?? 'Ката кетти');
    } finally {
      setUpdatingId(null);
    }
  };

  return (
    <div className="ep-orders">
      {/* New order alert banner */}
      {newOrderAlert && (
        <div className="ep-new-order-alert">
          🛎 Жаңы заказ келди! Тизмени жаңыртыңыз.
        </div>
      )}

      <div className="ep-orders-header">
        <div className="ep-orders-title">
          <Package size={22} />
          <h1>Заказдар</h1>
          <span className="ep-orders-count">{filtered.length}</span>
        </div>
        <button className="ep-refresh-btn" onClick={() => loadDisplay(true)} disabled={loading}>
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
              <div
                key={order.id}
                id={`order-${order.id}`}
                className={`ep-order-card${highlightId === order.id ? ' ep-order-highlight' : ''}`}
              >
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
                    <span className="ep-order-price">
                      {order.items_total != null ? `${Number(order.items_total).toFixed(0)} сом` : '—'}
                    </span>
                    <span className="ep-order-date">
                      {fmtDate(order.created_at)}
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
                      {order.courier_name && (
                        <div className="ep-detail-item">
                          <span className="ep-detail-label">Курьер</span>
                          <span>🚴 {order.courier_name}{order.courier_phone ? ` · ${order.courier_phone}` : ''}</span>
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

                    <div className="ep-order-payment-link">
                      <button
                        className="ep-payment-link-btn"
                        onClick={() => navigate(`/payments?order_id=${order.id}`)}
                      >
                        <CreditCard size={14} />
                        Төлөмдү кароо
                      </button>
                    </div>

                    {order.status !== 'COMPLETED' && order.status !== 'CANCELLED' && order.status !== 'READY' && (
                      <div className="ep-status-actions">
                        <span className="ep-actions-label">Кийинки кадам:</span>
                        <div className="ep-status-btns">
                          {(order.order_type === 'dine_in'
                            ? DINE_IN_STATUSES
                            : order.status === 'ACCEPTED'
                              ? ACCEPTED_STATUSES
                              : order.status === 'PREPARING'
                                ? PREPARING_STATUSES
                                : WAITING_STATUSES
                          ).map((s) => (
                            <button
                              key={s.value}
                              className={`ep-status-btn ${s.value === 'CANCELLED' ? 'cancel' : 'primary'}`}
                              disabled={updatingId === order.id}
                              onClick={() => handleStatusUpdate(order.id, s.value)}
                            >
                              {s.value === 'PREPARING' && <Package size={13} />}
                              {s.value === 'READY' && <Truck size={13} />}
                              {s.value === 'ACCEPTED' && <CheckCircle size={13} />}
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
