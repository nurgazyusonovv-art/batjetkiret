import { useState, FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Building2 } from 'lucide-react';
import { authService } from '../services/auth';
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
      navigate('/');
    } catch (err: unknown) {
      const e = err as { response?: { data?: { detail?: string } } };
      setError(e?.response?.data?.detail ?? 'Логин же сырсөз туура эмес');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="ep-login-page">
      <div className="ep-login-card">
        <div className="ep-login-logo">
          <Building2 size={36} color="#4f46e5" />
        </div>
        <h1>Ишкана панели</h1>
        <p className="ep-login-subtitle">Batken Express — ишканаңызды башкаруу</p>

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
