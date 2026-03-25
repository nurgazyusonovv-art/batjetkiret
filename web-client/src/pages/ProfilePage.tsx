import { useState, useEffect, useRef, ChangeEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { authService, User } from '../services/auth';
import { topupService, TopupRequest } from '../services/topup';
import './ProfilePage.css';

const TOPUP_STATUS: Record<string, string> = {
  pending: 'Күтүүдө',
  approved: 'Бекитилди',
  rejected: 'Кабыл алынган жок',
};
const TOPUP_COLOR: Record<string, string> = {
  pending: '#f59e0b',
  approved: '#22c55e',
  rejected: '#ef4444',
};

export default function ProfilePage() {
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(authService.getCachedUser());
  const [topups, setTopups] = useState<TopupRequest[]>([]);
  const [loadingTopups, setLoadingTopups] = useState(false);
  const [showTopup, setShowTopup] = useState(false);
  const [showChangePass, setShowChangePass] = useState(false);

  useEffect(() => {
    authService.getMe().then(u => {
      setUser(u);
      localStorage.setItem('user', JSON.stringify(u));
    }).catch(console.error);

    setLoadingTopups(true);
    topupService.getMyRequests()
      .then(setTopups)
      .catch(console.error)
      .finally(() => setLoadingTopups(false));
  }, []);

  function handleLogout() {
    authService.logout();
    navigate('/login');
  }

  if (!user) return null;

  return (
    <div>
      <h1 className="page-title">👤 Профиль</h1>

      <div className="profile-grid">
        <div>
          {/* User card */}
          <div className="card profile-card">
            <div className="profile-avatar">{user.name.charAt(0).toUpperCase()}</div>
            <div className="profile-meta">
              <div className="profile-name">{user.name}</div>
              <div className="profile-phone">📞 {user.phone}</div>
              {user.unique_id && <div className="profile-id">ID: {user.unique_id}</div>}
              {user.is_courier && <span className="badge" style={{ background: '#dbeafe', color: '#1d4ed8', marginTop: 6 }}>🚴 Курьер</span>}
            </div>
          </div>

          {/* Balance card */}
          <div className="card balance-card">
            <div className="balance-header">
              <span>💰 Учурдагы баланс</span>
            </div>
            <div className="balance-amount">{user.balance.toFixed(2)} <span>сом</span></div>
            <button className="btn btn-primary btn-full" onClick={() => setShowTopup(true)}>
              + Балансты толуктоо
            </button>
          </div>

          {/* Actions */}
          <div className="card" style={{ marginTop: 16 }}>
            <div className="section-title">⚙️ Орнотуулар</div>
            <div className="profile-menu">
              <button className="profile-menu-item" onClick={() => setShowChangePass(true)}>
                <span>🔑 Сырсөздү өзгөртүү</span>
                <span>›</span>
              </button>
              <button className="profile-menu-item danger" onClick={handleLogout}>
                <span>🚪 Чыгуу</span>
                <span>›</span>
              </button>
            </div>
          </div>
        </div>

        {/* Topup history */}
        <div>
          <div className="section-title">📋 Толуктоо тарыхы</div>
          {loadingTopups ? (
            <div style={{ textAlign: 'center', padding: 40 }}><span className="spinner spinner-dark" /></div>
          ) : topups.length === 0 ? (
            <div className="empty-state"><p>Толуктоо тарыхы жок</p></div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {topups.map(t => (
                <div key={t.id} className="topup-card">
                  <div className="topup-top">
                    <span className="topup-amount">+{t.amount.toFixed(0)} сом</span>
                    <span className="badge" style={{ background: TOPUP_COLOR[t.status] + '20', color: TOPUP_COLOR[t.status] }}>
                      {TOPUP_STATUS[t.status] || t.status}
                    </span>
                  </div>
                  {t.approved_amount && t.approved_amount !== t.amount && (
                    <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Бекитилген: {t.approved_amount} сом</div>
                  )}
                  {t.admin_note && <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 4 }}>💬 {t.admin_note}</div>}
                  <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 4 }}>
                    {new Date(t.created_at).toLocaleString('ru-RU')}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {showTopup && <TopupModal onClose={() => setShowTopup(false)} onSuccess={(amount) => {
        setShowTopup(false);
        // Add pending to list
        setTopups(prev => [{
          id: Date.now(),
          amount,
          status: 'pending',
          created_at: new Date().toISOString(),
        }, ...prev]);
      }} />}

      {showChangePass && <ChangePasswordModal onClose={() => setShowChangePass(false)} />}
    </div>
  );
}

// ── TopupModal ────────────────────────────────────────────────────────────────
function TopupModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: (amount: number) => void }) {
  const [amount, setAmount] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  function handleFile(e: ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!f.type.startsWith('image/')) { setError('Сүрөт файлын тандаңыз'); return; }
    setFile(f);
    setPreview(URL.createObjectURL(f));
    setError('');
  }

  async function handleSubmit() {
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) { setError('Сумманы туура киргизиңиз'); return; }
    if (!file) { setError('Скриншот жүктөңүз'); return; }

    setError('');
    setUploading(true);
    try {
      const url = await topupService.uploadScreenshot(file);
      await topupService.requestTopup(amt, url);
      onSuccess(amt);
    } catch (err: unknown) {
      const msg = (err as Error).message || 'Ката чыкты';
      setError(msg);
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-card" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Балансты толуктоо</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div className="form-group">
          <label>Сумма (сом)</label>
          <input
            type="number"
            placeholder="Мисалы: 500"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            min="1"
          />
        </div>

        <div className="form-group">
          <label>Төлөм скриншоту</label>
          {preview ? (
            <div className="screenshot-preview">
              <img src={preview} alt="screenshot" />
              <button className="screenshot-remove" onClick={() => { setFile(null); setPreview(null); }}>✕</button>
            </div>
          ) : (
            <div className="screenshot-drop" onClick={() => fileRef.current?.click()}>
              <div style={{ fontSize: 40 }}>📎</div>
              <p>Скриншот жүктөөн үчүн таптаңыз</p>
              <span>PNG, JPG, HEIC форматтары</span>
            </div>
          )}
          <input ref={fileRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleFile} />
        </div>

        {error && <div className="form-error" style={{ marginBottom: 12 }}>{error}</div>}

        <button className="btn btn-primary btn-full" onClick={handleSubmit} disabled={uploading}>
          {uploading ? <span className="spinner" /> : 'Жөнөтүү'}
        </button>
      </div>
    </div>
  );
}

