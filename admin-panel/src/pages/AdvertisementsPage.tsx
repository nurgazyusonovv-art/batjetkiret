import { useEffect, useState } from 'react';
import { CheckCircle, RefreshCw, XCircle } from 'lucide-react';
import { advertisementsService } from '@/services/advertisements';
import { Advertisement } from '@/types';
import './SettingsPage.css';

const STATUSES = [
  { value: '', label: 'Баары' },
  { value: 'PENDING', label: 'Күтүүдө' },
  { value: 'ACTIVE', label: 'Активдүү' },
  { value: 'REJECTED', label: 'Четке кагылган' },
  { value: 'EXPIRED', label: 'Мөөнөтү бүткөн' },
];

export default function AdvertisementsPage() {
  const [ads, setAds] = useState<Advertisement[]>([]);
  const [status, setStatus] = useState('PENDING');
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  const load = async () => {
    setLoading(true);
    setMessage('');
    try {
      const data = await advertisementsService.list(status || undefined);
      setAds(data);
    } catch {
      setMessage('Жарнамалар жүктөлгөн жок');
    } finally {
      setLoading(false);
    }
  };

  const approve = async (ad: Advertisement) => {
    try {
      await advertisementsService.approve(ad.id);
      setMessage('✓ Жарнама жактырылды');
      await load();
    } catch {
      setMessage('Жактырууда ката кетти');
    }
  };

  const reject = async (ad: Advertisement) => {
    const reason = prompt('Четке кагуу себеби:', 'Эрежеге туура келбейт') || '';
    try {
      await advertisementsService.reject(ad.id, reason);
      setMessage('✓ Жарнама четке кагылды, акча кайтарылды');
      await load();
    } catch {
      setMessage('Четке кагууда ката кетти');
    }
  };

  return (
    <div className="sp-page">
      <div className="sp-section">
        <div className="sp-section-title">
          Колдонуучу жарнамалары
        </div>

        <div className="sp-fee-input-row" style={{ marginBottom: 16 }}>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="sp-fee-input"
            style={{ maxWidth: 260 }}
          >
            {STATUSES.map((item) => (
              <option key={item.value} value={item.value}>{item.label}</option>
            ))}
          </select>
          <button className="sp-save-btn" onClick={load} disabled={loading}>
            <RefreshCw size={15} />
            Жаңылоо
          </button>
          {message && (
            <div className={`sp-fee-msg ${message.startsWith('✓') ? 'success' : 'error'}`}>
              {message}
            </div>
          )}
        </div>

        {loading ? (
          <p>Жүктөлүүдө...</p>
        ) : ads.length === 0 ? (
          <p>Жарнама жок</p>
        ) : (
          <div className="sp-fees-grid">
            {ads.map((ad) => (
              <div key={ad.id} className="sp-fee-card sp-fee-card--bordered">
                {ad.image_url && (
                  <img
                    src={ad.image_url}
                    alt={ad.title}
                    style={{ width: '100%', height: 180, objectFit: 'cover', borderRadius: 12, marginBottom: 12 }}
                  />
                )}
                <div className="sp-fee-info">
                  <div className="sp-fee-label">{ad.title}</div>
                  <div className="sp-fee-desc">
                    {ad.user_name || `Колдонуучу #${ad.user_id}`} · {ad.status} · {ad.fee_amount} сом
                  </div>
                </div>
                <p style={{ whiteSpace: 'pre-wrap', lineHeight: 1.45 }}>{ad.description}</p>
                {ad.contact_phone && <p><b>Байланыш:</b> {ad.contact_phone}</p>}
                {ad.category && <p><b>Категория:</b> {ad.category}</p>}
                {ad.rejection_reason && <p><b>Себеп:</b> {ad.rejection_reason}</p>}

                {ad.status !== 'ACTIVE' && (
                  <div className="sp-fee-input-row">
                    <button className="sp-save-btn" onClick={() => approve(ad)}>
                      <CheckCircle size={15} />
                      Жактыруу
                    </button>
                    {ad.status !== 'REJECTED' && (
                      <button className="sp-save-btn sp-save-btn--danger" onClick={() => reject(ad)}>
                        <XCircle size={15} />
                        Четке кагуу
                      </button>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
