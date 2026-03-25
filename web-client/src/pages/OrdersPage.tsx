import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { ordersService, Order, STATUS_LABELS, STATUS_COLORS } from '../services/orders';
import './OrdersPage.css';

const WS_BASE = (import.meta.env.VITE_API_URL || 'http://localhost:8000').replace(/^http/, 'ws');

// Normalized WS status → raw REST status
const WS_TO_RAW: Record<string, string> = {
  pending: 'WAITING_COURIER',
  accepted: 'COURIER_ASSIGNED',
  in_transit: 'IN_PROGRESS',
  delivered: 'DELIVERED',
  completed: 'COMPLETED',
  cancelled: 'CANCELLED',
};

interface Toast { id: number; text: string; color: string; }

export default function OrdersPage() {
  const navigate = useNavigate();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [toasts, setToasts] = useState<Toast[]>([]);
  const prevStatusesRef = useRef<Record<number, string>>({});

  function addToast(text: string, color: string) {
    const id = Date.now() + Math.random();
    setToasts(prev => [...prev, { id, text, color }]);
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 4500);
  }

  useEffect(() => {
    ordersService.getMyOrders()
      .then(data => {
        setOrders(data);
        prevStatusesRef.current = Object.fromEntries(data.map(o => [o.id, o.status]));
      })
      .catch(() => setError('Заказдарды жүктөөдө ката чыкты'))
      .finally(() => setLoading(false));
  }, []);

  // WebSocket: live status updates
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return;

    const ws = new WebSocket(`${WS_BASE}/orders/ws/my?token=${token}`);

    ws.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        if (data.event !== 'orders_snapshot') return;

        const changed: Array<{ id: number; rawStatus: string }> = [];

        data.orders.forEach((wsOrder: { id: number; status: string }) => {
          const rawStatus = WS_TO_RAW[wsOrder.status] || wsOrder.status.toUpperCase();
          const prev = prevStatusesRef.current[wsOrder.id];
          if (prev !== undefined && prev !== rawStatus) {
            changed.push({ id: wsOrder.id, rawStatus });
          }
          prevStatusesRef.current[wsOrder.id] = rawStatus;
        });

        if (changed.length === 0) return;

        ordersService.getMyOrders().then(newOrders => {
          setOrders(newOrders);
          prevStatusesRef.current = Object.fromEntries(newOrders.map(o => [o.id, o.status]));

          changed.forEach(({ id, rawStatus }) => {
            const label = STATUS_LABELS[rawStatus] || rawStatus;
            const color = STATUS_COLORS[rawStatus] || '#718096';
            addToast(`Заказ #${id}: ${label}`, color);
          });
        }).catch(() => {});
      } catch {/* ignore parse errors */}
    };

    ws.onerror = () => {};
    return () => ws.close();
  }, []);

  const active = orders.filter(o => !['COMPLETED', 'DELIVERED', 'CANCELLED'].includes(o.status));
  const history = orders.filter(o => ['COMPLETED', 'DELIVERED', 'CANCELLED'].includes(o.status));

  if (loading) return <div style={{ textAlign: 'center', padding: 80 }}><span className="spinner spinner-dark" /></div>;
  if (error) return <div className="form-error" style={{ padding: 24 }}>{error}</div>;

  return (
    <div>
      {/* Toast notifications */}
      <div className="toast-container">
        {toasts.map(t => (
          <div key={t.id} className="toast" style={{ borderLeftColor: t.color }}>
            <span className="toast-dot" style={{ background: t.color }} />
            <span>{t.text}</span>
          </div>
        ))}
      </div>

      <h1 className="page-title">📦 Менин заказдарым</h1>

      {orders.length === 0 ? (
        <div className="empty-state">
          <div style={{ fontSize: 64, marginBottom: 16 }}>📭</div>
          <p>Азырынча заказ жок</p>
        </div>
      ) : (
        <>
          {active.length > 0 && (
            <div style={{ marginBottom: 28 }}>
              <div className="section-title">Активдүү заказдар</div>
              <div className="orders-list">
                {active.map(o => <OrderCard key={o.id} order={o} onClick={() => navigate(`/orders/${o.id}`)} />)}
              </div>
            </div>
          )}

          {history.length > 0 && (
            <div>
              <div className="section-title">Тарых</div>
              <div className="orders-list">
                {history.map(o => <OrderCard key={o.id} order={o} onClick={() => navigate(`/orders/${o.id}`)} />)}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function OrderCard({ order, onClick }: { order: Order; onClick: () => void }) {
  const label = STATUS_LABELS[order.status] || order.status;
  const color = STATUS_COLORS[order.status] || '#718096';
  const date = new Date(order.created_at).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

  return (
    <div className="order-card" onClick={onClick}>
      <div className="order-card-header">
        <span className="order-id">#{order.id}</span>
        <span className="badge" style={{ background: color + '20', color }}>{label}</span>
      </div>
      <div className="order-route">
        <div className="route-point">
          <span className="route-dot green" />
          <span>{order.from_address}</span>
        </div>
        <div className="route-point">
          <span className="route-dot red" />
          <span>{order.to_address}</span>
        </div>
      </div>
      <div className="order-card-footer">
        <span>🕐 {date}</span>
        <span>💰 {order.price.toFixed(0)} сом</span>
        {order.distance_km && <span>📏 {order.distance_km.toFixed(1)} км</span>}
      </div>
    </div>
  );
}
