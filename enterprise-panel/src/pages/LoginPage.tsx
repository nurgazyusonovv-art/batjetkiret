import { useState, FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/auth';
import { subscribeToPush } from '../utils/pushNotifications';
import './LoginPage.css';

export default function LoginPage() {
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await authService.login(phone.trim(), password);
      // Subscribe to Web Push after successful login (non-blocking)
      subscribeToPush().catch(() => {});
      navigate('/');
    } catch (err: unknown) {
      const e = err as { response?: { status?: number; data?: { detail?: string } } };
      // No response means the server was never reached — saying "wrong
      // password" then sends people retyping a password that is correct.
      if (!e?.response) {
        setError('Сервер менен байланыш жок. Интернетти текшерип, кайра аракет кылыңыз.');
      } else {
        setError(
          e.response.data?.detail ??
            (e.response.status === 401
              ? 'Логин же сырсөз туура эмес'
              : `Сервер катасы (${e.response.status}). Кийинчерээк кайталаңыз.`),
        );
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="ep-login-page">
      <div className="ep-login-card">
        <div className="ep-login-logo">
          <img src="/logo.png" alt="Баткен Экспресс" className="ep-login-logo-img" />
        </div>
        <h1>Баткен Экспресс</h1>
        <p className="ep-login-subtitle">Ишкана башкаруу панели</p>

        {error && <div className="ep-login-error">{error}</div>}

        <form onSubmit={handleSubmit} className="ep-login-form">
          <div className="ep-form-group">
            <label>Телефон номери</label>
            <input
              type="text"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+996XXXXXXXXX"
              required
            />
          </div>
          <div className="ep-form-group">
            <label>Сырсөз</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
          </div>
          <button type="submit" className="ep-login-btn" disabled={loading}>
            {loading ? 'Кирүүдө...' : 'Кирүү'}
          </button>
        </form>
      </div>
    </div>
  );
}