// ── ChangePasswordModal ────────────────────────────────────────────────────────
function ChangePasswordModal({ onClose }: { onClose: () => void }) {
  const [oldPass, setOldPass] = useState('');
  const [newPass, setNewPass] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  async function handleSubmit() {
    if (!oldPass || !newPass) { setError('Бардык талааларды толтуруңуз'); return; }
    if (newPass.length < 6) { setError('Жаңы сырсөз 6 символдон кем болбосун'); return; }
    setError('');
    setLoading(true);
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/auth/change-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ old_password: oldPass, new_password: newPass }),
      });
      if (!res.ok) {
        const d = await res.json();
        throw new Error(d.detail || 'Ката чыкты');
      }
      setSuccess(true);
    } catch (err: unknown) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-card" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Сырсөздү өзгөртүү</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        {success ? (
          <div style={{ textAlign: 'center', padding: '20px 0' }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
            <p style={{ fontWeight: 600 }}>Сырсөз ийгиликтүү өзгөртүлдү</p>
            <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={onClose}>Жабуу</button>
          </div>
        ) : (
          <>
            <div className="form-group">
              <label>Учурдагы сырсөз</label>
              <input type="password" value={oldPass} onChange={e => setOldPass(e.target.value)} placeholder="••••••" />
            </div>
            <div className="form-group">
              <label>Жаңы сырсөз</label>
              <input type="password" value={newPass} onChange={e => setNewPass(e.target.value)} placeholder="••••••" />
            </div>
            {error && <div className="form-error" style={{ marginBottom: 12 }}>{error}</div>}
            <button className="btn btn-primary btn-full" onClick={handleSubmit} disabled={loading}>
              {loading ? <span className="spinner" /> : 'Өзгөртүү'}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
