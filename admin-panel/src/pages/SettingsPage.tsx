import { useEffect, useState, useMemo } from 'react';
import { Settings, Save, Wallet, Search, ChevronLeft, ChevronRight, RefreshCw, Truck, Trash2, AlertTriangle, MessageCircle } from 'lucide-react';
import { settingsService, SETTING_KEYS } from '@/services/settings';
import { userService } from '@/services/users';
import { orderService } from '@/services/orders';
import { User } from '@/types';
import './SettingsPage.css';

const ITEMS_PER_PAGE = 10;

export default function SettingsPage() {
  // ── Courier service fee ───────────────────────────────────────────────────
  const [fee, setFee] = useState('5');
  const [feeSaving, setFeeSaving] = useState(false);
  const [feeMsg, setFeeMsg] = useState('');

  // ── User service fee ──────────────────────────────────────────────────────
  const [userFee, setUserFee] = useState('5');
  const [userFeeSaving, setUserFeeSaving] = useState(false);
  const [userFeeMsg, setUserFeeMsg] = useState('');

  // ── Courier cancel penalty ────────────────────────────────────────────────
  const [penalty, setPenalty] = useState('10');
  const [penaltySaving, setPenaltySaving] = useState(false);
  const [penaltyMsg, setPenaltyMsg] = useState('');

  // ── Delivery pricing ─────────────────────────────────────────────────────
  const [basePrice, setBasePrice] = useState('80');
  const [perKm, setPerKm] = useState('20');
  const [priceSaving, setPriceSaving] = useState(false);
  const [priceMsg, setPriceMsg] = useState('');

  // ── Taxi pricing ──────────────────────────────────────────────────────────
  const [taxiBase, setTaxiBase] = useState('100');
  const [taxiPerKm, setTaxiPerKm] = useState('30');
  const [taxiSaving, setTaxiSaving] = useState(false);
  const [taxiMsg, setTaxiMsg] = useState('');

  // ── Contact info ──────────────────────────────────────────────────────────
  const [telegram, setTelegram] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [contactSaving, setContactSaving] = useState(false);
  const [contactMsg, setContactMsg] = useState('');

  // ── Danger zone ───────────────────────────────────────────────────────────
  const [clearLoading, setClearLoading] = useState(false);
  const [clearMsg, setClearMsg] = useState('');

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
      if (data[SETTING_KEYS.COURIER_FEE]) setFee(data[SETTING_KEYS.COURIER_FEE].value);
      if (data[SETTING_KEYS.USER_FEE]) setUserFee(data[SETTING_KEYS.USER_FEE].value);
      if (data[SETTING_KEYS.COURIER_CANCEL_PENALTY]) setPenalty(data[SETTING_KEYS.COURIER_CANCEL_PENALTY].value);
      if (data[SETTING_KEYS.DELIVERY_BASE]) setBasePrice(data[SETTING_KEYS.DELIVERY_BASE].value);
      if (data[SETTING_KEYS.DELIVERY_PER_KM]) setPerKm(data[SETTING_KEYS.DELIVERY_PER_KM].value);
      if (data[SETTING_KEYS.TAXI_BASE]) setTaxiBase(data[SETTING_KEYS.TAXI_BASE].value);
      if (data[SETTING_KEYS.TAXI_PER_KM]) setTaxiPerKm(data[SETTING_KEYS.TAXI_PER_KM].value);
      if (data[SETTING_KEYS.CONTACT_TELEGRAM]) setTelegram(data[SETTING_KEYS.CONTACT_TELEGRAM].value);
      if (data[SETTING_KEYS.CONTACT_WHATSAPP]) setWhatsapp(data[SETTING_KEYS.CONTACT_WHATSAPP].value);
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

  const saveUserFee = async () => {
    const val = parseFloat(userFee);
    if (isNaN(val) || val < 0) { setUserFeeMsg('Туура сан киргизиңиз'); return; }
    setUserFeeSaving(true);
    setUserFeeMsg('');
    try {
      await settingsService.updateSetting(SETTING_KEYS.USER_FEE, String(val));
      setUserFeeMsg('✓ Сакталды');
    } catch {
      setUserFeeMsg('Сактоодо ката кетти');
    } finally {
      setUserFeeSaving(false);
    }
  };

  const savePenalty = async () => {
    const val = parseFloat(penalty);
    if (isNaN(val) || val < 0) { setPenaltyMsg('Туура сан киргизиңиз'); return; }
    setPenaltySaving(true);
    setPenaltyMsg('');
    try {
      await settingsService.updateSetting(SETTING_KEYS.COURIER_CANCEL_PENALTY, String(val));
      setPenaltyMsg('✓ Сакталды');
    } catch {
      setPenaltyMsg('Сактоодо ката кетти');
    } finally {
      setPenaltySaving(false);
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

  const saveTaxiPricing = async () => {
    const base = parseFloat(taxiBase);
    const km = parseFloat(taxiPerKm);
    if (isNaN(base) || base < 0 || isNaN(km) || km < 0) {
      setTaxiMsg('Туура сан киргизиңиз');
      return;
    }
    setTaxiSaving(true);
    setTaxiMsg('');
    try {
      await Promise.all([
        settingsService.updateSetting(SETTING_KEYS.TAXI_BASE, String(base)),
        settingsService.updateSetting(SETTING_KEYS.TAXI_PER_KM, String(km)),
      ]);
      setTaxiMsg('✓ Сакталды');
    } catch {
      setTaxiMsg('Сактоодо ката кетти');
    } finally {
      setTaxiSaving(false);
    }
  };

  const saveContact = async () => {
    setContactSaving(true);
    setContactMsg('');
    try {
      await Promise.all([
        settingsService.updateSetting(SETTING_KEYS.CONTACT_TELEGRAM, telegram.trim()),
        settingsService.updateSetting(SETTING_KEYS.CONTACT_WHATSAPP, whatsapp.trim()),
      ]);
      setContactMsg('✓ Сакталды');
    } catch {
      setContactMsg('Сактоодо ката кетти');
    } finally {
      setContactSaving(false);
    }
  };

  const deliveryPreview = useMemo(() => {
    const base = parseFloat(basePrice) || 0;
    const km = parseFloat(perKm) || 0;
    return [1, 3, 5, 10].map(d => ({ km: d, price: Math.round(base + d * km) }));
  }, [basePrice, perKm]);

  const taxiPreview = useMemo(() => {
    const base = parseFloat(taxiBase) || 0;
    const km = parseFloat(taxiPerKm) || 0;
    return [1, 3, 5, 10].map(d => ({ km: d, price: Math.round(base + d * km) }));
  }, [taxiBase, taxiPerKm]);

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

  const handleClearAllOrders = async () => {
    if (!confirm('Бардык заказдар өчүрүлөт! Бул аракетти артка кайтаруу мүмкүн эмес.\n\nУланткыңыз келеби?')) return;
    if (!confirm('Акыркы ырастоо: чын эле бардык заказдарды өчүрөсүзбү?')) return;
    setClearLoading(true);
    setClearMsg('');
    try {
      const res = await orderService.clearAllOrders();
      setClearMsg(`✓ ${res.message}`);
    } catch {
      setClearMsg('Ката кетти. Кайра аракет кылыңыз.');
    } finally {
      setClearLoading(false);
    }
  };

  return (
    <div className="sp-page">
      {/* ── Section 1: Commission fees ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <Settings size={18} />
          Тутум жөндөөлөрү — Комиссиялар
        </div>

        <div className="sp-fees-grid">
          {/* Courier fee */}
          <div className="sp-fee-card sp-fee-card--bordered">
            <div className="sp-fee-info">
              <div className="sp-fee-label">🚴 Курьерден алынуучу комиссия</div>
              <div className="sp-fee-desc">Ар бир аяктаган заказ үчүн курьердин балансынан алынат</div>
            </div>
            <div className="sp-fee-input-row">
              <div className="sp-fee-input-wrap">
                <input
                  type="number" min="0" step="0.5"
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
              <div className={`sp-fee-msg ${feeMsg.startsWith('✓') ? 'success' : 'error'}`}>{feeMsg}</div>
            )}
          </div>

          {/* User fee */}
          <div className="sp-fee-card sp-fee-card--bordered">
            <div className="sp-fee-info">
              <div className="sp-fee-label">👤 Колдонуучудан алынуучу комиссия</div>
              <div className="sp-fee-desc">Заказ берген учурда колдонуучунун балансынан алынат</div>
            </div>
            <div className="sp-fee-input-row">
              <div className="sp-fee-input-wrap">
                <input
                  type="number" min="0" step="0.5"
                  value={userFee}
                  onChange={e => { setUserFee(e.target.value); setUserFeeMsg(''); }}
                  className="sp-fee-input"
                  placeholder="0"
                />
                <span className="sp-fee-unit">сом</span>
              </div>
              <button className="sp-save-btn" onClick={saveUserFee} disabled={userFeeSaving}>
                <Save size={15} />
                {userFeeSaving ? 'Сакталууда...' : 'Сактоо'}
              </button>
            </div>
            {userFeeMsg && (
              <div className={`sp-fee-msg ${userFeeMsg.startsWith('✓') ? 'success' : 'error'}`}>{userFeeMsg}</div>
            )}
          </div>

          {/* Cancel penalty */}
          <div className="sp-fee-card sp-fee-card--bordered sp-fee-card--danger">
            <div className="sp-fee-info">
              <div className="sp-fee-label">🚫 Курьер отмена штрафы</div>
              <div className="sp-fee-desc">Курьер кабыл алган заказдан баш тарткандагы штраф суммасы</div>
            </div>
            <div className="sp-fee-input-row">
              <div className="sp-fee-input-wrap">
                <input
                  type="number" min="0" step="1"
                  value={penalty}
                  onChange={e => { setPenalty(e.target.value); setPenaltyMsg(''); }}
                  className="sp-fee-input"
                  placeholder="0"
                />
                <span className="sp-fee-unit">сом</span>
              </div>
              <button className="sp-save-btn sp-save-btn--danger" onClick={savePenalty} disabled={penaltySaving}>
                <Save size={15} />
                {penaltySaving ? 'Сакталууда...' : 'Сактоо'}
              </button>
            </div>
            {penaltyMsg && (
              <div className={`sp-fee-msg ${penaltyMsg.startsWith('✓') ? 'success' : 'error'}`}>{penaltyMsg}</div>
            )}
          </div>
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

      {/* ── Section 3: Taxi pricing ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <Truck size={18} />
          Такси акысынын формуласы
        </div>

        <div className="sp-delivery-pricing">
          <div className="sp-delivery-formula">
            <div className="sp-formula-field">
              <div className="sp-fee-label">Башкы баа (сом)</div>
              <div className="sp-fee-desc">Такси заказынын аралыгынан көз карандысыз туруктуу баа</div>
              <div className="sp-fee-input-wrap" style={{ marginTop: 8 }}>
                <input
                  type="number" min="0" step="1"
                  value={taxiBase}
                  onChange={e => { setTaxiBase(e.target.value); setTaxiMsg(''); }}
                  className="sp-fee-input"
                  placeholder="100"
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
                  value={taxiPerKm}
                  onChange={e => { setTaxiPerKm(e.target.value); setTaxiMsg(''); }}
                  className="sp-fee-input"
                  placeholder="30"
                />
                <span className="sp-fee-unit">сом/км</span>
              </div>
            </div>

            <div className="sp-formula-plus">×</div>
            <div className="sp-formula-km-label">км</div>
          </div>

          <div className="sp-delivery-preview">
            <div className="sp-preview-title">Мисалдар:</div>
            {taxiPreview.map(({ km, price }) => (
              <div key={km} className="sp-preview-row">
                <span>{km} км</span>
                <span className="sp-preview-price">{price} сом</span>
              </div>
            ))}
          </div>
        </div>

        <div className="sp-fee-input-row" style={{ marginTop: 16 }}>
          <button className="sp-save-btn" onClick={saveTaxiPricing} disabled={taxiSaving}>
            <Save size={15} />
            {taxiSaving ? 'Сакталууда...' : 'Сактоо'}
          </button>
          {taxiMsg && (
            <div className={`sp-fee-msg ${taxiMsg.startsWith('✓') ? 'success' : 'error'}`}>
              {taxiMsg}
            </div>
          )}
        </div>
      </div>

      {/* ── Section 4: Balance top-up ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <Wallet size={18} />
          Колдонуучуга баланс кошуу (эскирген, UserDetail бетти колдонуңуз)
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

      {/* ── Section: Contact info ── */}
      <div className="sp-section">
        <div className="sp-section-title">
          <MessageCircle size={18} />
          Администратор байланыш маалыматтары
        </div>
        <p className="sp-section-desc" style={{ marginBottom: 16 }}>
          Колдонуучулар "Администраторго жазуу" баскычын баскандан кийин ушул номерлерге багытталат.
        </p>

        <div className="sp-fees-grid">
          <div className="sp-fee-card sp-fee-card--bordered">
            <div className="sp-fee-info">
              <div className="sp-fee-label">✈️ Telegram username</div>
              <div className="sp-fee-desc">@ белгисисиз жазыңыз (мис: adminname)</div>
            </div>
            <div className="sp-fee-input-row">
              <div className="sp-fee-input-wrap" style={{ flex: 1 }}>
                <span className="sp-fee-unit" style={{ left: 10, right: 'auto' }}>@</span>
                <input
                  type="text"
                  value={telegram}
                  onChange={e => { setTelegram(e.target.value); setContactMsg(''); }}
                  className="sp-fee-input sp-text-input"
                  style={{ paddingLeft: 28 }}
                  placeholder="adminname"
                />
              </div>
            </div>
          </div>

          <div className="sp-fee-card sp-fee-card--bordered">
            <div className="sp-fee-info">
              <div className="sp-fee-label">💬 WhatsApp номери</div>
              <div className="sp-fee-desc">Эл аралык форматта, + жок (мис: 996700123456)</div>
            </div>
            <div className="sp-fee-input-row">
              <div className="sp-fee-input-wrap" style={{ flex: 1 }}>
                <input
                  type="text"
                  value={whatsapp}
                  onChange={e => { setWhatsapp(e.target.value); setContactMsg(''); }}
                  className="sp-fee-input sp-text-input"
                  placeholder="996700123456"
                />
              </div>
            </div>
          </div>
        </div>

        <div className="sp-fee-input-row" style={{ marginTop: 16 }}>
          <button className="sp-save-btn" onClick={saveContact} disabled={contactSaving}>
            <Save size={15} />
            {contactSaving ? 'Сакталууда...' : 'Сактоо'}
          </button>
          {contactMsg && (
            <div className={`sp-fee-msg ${contactMsg.startsWith('✓') ? 'success' : 'error'}`}>
              {contactMsg}
            </div>
          )}
        </div>
      </div>

      {/* ── Danger zone ── */}
      <div className="sp-section sp-danger-section">
        <div className="sp-section-header">
          <AlertTriangle size={18} className="sp-danger-icon" />
          <div>
            <div className="sp-section-title sp-danger-title">Коркунуч аймагы</div>
            <div className="sp-section-desc">Бул аракеттерди артка кайтаруу мүмкүн эмес. Абайлап колдонуңуз.</div>
          </div>
        </div>

        <div className="sp-danger-card">
          <div className="sp-danger-card-info">
            <div className="sp-danger-card-title">Бардык заказдарды тазалоо</div>
            <div className="sp-danger-card-desc">
              Системадагы бардык заказдар, чат билдирүүлөрү, статус тарыхы жана рейтингдер өчүрүлөт.
            </div>
          </div>
          <button
            className="sp-danger-btn"
            onClick={handleClearAllOrders}
            disabled={clearLoading}
          >
            <Trash2 size={15} />
            {clearLoading ? 'Өчүрүлүүдө...' : 'Бардыгын тазалоо'}
          </button>
        </div>

        {clearMsg && (
          <div className={`sp-topup-msg ${clearMsg.startsWith('✓') ? 'success' : 'error'}`}>
            {clearMsg}
          </div>
        )}
      </div>
    </div>
  );
}
