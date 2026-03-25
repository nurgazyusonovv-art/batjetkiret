import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { enterprisesService, Enterprise, EnterpriseMenuCategory } from '../services/enterprises';
import type { EnterpriseProduct } from '../services/enterprises';
import { ordersService } from '../services/orders';
import MapPicker from '../components/MapPicker';
import './HomePage.css';

type Step = 'home' | 'enterprise-menu' | 'create-order';
type OrderStep = 1 | 2 | 3 | 4;

const CATEGORIES = [
  { value: 'Жеткирүү', icon: '📦', label: 'Жеткирүү' },
  { value: 'Тамак-аш', icon: '🍔', label: 'Тамак-аш' },
  { value: 'Дары-дармек', icon: '💊', label: 'Дары-дармек' },
  { value: 'Документтер', icon: '📄', label: 'Документтер' },
  { value: 'Башка', icon: '📋', label: 'Башка' },
];

export default function HomePage() {
  const navigate = useNavigate();
  const [enterprises, setEnterprises] = useState<Enterprise[]>([]);
  const [loading, setLoading] = useState(true);
  const [step, setStep] = useState<Step>('home');

  // Enterprise order
  const [selectedEnterprise, setSelectedEnterprise] = useState<Enterprise | null>(null);
  const [menuCategories, setMenuCategories] = useState<EnterpriseMenuCategory[]>([]);
  const [menuLoading, setMenuLoading] = useState(false);
  const [cart, setCart] = useState<Record<number, number>>({});
  const [showDeliveryForm, setShowDeliveryForm] = useState(false);
  const [deliveryAddress, setDeliveryAddress] = useState('');
  const [deliveryCoords, setDeliveryCoords] = useState<[number, number] | null>(null);

  // Regular order
  const [fromAddress, setFromAddress] = useState('');
  const [toAddress, setToAddress] = useState('');
  const [fromCoords, setFromCoords] = useState<[number, number] | null>(null);
  const [toCoords, setToCoords] = useState<[number, number] | null>(null);
  const [category, setCategory] = useState('Жеткирүү');
  const [description, setDescription] = useState('');
  const [orderStep, setOrderStep] = useState<OrderStep>(1);
  const [submitting, setSubmitting] = useState(false);
  const [orderError, setOrderError] = useState('');

  useEffect(() => {
    enterprisesService.getActive()
      .then(setEnterprises)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  async function openEnterprise(e: Enterprise) {
    setSelectedEnterprise(e);
    setMenuLoading(true);
    setStep('enterprise-menu');
    try {
      const data = await enterprisesService.getMenu(e.id);
      setMenuCategories(data.menu);
    } catch {
      setMenuCategories([]);
    } finally {
      setMenuLoading(false);
    }
  }

  function addToCart(productId: number) {
    setCart(prev => ({ ...prev, [productId]: (prev[productId] || 0) + 1 }));
  }
  function removeFromCart(productId: number) {
    setCart(prev => {
      const n = { ...prev };
      if ((n[productId] || 0) <= 1) delete n[productId];
      else n[productId]--;
      return n;
    });
  }

  const allProducts: EnterpriseProduct[] = menuCategories.flatMap(c => c.products);
  const cartTotal = allProducts.filter(p => cart[p.id]).reduce((s, p) => s + p.price * (cart[p.id] || 0), 0);
  const cartCount = Object.values(cart).reduce((a, b) => a + b, 0);

  async function submitEnterpriseOrder() {
    if (!selectedEnterprise) return;
    if (!deliveryAddress.trim()) { setOrderError('Жеткирүү дарегин киргизиңиз'); return; }
    const items = allProducts.filter(p => cart[p.id]).map(p => `${p.name} x${cart[p.id]}`).join(', ');
    const desc = `Буйрутма: ${items}`;
    setOrderError('');
    setSubmitting(true);
    try {
      const fromCoords = selectedEnterprise.lat && selectedEnterprise.lon
        ? { from_latitude: selectedEnterprise.lat, from_longitude: selectedEnterprise.lon }
        : {};
      const toCoords = deliveryCoords
        ? { to_latitude: deliveryCoords[0], to_longitude: deliveryCoords[1] }
        : {};
      const distKm = (selectedEnterprise.lat && selectedEnterprise.lon && deliveryCoords)
        ? calcHaversine([selectedEnterprise.lat, selectedEnterprise.lon], deliveryCoords)
        : 1;
      const order = await ordersService.createOrder({
        category: selectedEnterprise.category || 'Ишкана',
        description: desc,
        from_address: selectedEnterprise.address || selectedEnterprise.name,
        to_address: deliveryAddress,
        distance_km: distKm,
        enterprise_id: selectedEnterprise.id,
        ...fromCoords,
        ...toCoords,
      });
      setCart({});
      setDeliveryAddress('');
      setDeliveryCoords(null);
      setShowDeliveryForm(false);
      navigate(`/orders/${order.id}`);
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setOrderError(msg || 'Ката чыкты');
    } finally {
      setSubmitting(false);
    }
  }

  function calcHaversine(from: [number, number], to: [number, number]): number {
    const R = 6371;
    const dLat = (to[0] - from[0]) * Math.PI / 180;
    const dLon = (to[1] - from[1]) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2
      + Math.cos(from[0] * Math.PI / 180) * Math.cos(to[0] * Math.PI / 180)
      * Math.sin(dLon / 2) ** 2;
    return Math.max(0.5, R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
  }

  function calcDistance(): number {
    if (!fromCoords || !toCoords) return 1;
    const R = 6371;
    const dLat = (toCoords[0] - fromCoords[0]) * Math.PI / 180;
    const dLon = (toCoords[1] - fromCoords[1]) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2
      + Math.cos(fromCoords[0] * Math.PI / 180) * Math.cos(toCoords[0] * Math.PI / 180)
      * Math.sin(dLon / 2) ** 2;
    return Math.max(0.5, R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
  }

  async function submitRegularOrder() {
    if (!fromAddress || !toAddress) { setOrderError('Адрестерди толуктаңыз'); return; }
    if (!description) { setOrderError('Сүрөттөмө жазыңыз'); return; }
    setOrderError('');
    setSubmitting(true);
    try {
      const order = await ordersService.createOrder({
        category,
        description,
        from_address: fromAddress,
        to_address: toAddress,
        distance_km: calcDistance(),
        ...(fromCoords ? { from_latitude: fromCoords[0], from_longitude: fromCoords[1] } : {}),
        ...(toCoords ? { to_latitude: toCoords[0], to_longitude: toCoords[1] } : {}),
      });
      navigate(`/orders/${order.id}`);
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setOrderError(msg || 'Ката чыкты');
    } finally {
      setSubmitting(false);
    }
  }

  // ── Enterprise Menu ───────────────────────────────────────────────────────
  if (step === 'enterprise-menu' && selectedEnterprise) {
    return (
      <div>
        <div className="page-back">
          <button className="btn btn-ghost btn-sm" onClick={() => { setStep('home'); setCart({}); }}>
            ← Артка
          </button>
          <h1 className="page-title" style={{ margin: 0 }}>{selectedEnterprise.name}</h1>
        </div>
        {selectedEnterprise.address && <p style={{ color: 'var(--text-muted)', marginBottom: 20 }}>📍 {selectedEnterprise.address}</p>}

        {menuLoading ? (
          <div style={{ textAlign: 'center', padding: 60 }}><span className="spinner spinner-dark" /></div>
        ) : menuCategories.length === 0 ? (
          <div className="empty-state"><p>Азырынча товар жок</p></div>
        ) : (
          menuCategories.map(cat => (
            <div key={cat.id} style={{ marginBottom: 28 }}>
              <div className="section-title">{cat.name}</div>
              <div className="product-grid">
                {cat.products.map(p => (
                  <div key={p.id} className="product-card">
                    <div className="product-info">
                      <div className="product-name">{p.name}</div>
                      {p.description && <div className="product-desc">{p.description}</div>}
                      <div className="product-price">{p.price.toFixed(0)} сом</div>
                    </div>
                    <div className="product-actions">
                      {cart[p.id] ? (
                        <div className="qty-control">
                          <button onClick={() => removeFromCart(p.id)}>−</button>
                          <span>{cart[p.id]}</span>
                          <button onClick={() => addToCart(p.id)}>+</button>
                        </div>
                      ) : (
                        <button className="btn btn-primary btn-sm" onClick={() => addToCart(p.id)}>+</button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))
        )}

        {cartCount > 0 && (
          <div className="cart-bar">
            <div className="cart-info">
              <span className="cart-count">{cartCount} буюм</span>
              <span className="cart-total">{cartTotal.toFixed(0)} сом</span>
            </div>
            <button className="btn btn-primary" onClick={() => { setOrderError(''); setShowDeliveryForm(true); }}>
              Заказ бер →
            </button>
          </div>
        )}

        {showDeliveryForm && (
          <div className="modal-overlay" onClick={() => setShowDeliveryForm(false)}>
            <div className="modal-card" onClick={e => e.stopPropagation()} style={{ maxWidth: 480 }}>
              <div className="modal-header">
                <h2>📍 Жеткирүү дареги</h2>
                <button className="modal-close" onClick={() => setShowDeliveryForm(false)}>✕</button>
              </div>

              <div className="form-group">
                <label>Дарек (кол менен жазыңыз)</label>
                <input
                  type="text"
                  placeholder="Мисалы: Ленин көч., 15-үй"
                  value={deliveryAddress}
                  onChange={e => setDeliveryAddress(e.target.value)}
                  autoFocus
                />
              </div>

              <div className="form-group">
                <label>же картадан тандаңыз</label>
                <MapPicker
                  value={deliveryCoords}
                  markerColor="red"
                  height="220px"
                  onChange={(coords, addr) => {
                    setDeliveryCoords(coords);
                    if (!deliveryAddress) setDeliveryAddress(addr);
                  }}
                />
              </div>

              {orderError && <div className="form-error" style={{ marginBottom: 12 }}>{orderError}</div>}

              <div style={{ display: 'flex', gap: 10 }}>
                <button className="btn btn-ghost" style={{ flex: 1 }} onClick={() => setShowDeliveryForm(false)}>
                  Артка
                </button>
                <button className="btn btn-primary" style={{ flex: 2 }} onClick={submitEnterpriseOrder} disabled={submitting}>
                  {submitting ? <span className="spinner" /> : `Заказ бер • ${cartTotal.toFixed(0)} сом`}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  // ── Create Regular Order (Wizard) ────────────────────────────────────────
  if (step === 'create-order') {
    const STEP_LABELS = ['Категория', 'Кайдан', 'Кайда', 'Сүрөттөмө'];

    function goBack() {
      setOrderError('');
      if (orderStep === 1) { setStep('home'); }
      else setOrderStep((orderStep - 1) as OrderStep);
    }

    function goNext() {
      setOrderError('');
      if (orderStep === 1) {
        setOrderStep(2);
      } else if (orderStep === 2) {
        if (!fromAddress.trim()) { setOrderError('Башталгыч дарек жазыңыз'); return; }
        setOrderStep(3);
      } else if (orderStep === 3) {
        if (!toAddress.trim()) { setOrderError('Аяктоо дарегин жазыңыз'); return; }
        setOrderStep(4);
      } else if (orderStep === 4) {
        submitRegularOrder();
      }
    }

    return (
      <div>
        <div className="page-back">
          <button className="btn btn-ghost btn-sm" onClick={goBack}>← Артка</button>
          <h1 className="page-title" style={{ margin: 0 }}>Жаңы заказ</h1>
        </div>

        {/* Progress bar */}
        <div className="wizard-progress">
          {STEP_LABELS.map((label, i) => (
            <div key={i} className={`wizard-step ${i + 1 <= orderStep ? 'active' : ''} ${i + 1 < orderStep ? 'done' : ''}`}>
              <div className="wizard-step-dot">{i + 1 < orderStep ? '✓' : i + 1}</div>
              <span className="wizard-step-label">{label}</span>
              {i < STEP_LABELS.length - 1 && <div className="wizard-step-line" />}
            </div>
          ))}
        </div>

        <div className="card wizard-card">
          {/* Step 1: Category */}
          {orderStep === 1 && (
            <div>
              <div className="section-title" style={{ marginBottom: 20 }}>Категорияны тандаңыз</div>
              <div className="category-grid">
                {CATEGORIES.map(cat => (
                  <div
                    key={cat.value}
                    className={`category-card ${category === cat.value ? 'selected' : ''}`}
                    onClick={() => setCategory(cat.value)}
                  >
                    <span className="category-icon">{cat.icon}</span>
                    <span className="category-label">{cat.label}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Step 2: From address */}
          {orderStep === 2 && (
            <div>
              <div className="section-title" style={{ marginBottom: 20 }}>Кайдан алуу керек?</div>
              <div className="form-group">
                <label>Дарек</label>
                <input
                  placeholder="Башталгыч дарек"
                  value={fromAddress}
                  onChange={e => setFromAddress(e.target.value)}
                  autoFocus
                />
              </div>
              <MapPicker
                value={fromCoords}
                markerColor="green"
                height="280px"
                onChange={(coords, addr) => { setFromCoords(coords); if (!fromAddress) setFromAddress(addr); }}
              />
              <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 8 }}>
                Картага таптап же жогоруда адрести жазыңыз
              </div>
            </div>
          )}

          {/* Step 3: To address */}
          {orderStep === 3 && (
            <div>
              <div className="section-title" style={{ marginBottom: 20 }}>Кайда жеткирүү керек?</div>
              <div className="form-group">
                <label>Дарек</label>
                <input
                  placeholder="Аяктоо дареги"
                  value={toAddress}
                  onChange={e => setToAddress(e.target.value)}
                  autoFocus
                />
              </div>
              <MapPicker
                value={toCoords}
                markerColor="red"
                height="280px"
                onChange={(coords, addr) => { setToCoords(coords); if (!toAddress) setToAddress(addr); }}
              />
              <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 8 }}>
                Картага таптап же жогоруда адрести жазыңыз
              </div>
              {fromCoords && toCoords && (
                <div className="distance-badge" style={{ marginTop: 12 }}>
                  Аралык: ~{calcDistance().toFixed(1)} км
                </div>
              )}
            </div>
          )}

          {/* Step 4: Description + review */}
          {orderStep === 4 && (
            <div>
              <div className="section-title" style={{ marginBottom: 20 }}>Эмнени жеткирүү керек?</div>
              <div className="form-group">
                <label>Сүрөттөмө</label>
                <textarea
                  placeholder="Мисалы: 2 кг алма, сумка, документ..."
                  rows={4}
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  autoFocus
                />
              </div>

              {/* Summary */}
              <div className="wizard-summary">
                <div className="wizard-summary-row">
                  <span>Категория</span><strong>{category}</strong>
                </div>
                <div className="wizard-summary-row">
                  <span>Кайдан</span><strong>{fromAddress || '—'}</strong>
                </div>
                <div className="wizard-summary-row">
                  <span>Кайда</span><strong>{toAddress || '—'}</strong>
                </div>
                {fromCoords && toCoords && (
                  <div className="wizard-summary-row">
                    <span>Аралык</span><strong>~{calcDistance().toFixed(1)} км</strong>
                  </div>
                )}
              </div>
            </div>
          )}

          {orderError && <div className="form-error" style={{ marginTop: 12 }}>{orderError}</div>}

          <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
            <button className="btn btn-ghost" style={{ flex: 1 }} onClick={goBack}>
              Артка
            </button>
            <button className="btn btn-primary" style={{ flex: 2 }} onClick={goNext} disabled={submitting}>
              {submitting
                ? <span className="spinner" />
                : orderStep === 4 ? 'Заказ берүү' : 'Кийинки →'}
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ── Home ─────────────────────────────────────────────────────────────────
  return (
    <div>
      <div className="home-hero">
        <div className="home-hero-text">
          <h1>Кош келиңиз! 👋</h1>
          <p>Заказ берүү же ишкана менюсунан тандаңыз</p>
        </div>
        <button className="btn btn-primary" onClick={() => { setOrderStep(1); setOrderError(''); setStep('create-order'); }}>
          + Жаңы заказ
        </button>
      </div>

      <div className="section-title">🏪 Ишканалар</div>
      {loading ? (
        <div style={{ textAlign: 'center', padding: 60 }}><span className="spinner spinner-dark" /></div>
      ) : enterprises.length === 0 ? (
        <div className="empty-state"><p>Ишканалар жок</p></div>
      ) : (
        <div className="enterprise-grid">
          {enterprises.map(e => (
            <div key={e.id} className="enterprise-card" onClick={() => openEnterprise(e)}>
              <div className="enterprise-avatar">{e.name.charAt(0)}</div>
              <div className="enterprise-info">
                <div className="enterprise-name">{e.name}</div>
                {e.category && <div className="enterprise-category">{e.category}</div>}
                {e.address && <div className="enterprise-address">📍 {e.address}</div>}
              </div>
              <span className="enterprise-arrow">›</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
