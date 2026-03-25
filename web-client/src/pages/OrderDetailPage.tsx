import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ordersService, Order, STATUS_LABELS, STATUS_COLORS } from '../services/orders';
import MapPicker from '../components/MapPicker';
import './OrderDetailPage.css';

const BATKEN: [number, number] = [40.060518, 70.819638];

export default function OrderDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [order, setOrder] = useState<Order | null>(null);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');
  const [showEdit, setShowEdit] = useState(false);

  useEffect(() => {
    if (!id) return;
    ordersService.getOrder(Number(id))
      .then(setOrder)
      .catch(() => setError('Заказ табылган жок'))
      .finally(() => setLoading(false));
  }, [id]);

  // Poll every 5s while order is active
  useEffect(() => {
    if (!id || !order) return;
    const finished = ['COMPLETED', 'CANCELLED'];
    if (finished.includes(order.status)) return;

    const interval = setInterval(() => {
      ordersService.getOrder(Number(id))
        .then(updated => {
          if (updated.status !== order.status) setOrder(updated);
        })
        .catch(() => {});
    }, 5000);

    return () => clearInterval(interval);
  }, [id, order?.status]);

  async function handleCancel() {
    if (!order || !confirm('Заказды жокко чыгаруу?')) return;
    setCancelling(true);
    try {
      await ordersService.cancelOrder(order.id);
      setOrder({ ...order, status: 'CANCELLED' });
    } catch {
      alert('Жокко чыгаруу мүмкүн болбоды');
    } finally {
      setCancelling(false);
    }
  }

  async function handleDelete() {
    if (!order || !confirm('Заказды биротоло өчүрүү?')) return;
    setDeleting(true);
    try {
      await ordersService.deleteOrder(order.id);
      navigate('/orders');
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      alert(msg || 'Өчүрүүгө болбоды');
    } finally {
      setDeleting(false);
    }
  }

  if (loading) return <div style={{ textAlign: 'center', padding: 80 }}><span className="spinner spinner-dark" /></div>;
  if (error || !order) return <div className="form-error" style={{ padding: 24 }}>{error || 'Табылган жок'}</div>;

  const label = STATUS_LABELS[order.status] || order.status;
  const color = STATUS_COLORS[order.status] || '#718096';
  const canCancel = ['WAITING_COURIER', 'COURIER_ASSIGNED'].includes(order.status);
  const canEdit = order.status === 'WAITING_COURIER';
  const canDelete = ['CANCELLED', 'COMPLETED', 'DELIVERED'].includes(order.status);
  const date = new Date(order.created_at).toLocaleString('ru-RU');

  const fromCoords: [number, number] | null = order.from_latitude && order.from_longitude
    ? [order.from_latitude, order.from_longitude] : null;
  const toCoords: [number, number] | null = order.to_latitude && order.to_longitude
    ? [order.to_latitude, order.to_longitude] : null;

  const mapCenter = fromCoords ?? toCoords ?? BATKEN;
  const mapUrl = fromCoords && toCoords
    ? `https://static-maps.yandex.ru/1.x/?lang=ru_RU&l=map&size=600,300&pt=${fromCoords[1]},${fromCoords[0]},pmgnm~${toCoords[1]},${toCoords[0]},pmrdm`
    : null;

  return (
    <div>
      <div className="detail-header">
        <button className="btn btn-ghost btn-sm" onClick={() => navigate('/orders')}>← Артка</button>
        <h1 className="page-title" style={{ margin: 0 }}>Заказ #{order.id}</h1>
      </div>

      <div className="detail-grid">
        <div>
          {/* Status */}
          <div className="card" style={{ marginBottom: 16 }}>
            <div className="detail-status-row">
              <span className="badge" style={{ background: color + '20', color, fontSize: 14, padding: '6px 16px' }}>
                {label}
              </span>
              <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>{date}</span>
            </div>

            <div className="detail-progress">
              {['WAITING_COURIER', 'COURIER_ASSIGNED', 'COURIER_ARRIVED', 'IN_PROGRESS', 'DELIVERED'].map((s, i, arr) => {
                const idx = arr.indexOf(order.status);
                const done = i <= idx;
                return (
                  <div key={s} className={`progress-step ${done ? 'done' : ''}`}>
                    <div className="progress-dot" />
                    <span>{STATUS_LABELS[s]}</span>
                    {i < arr.length - 1 && <div className={`progress-line ${i < idx ? 'done' : ''}`} />}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Route */}
          <div className="card" style={{ marginBottom: 16 }}>
            <div className="section-title">🗺️ Маршрут</div>
            <div className="detail-route">
              <div className="detail-route-item">
                <div className="route-icon green">А</div>
                <div>
                  <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Кайдан</div>
                  <div style={{ fontWeight: 600 }}>{order.from_address}</div>
                </div>
              </div>
              <div className="route-divider" />
              <div className="detail-route-item">
                <div className="route-icon red">Б</div>
                <div>
                  <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Кайда</div>
                  <div style={{ fontWeight: 600 }}>{order.to_address}</div>
                </div>
              </div>
            </div>
            {order.distance_km && (
              <div style={{ marginTop: 12, color: 'var(--text-muted)', fontSize: 13 }}>
                📏 Аралык: {order.distance_km.toFixed(1)} км
              </div>
            )}
          </div>

          {/* Map */}
          {mapUrl ? (
            <div className="card" style={{ marginBottom: 16 }}>
              <div className="section-title">🗺️ Карта</div>
              <img src={mapUrl} alt="route map" style={{ width: '100%', borderRadius: 8 }}
                onError={e => { (e.target as HTMLImageElement).style.display = 'none'; }} />
            </div>
          ) : fromCoords || toCoords ? (
            <div className="card" style={{ marginBottom: 16 }}>
              <div className="section-title">📍 Координаттар</div>
              {fromCoords && <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Кайдан: {fromCoords[0].toFixed(5)}, {fromCoords[1].toFixed(5)}</div>}
              {toCoords && <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>Кайда: {toCoords[0].toFixed(5)}, {toCoords[1].toFixed(5)}</div>}
            </div>
          ) : null}
        </div>

        <div>
          {/* Info */}
          <div className="card" style={{ marginBottom: 16 }}>
            <div className="section-title">ℹ️ Маалымат</div>
            <div className="detail-info-rows">
              <div className="info-row"><span>Категория</span><strong>{order.category}</strong></div>
              <div className="info-row"><span>Баасы</span><strong style={{ color: 'var(--primary)' }}>{order.price.toFixed(2)} сом</strong></div>
              {order.description && <div className="info-row"><span>Сүрөттөмө</span><strong>{order.description}</strong></div>}
              {order.enterprise_name && <div className="info-row"><span>Ишкана</span><strong>{order.enterprise_name}</strong></div>}
            </div>
          </div>

          {/* Verification code — shown when DELIVERED */}
          {order.status === 'DELIVERED' && order.verification_code && (
            <div className="card verification-card" style={{ marginBottom: 16 }}>
              <div className="section-title">Тастыктоо коду</div>
              <p style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 12 }}>
                Курьерге ушул кодду айтыңыз — жеткирүүнү тастыктоо үчүн
              </p>
              <div className="verification-code-box">
                {order.verification_code.split('').map((ch, i) => (
                  <span key={i} className="verification-digit">{ch}</span>
                ))}
              </div>
            </div>
          )}

          {/* Courier */}
          {order.courier_name && (
            <div className="card" style={{ marginBottom: 16 }}>
              <div className="section-title">🚴 Курьер</div>
              <div className="courier-info">
                <div className="courier-avatar">{order.courier_name.charAt(0)}</div>
                <div>
                  <div style={{ fontWeight: 600 }}>{order.courier_name}</div>
                  {order.courier_phone && (
                    <a href={`tel:${order.courier_phone}`} style={{ fontSize: 13, color: 'var(--primary)' }}>
                      📞 {order.courier_phone}
                    </a>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Actions */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {canEdit && (
              <button className="btn btn-outline btn-full" onClick={() => setShowEdit(true)}>
                ✏️ Заказды өзгөртүү
              </button>
            )}
            {canCancel && (
              <button className="btn btn-danger btn-full" onClick={handleCancel} disabled={cancelling}>
                {cancelling ? <span className="spinner" /> : '✕ Жокко чыгаруу'}
              </button>
            )}
            {canDelete && (
              <button className="btn btn-ghost btn-full" onClick={handleDelete} disabled={deleting}
                style={{ color: 'var(--danger)', borderColor: 'var(--danger)' }}>
                {deleting ? <span className="spinner spinner-dark" /> : '🗑️ Заказды өчүрүү'}
              </button>
            )}
          </div>
        </div>
      </div>

      {showEdit && order && (
        <EditOrderModal
          order={order}
          onClose={() => setShowEdit(false)}
          onSaved={(updated) => { setOrder({ ...order, ...updated }); setShowEdit(false); }}
        />
      )}
    </div>
  );
}

// ── EditOrderModal ─────────────────────────────────────────────────────────────
function EditOrderModal({
  order,
  onClose,
  onSaved,
}: {
  order: Order;
  onClose: () => void;
  onSaved: (data: Partial<Order>) => void;
}) {
  const [description, setDescription] = useState(order.description || '');
  const [fromAddress, setFromAddress] = useState(order.from_address);
  const [toAddress, setToAddress] = useState(order.to_address);
  const [fromCoords, setFromCoords] = useState<[number, number] | null>(
    order.from_latitude && order.from_longitude ? [order.from_latitude, order.from_longitude] : null
  );
  const [toCoords, setToCoords] = useState<[number, number] | null>(
    order.to_latitude && order.to_longitude ? [order.to_latitude, order.to_longitude] : null
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  function calcDistance(from: [number, number], to: [number, number]): number {
    const R = 6371;
    const dLat = (to[0] - from[0]) * Math.PI / 180;
    const dLon = (to[1] - from[1]) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2
      + Math.cos(from[0] * Math.PI / 180) * Math.cos(to[0] * Math.PI / 180)
      * Math.sin(dLon / 2) ** 2;
    return Math.max(0.5, R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
  }

  const distanceKm = fromCoords && toCoords ? calcDistance(fromCoords, toCoords) : null;
  const estimatedPrice = distanceKm !== null ? 80 + distanceKm * 20 : null;

  async function handleSave() {
    if (!fromAddress.trim() || !toAddress.trim()) {
      setError('Адрестерди толуктаңыз');
      return;
    }
    setError('');
    setSaving(true);
    try {
      const payload: Parameters<typeof ordersService.updateOrder>[1] = {
        description,
        from_address: fromAddress,
        to_address: toAddress,
        ...(fromCoords ? { from_latitude: fromCoords[0], from_longitude: fromCoords[1] } : {}),
        ...(toCoords ? { to_latitude: toCoords[0], to_longitude: toCoords[1] } : {}),
        ...(distanceKm !== null ? { distance_km: distanceKm } : {}),
      };
      const result = await ordersService.updateOrder(order.id, payload);
      onSaved({ ...payload, ...(result.price !== undefined ? { price: result.price } : {}) });
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(msg || 'Ката чыкты');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-card" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>✏️ Заказды өзгөртүү</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div className="form-group">
          <label>Сүрөттөмө</label>
          <textarea rows={2} value={description} onChange={e => setDescription(e.target.value)} />
        </div>

        <div className="form-group">
          <label>Кайдан алуу</label>
          <input value={fromAddress} onChange={e => setFromAddress(e.target.value)} />
          <MapPicker
            value={fromCoords}
            markerColor="green"
            height="180px"
            onChange={(coords, addr) => {
              setFromCoords(coords);
              if (!fromAddress || fromAddress === order.from_address) setFromAddress(addr);
            }}
          />
        </div>

        <div className="form-group">
          <label>Кайда жеткирүү</label>
          <input value={toAddress} onChange={e => setToAddress(e.target.value)} />
          <MapPicker
            value={toCoords}
            markerColor="red"
            height="180px"
            onChange={(coords, addr) => {
              setToCoords(coords);
              if (!toAddress || toAddress === order.to_address) setToAddress(addr);
            }}
          />
        </div>

        {distanceKm !== null && (
          <div style={{
            background: 'var(--primary-light)',
            borderRadius: 10,
            padding: '12px 16px',
            marginBottom: 12,
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}>
            <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>
              Аралык: ~{distanceKm.toFixed(1)} км
            </span>
            <strong style={{ color: 'var(--primary)', fontSize: 16 }}>
              {estimatedPrice!.toFixed(0)} сом
            </strong>
          </div>
        )}

        {error && <div className="form-error" style={{ marginBottom: 12 }}>{error}</div>}

        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn btn-ghost" style={{ flex: 1 }} onClick={onClose}>Жабуу</button>
          <button className="btn btn-primary" style={{ flex: 2 }} onClick={handleSave} disabled={saving}>
            {saving ? <span className="spinner" /> : 'Сактоо'}
          </button>
        </div>
      </div>
    </div>
  );
}
