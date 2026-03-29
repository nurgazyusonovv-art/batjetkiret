import { useEffect, useState, useMemo } from 'react';
import { Settings, Save, Wallet, Search, ChevronLeft, ChevronRight, RefreshCw, Truck } from 'lucide-react';
import { settingsService, SETTING_KEYS } from '@/services/settings';
import { userService } from '@/services/users';
import { User } from '@/types';
import './SettingsPage.css';

const ITEMS_PER_PAGE = 10;

export default function SettingsPage() {
  // ── System settings ──────────────────────────────────────────────────────
  const [fee, setFee] = useState('5');
  const [feeDesc, setFeeDesc] = useState('');
  const [feeSaving, setFeeSaving] = useState(false);
  const [feeMsg, setFeeMsg] = useState('');

  // ── Delivery pricing ─────────────────────────────────────────────────────
  const [basePrice, setBasePrice] = useState('80');
  const [perKm, setPerKm] = useState('20');
  const [priceSaving, setPriceSaving] = useState(false);
  const [priceMsg, setPriceMsg] = useState('');

  // ── Balance top-up ────────────────────────────────────────────────────────
  const [users, setUsers] = useState<User[]>([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [topupLoading, setTopupLoading] = useState(false);
  const [topupMsg, setTopupMsg] = useState('');

  useEffect(() => {
    loadSettings();
    loadUsers();
  }, []);

  const loadSettings = async () => {
    try {
      const data = await settingsService.getSettings();
      if (data[SETTING_KEYS.COURIER_FEE]) {
        setFee(data[SETTING_KEYS.COURIER_FEE].value);
        setFeeDesc(data[SETTING_KEYS.COURIER_FEE].description);
      }
      if (data[SETTING_KEYS.DELIVERY_BASE]) setBasePrice(data[SETTING_KEYS.DELIVERY_BASE].value);
      if (data[SETTING_KEYS.DELIVERY_PER_KM]) setPerKm(data[SETTING_KEYS.DELIVERY_PER_KM].value);
    } catch { /* silent */ }
  };

  const loadUsers = async () => {
    setUsersLoading(true);
    try {
      const data = await userService.getUsers({ limit: 500 });
      setUsers(data);
    } catch { /* silent */ } finally {
      setUsersLoading(false);
    }
  };

  const saveFee = async () => {
    const val = parseFloat(fee);
    if (isNaN(val) || val < 0) { setFeeMsg('Туура сан киргизиңиз'); return; }
    setFeeSaving(true);
    setFeeMsg('');
    try {
      await settingsService.updateSetting(SETTING_KEYS.COURIER_FEE, String(val));
      setFeeMsg('✓ Сакталды');
    } catch {
      setFeeMsg('Сактоодо ката кетти');
    } finally {
      setFeeSaving(false);
    }
  };

  const saveDeliveryPricing = async () => {
    const base = parseFloat(basePrice);
    const km = parseFloat(perKm);
    if (isNaN(base) || base < 0 || isNaN(km) || km < 0) {
      setPriceMsg('Туура сан киргизиңиз');
      return;
    }
    setPriceSaving(true);
    setPriceMsg('');
    try {
      await Promise.all([
        settingsService.updateSetting(SETTING_KEYS.DELIVERY_BASE, String(base)),
        settingsService.updateSetting(SETTING_KEYS.DELIVERY_PER_KM, String(km)),
      ]);
      setPriceMsg('✓ Сакталды');
    } catch {
      setPriceMsg('Сактоодо ката кетти');
    } finally {
      setPriceSaving(false);
    }
  };

  const deliveryPreview = useMemo(() => {
    const base = parseFloat(basePrice) || 0;
    const km = parseFloat(perKm) || 0;
    return [1, 3, 5, 10].map(d => ({ km: d, price: Math.round(base + d * km) }));
  }, [basePrice, perKm]);

  const filteredUsers = useMemo(() => {
    if (!search.trim()) return users;
    const q = search.toLowerCase();
    return users.filter(u =>
      u.phone.includes(q) ||
      (u.name || '').toLowerCase().includes(q) ||
      String(u.id).includes(q)
    );
  }, [users, search]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / ITEMS_PER_PAGE));
  const paginatedUsers = useMemo(() => {
    const start = (page - 1) * ITEMS_PER_PAGE;
    return filteredUsers.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredUsers, page]);

  const handleTopup = async () => {
    if (!selectedUser) { setTopupMsg('Колдонуучу тандаңыз'); return; }
    const amt = parseFloat(amount);
    if (isNaN(amt) || amt <= 0) { setTopupMsg('Туура сумма киргизиңиз'); return; }
    setTopupLoading(true);
    setTopupMsg('');
    try {
      const res = await settingsService.topupUserBalance(selectedUser.id, amt, note);
      setTopupMsg(`✓ ${selectedUser.name || selectedUser.phone} балансына ${amt} сом кошулду. Жаңы баланс: ${res.balance} сом`);
      // update local user balance
      setUsers(prev => prev.map(u => u.id === selectedUser.id ? { ...u, balance: res.balance } : u));
      setSelectedUser(prev => prev ? { ...prev, balance: res.balance } : null);
      setAmount('');
      setNote('');
    } catch {
      setTopupMsg('Баланс кошуу мүмкүн болгон жок');
    } finally {
      setTopupLoading(false);
    }
  };

  return (
    <div className="sp-page">
      {/* ── Section 1: Courier service fee ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <Settings size={18} />
          Тутум жөндөөлөрү
        </div>

        <div className="sp-fee-card">
          <div className="sp-fee-info">
            <div className="sp-fee-label">Курьерден алынуучу комиссия</div>
            <div className="sp-fee-desc">{feeDesc || 'Ар бир аяктаган заказ үчүн курьердин балансынан алынат'}</div>
          </div>
          <div className="sp-fee-input-row">
            <div className="sp-fee-input-wrap">
              <input
                type="number"
                min="0"
                step="0.5"
                value={fee}
                onChange={e => { setFee(e.target.value); setFeeMsg(''); }}
                className="sp-fee-input"
                placeholder="0"
              />
              <span className="sp-fee-unit">сом</span>
            </div>
            <button className="sp-save-btn" onClick={saveFee} disabled={feeSaving}>
              <Save size={15} />
              {feeSaving ? 'Сакталууда...' : 'Сактоо'}
            </button>
          </div>
          {feeMsg && (
            <div className={`sp-fee-msg ${feeMsg.startsWith('✓') ? 'success' : 'error'}`}>
              {feeMsg}
            </div>
          )}
        </div>
      </div>

      {/* ── Section 2: Delivery pricing ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <Truck size={18} />
          Жеткирүү акысынын формуласы
        </div>

        <div className="sp-delivery-pricing">
          <div className="sp-delivery-formula">
            <div className="sp-formula-field">
              <div className="sp-fee-label">Башкы баа (сом)</div>
              <div className="sp-fee-desc">Заказдын аралыгынан көз карандысыз алынуучу туруктуу баа</div>
              <div className="sp-fee-input-wrap" style={{ marginTop: 8 }}>
                <input
                  type="number" min="0" step="1"
                  value={basePrice}
                  onChange={e => { setBasePrice(e.target.value); setPriceMsg(''); }}
                  className="sp-fee-input"
                  placeholder="80"
                />
                <span className="sp-fee-unit">сом</span>
              </div>
            </div>

            <div className="sp-formula-plus">+</div>

            <div className="sp-formula-field">
              <div className="sp-fee-label">1 км үчүн баа (сом)</div>
              <div className="sp-fee-desc">Ар бир километр үчүн кошулуучу сумма</div>
              <div className="sp-fee-input-wrap" style={{ marginTop: 8 }}>
                <input
                  type="number" min="0" step="1"
                  value={perKm}
                  onChange={e => { setPerKm(e.target.value); setPriceMsg(''); }}
                  className="sp-fee-input"
                  placeholder="20"
                />
                <span className="sp-fee-unit">сом/км</span>
              </div>
            </div>

            <div className="sp-formula-plus">×</div>
            <div className="sp-formula-km-label">км</div>
          </div>

          <div className="sp-delivery-preview">
            <div className="sp-preview-title">Мисалдар:</div>
            {deliveryPreview.map(({ km, price }) => (
              <div key={km} className="sp-preview-row">
                <span>{km} км</span>
                <span className="sp-preview-price">{price} сом</span>
              </div>
            ))}
          </div>
        </div>

        <div className="sp-fee-input-row" style={{ marginTop: 16 }}>
          <button className="sp-save-btn" onClick={saveDeliveryPricing} disabled={priceSaving}>
            <Save size={15} />
            {priceSaving ? 'Сакталууда...' : 'Сактоо'}
          </button>
          {priceMsg && (
            <div className={`sp-fee-msg ${priceMsg.startsWith('✓') ? 'success' : 'error'}`}>
              {priceMsg}
            </div>
          )}
        </div>
      </div>

      {/* ── Section 3: Balance top-up ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <Wallet size={18} />
          Колдонуучуга баланс кошуу
        </div>

        <div className="sp-topup-layout">
          {/* User picker */}
          <div className="sp-user-picker">
            <div className="sp-picker-header">
              <div className="sp-picker-search">
                <Search size={15} />
                <input
                  placeholder="Аты же телефон..."
                  value={search}
                  onChange={e => { setSearch(e.target.value); setPage(1); }}
                />
              </div>
              <button className="sp-refresh-btn" onClick={loadUsers} title="Жаңылоо">
                <RefreshCw size={14} />
              </button>
            </div>

            {usersLoading ? (
              <div className="sp-picker-loading">Жүктөлүүдө...</div>
            ) : (
              <>
                <div className="sp-user-list">
                  {paginatedUsers.map(u => (
                    <div
                      key={u.id}
                      className={`sp-user-row ${selectedUser?.id === u.id ? 'selected' : ''}`}
                      onClick={() => { setSelectedUser(u); setTopupMsg(''); }}
                    >
                      <div className="sp-user-main">
                        <span className="sp-user-name">{u.name || u.phone}</span>
                        <span className={`sp-user-role sp-role-${u.role}`}>
                          {u.role === 'courier' ? 'Курьер' : u.role === 'admin' ? 'Админ' : 'Колдонуучу'}
                        </span>
                      </div>
                      <div className="sp-user-sub">
                        <span>{u.phone}</span>
                        <span className="sp-user-balance">{u.balance} с</span>
                      </div>
                    </div>
                  ))}
                  {filteredUsers.length === 0 && (
                    <div className="sp-picker-empty">Колдонуучу табылган жок</div>
                  )}
                </div>

                {totalPages > 1 && (
                  <div className="sp-picker-pagination">
                    <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
                      <ChevronLeft size={14} />
                    </button>
                    <span>{page}/{totalPages}</span>
                    <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}>
                      <ChevronRight size={14} />
                    </button>
                  </div>
                )}
              </>
            )}
          </div>

          {/* Top-up form */}
          <div className="sp-topup-form">
            {selectedUser ? (
              <div className="sp-selected-user">
                <div className="sp-selected-name">{selectedUser.name || selectedUser.phone}</div>
                <div className="sp-selected-phone">{selectedUser.phone}</div>
                <div className="sp-selected-balance">
                  Учурдагы баланс: <strong>{selectedUser.balance} сом</strong>
                </div>
              </div>
            ) : (
              <div className="sp-no-selection">
                <Wallet size={32} opacity={0.2} />
                <p>Сол жактан колдонуучу тандаңыз</p>
              </div>
            )}

            <label className="sp-form-label">
              Кошулуучу сумма (сом)
              <input
                type="number"
                min="1"
                step="1"
                value={amount}
                onChange={e => { setAmount(e.target.value); setTopupMsg(''); }}
                placeholder="Мис: 500"
                className="sp-form-input"
                disabled={!selectedUser}
              />
            </label>

            <label className="sp-form-label">
              Эскертүү (милдеттүү эмес)
              <input
                type="text"
                value={note}
                onChange={e => setNote(e.target.value)}
                placeholder="Себеп же комментарий..."
                className="sp-form-input"
                disabled={!selectedUser}
              />
            </label>

            <button
              className="sp-topup-btn"
              onClick={handleTopup}
              disabled={topupLoading || !selectedUser || !amount}
            >
              <Wallet size={16} />
              {topupLoading ? 'Кошулууда...' : 'Баланс кошуу'}
            </button>

            {topupMsg && (
              <div className={`sp-topup-msg ${topupMsg.startsWith('✓') ? 'success' : 'error'}`}>
                {topupMsg}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
