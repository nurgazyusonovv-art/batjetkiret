import { useState, useEffect } from 'react';
import { ShoppingCart, Plus, Minus, Package, X, CheckCircle, MapPin, UtensilsCrossed, Bike } from 'lucide-react';
import { productsService, Category, Product } from '../services/products';
import { ordersService } from '../services/orders';
import MapPicker from '../components/MapPicker';
import './CreateOrderPage.css';

interface CartItem { product: Product; quantity: number; }
type OrderType = 'delivery' | 'dine_in';

export default function CreateOrderPage() {
  const [orderType, setOrderType] = useState<OrderType>('delivery');
  const [categories, setCategories] = useState<Category[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCat, setSelectedCat] = useState<number | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);

  // delivery fields
  const [customerPhone, setCustomerPhone] = useState('');
  const [toAddress, setToAddress] = useState('');
  const [toCoords, setToCoords] = useState<{ lat: number; lng: number } | null>(null);

  // dine_in fields
  const [tableNumber, setTableNumber] = useState('');
  const [dinePhone, setDinePhone] = useState('');  // optional for dine_in

  const [note, setNote] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [showMap, setShowMap] = useState(false);

  useEffect(() => {
    Promise.all([productsService.getCategories(), productsService.getProducts(undefined, true)])
      .then(([cats, prods]) => { setCategories(cats); setProducts(prods); })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const filteredProducts = selectedCat === null ? products : products.filter(p => p.category_id === selectedCat);

  const addToCart = (product: Product) => {
    setCart(prev => {
      const existing = prev.find(i => i.product.id === product.id);
      if (existing) return prev.map(i => i.product.id === product.id ? { ...i, quantity: i.quantity + 1 } : i);
      return [...prev, { product, quantity: 1 }];
    });
  };

  const updateQty = (productId: number, delta: number) => {
    setCart(prev => prev.map(i => i.product.id === productId ? { ...i, quantity: i.quantity + delta } : i).filter(i => i.quantity > 0));
  };

  const removeFromCart = (productId: number) => setCart(prev => prev.filter(i => i.product.id !== productId));

  const total = cart.reduce((sum, i) => sum + i.product.price * i.quantity, 0);
  const cartQty = (productId: number) => cart.find(i => i.product.id === productId)?.quantity ?? 0;

  const resetForm = () => {
    setCart([]);
    setCustomerPhone('');
    setToAddress('');
    setToCoords(null);
    setTableNumber('');
    setDinePhone('');
    setNote('');
  };

  const handleSubmit = async () => {
    setError('');
    if (cart.length === 0) { setError('Жок дегенде бир товар тандаңыз'); return; }

    if (orderType === 'delivery') {
      if (!customerPhone.trim()) { setError('Кардардын телефону талап кылынат'); return; }
      if (!toAddress.trim()) { setError('Жеткирүү дареги талап кылынат'); return; }
    }

    setSubmitting(true);
    try {
      await ordersService.createLocalOrder({
        order_type: orderType,
        customer_phone: orderType === 'delivery' ? customerPhone.trim() : (dinePhone.trim() || undefined),
        to_address: orderType === 'delivery' ? toAddress.trim() : undefined,
        to_lat: orderType === 'delivery' ? toCoords?.lat : undefined,
        to_lng: orderType === 'delivery' ? toCoords?.lng : undefined,
        table_number: orderType === 'dine_in' ? (tableNumber.trim() || undefined) : undefined,
        items: cart.map(i => ({ product_id: i.product.id, quantity: i.quantity })),
        note: note.trim() || undefined,
      });
      setSuccess(true);
      resetForm();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setError(err?.response?.data?.detail ?? 'Ката кетти. Кайра аракет кылыңыз.');
    } finally {
      setSubmitting(false);
    }
  };

  if (success) return (
    <div className="create-order-success">
      <CheckCircle size={64} color="#4f46e5" />
      <h2>{orderType === 'dine_in' ? 'Заказ кабыл алынды!' : 'Заказ түзүлдү!'}</h2>
      <p>{orderType === 'dine_in' ? 'Ошол столго даярдалып жатат' : 'Курьер жөнөтүлүп жатат'}</p>
      <button className="ep-btn-primary-sm" onClick={() => setSuccess(false)}>Жаңы заказ</button>
    </div>
  );

  return (
    <div className="create-order-page">
      <div className="co-header">
        <div className="co-title"><ShoppingCart size={22} /><h1>Жаңы заказ түзүү</h1></div>
      </div>

      <div className="co-layout">
        {/* Products selector */}
        <div className="co-products-section">
          <div className="co-cat-tabs">
            <button className={"co-cat-tab" + (selectedCat === null ? ' active' : '')} onClick={() => setSelectedCat(null)}>Баардыгы</button>
            {categories.filter(c => c.is_active).map(c => (
              <button key={c.id} className={"co-cat-tab" + (selectedCat === c.id ? ' active' : '')} onClick={() => setSelectedCat(c.id)}>{c.name}</button>
            ))}
          </div>

          {loading ? <div className="co-loading">Жүктөлүүдө...</div> : (
            <div className="co-products-grid">
              {filteredProducts.map(p => {
                const qty = cartQty(p.id);
                return (
                  <div key={p.id} className={"co-product-card" + (qty > 0 ? ' in-cart' : '')}>
                    <div className="co-product-info">
                      <span className="co-product-name">{p.name}</span>
                      {p.description && <span className="co-product-desc">{p.description}</span>}
                      <span className="co-product-price">{p.price.toFixed(0)} сом</span>
                    </div>
                    <div className="co-product-ctrl">
                      {qty === 0 ? (
                        <button className="co-add-btn" onClick={() => addToCart(p)}><Plus size={16} /></button>
                      ) : (
                        <div className="co-qty-ctrl">
                          <button onClick={() => updateQty(p.id, -1)}><Minus size={13} /></button>
                          <span>{qty}</span>
                          <button onClick={() => updateQty(p.id, 1)}><Plus size={13} /></button>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
              {filteredProducts.length === 0 && (
                <div className="co-empty"><Package size={32} opacity={0.2} /><p>Товар жок</p></div>
              )}
            </div>
          )}
        </div>

        {/* Order form / Cart */}
        <aside className="co-order-panel">
          <div className="co-panel-title"><ShoppingCart size={16} />Заказ</div>

          {/* Order type selector */}
          <div className="co-type-selector">
            <button
              className={"co-type-btn" + (orderType === 'dine_in' ? ' active' : '')}
              onClick={() => setOrderType('dine_in')}
            >
              <UtensilsCrossed size={18} />
              <span>Ичиндеги</span>
              <small>Стол заказы</small>
            </button>
            <button
              className={"co-type-btn" + (orderType === 'delivery' ? ' active' : '')}
              onClick={() => setOrderType('delivery')}
            >
              <Bike size={18} />
              <span>Жеткирүү</span>
              <small>Доставка</small>
            </button>
          </div>

          {/* Dine-in fields */}
          {orderType === 'dine_in' && (
            <>
              <div className="co-form-group">
                <label>Стол номери</label>
                <input value={tableNumber} onChange={e => setTableNumber(e.target.value)} placeholder="Мис: 3, А1, VIP..." />
              </div>
              <div className="co-form-group">
                <label>Телефон (милдеттүү эмес)</label>
                <input value={dinePhone} onChange={e => setDinePhone(e.target.value)} placeholder="+996XXXXXXXXX" />
              </div>
            </>
          )}

          {/* Delivery fields */}
          {orderType === 'delivery' && (
            <>
              <div className="co-form-group">
                <label>Кардардын телефону *</label>
                <input value={customerPhone} onChange={e => setCustomerPhone(e.target.value)} placeholder="+996XXXXXXXXX" />
              </div>
              <div className="co-form-group">
                <label>Жеткирүү дареги *</label>
                <div className="co-address-row">
                  <input
                    value={toAddress}
                    onChange={e => setToAddress(e.target.value)}
                    placeholder="Кардардын дареги"
                    className="co-address-input"
                  />
                  <button type="button" className="co-map-btn" onClick={() => setShowMap(true)} title="Картадан тандоо">
                    <MapPin size={16} />
                  </button>
                </div>
                {toCoords ? (
                  <div className="co-coords-badge">
                    <MapPin size={11} />
                    {toCoords.lat.toFixed(5)}, {toCoords.lng.toFixed(5)}
                    <button type="button" className="co-coords-clear" onClick={() => setToCoords(null)} title="Координаттарды тазалоо">
                      <X size={11} />
                    </button>
                  </div>
                ) : toAddress.trim() ? (
                  <div className="co-coords-hint">
                    <MapPin size={11} />
                    Так жер үчүн картадан тандаңыз
                  </div>
                ) : null}
              </div>
            </>
          )}

          {/* Cart items */}
          <div className="co-cart">
            {cart.length === 0 ? (
              <div className="co-cart-empty">Товар тандаңыз</div>
            ) : (
              cart.map(item => (
                <div key={item.product.id} className="co-cart-item">
                  <div className="co-cart-item-info">
                    <span className="co-cart-name">{item.product.name}</span>
                    <span className="co-cart-subtotal">{(item.product.price * item.quantity).toFixed(0)} сом</span>
                  </div>
                  <div className="co-cart-ctrl">
                    <button onClick={() => updateQty(item.product.id, -1)}><Minus size={12} /></button>
                    <span>{item.quantity}</span>
                    <button onClick={() => updateQty(item.product.id, 1)}><Plus size={12} /></button>
                    <button className="co-cart-remove" onClick={() => removeFromCart(item.product.id)}><X size={12} /></button>
                  </div>
                </div>
              ))
            )}
          </div>

          {cart.length > 0 && (
            <div className="co-total">
              <span>Жалпы:</span>
              <span className="co-total-value">{total.toFixed(0)} сом</span>
            </div>
          )}

          <div className="co-form-group">
            <label>Эскертүү (милдеттүү эмес)</label>
            <textarea value={note} onChange={e => setNote(e.target.value)} placeholder="Кошумча маалымат..." rows={2} />
          </div>

          {error && <div className="co-error">{error}</div>}

          <button className="co-submit-btn" onClick={handleSubmit} disabled={submitting || cart.length === 0}>
            {submitting ? 'Жөнөтүлүүдө...' : (orderType === 'dine_in' ? "Заказ алуу — " : "Жеткирүү — ") + total.toFixed(0) + " сом"}
          </button>
        </aside>
      </div>

      {showMap && (
        <MapPicker
          initialAddress={toAddress}
          initialLat={toCoords?.lat}
          initialLng={toCoords?.lng}
          onConfirm={(addr, lat, lng) => { setToAddress(addr); setToCoords(lat !== null && lng !== null ? { lat, lng } : null); setShowMap(false); }}
          onClose={() => setShowMap(false)}
        />
      )}
    </div>
  );
}
