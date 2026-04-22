import { useEffect, useState } from 'react';
import { KeyRound, RefreshCw, CheckCircle, MessageCircle, Copy } from 'lucide-react';
import { passwordResetService } from '@/services/passwordReset';
import { PasswordResetRequest } from '@/types';
import { fmtDateTime } from '@/utils/date';
import './PasswordResetRequestsPage.css';

function minutesLeft(expiresAt: string): number {
  return Math.floor((new Date(expiresAt).getTime() - Date.now()) / 60000);
}

export default function PasswordResetRequestsPage() {
  const [requests, setRequests] = useState<PasswordResetRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [dismissingId, setDismissingId] = useState<number | null>(null);
  const [copiedId, setCopiedId] = useState<number | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const data = await passwordResetService.list();
      setRequests(data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const copyCode = (req: PasswordResetRequest) => {
    navigator.clipboard.writeText(req.code);
    setCopiedId(req.id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const openWhatsApp = (req: PasswordResetRequest) => {
    const phone = req.user?.phone?.replace(/\D/g, '') ?? '';
    const name = req.user?.name ?? 'колдонуучу';
    const uniqueId = req.user?.unique_id ?? '';
    const msg = encodeURIComponent(
      `Саламатсызбы, ${name}!\n\nСиздин сырсөздү баштан коюу коду:\n\n*${req.code}*\n\nКодду колдонмого киргизиңиз. Код ${minutesLeft(req.expires_at)} мүнөт ичинде жарактуу.\n\n(ID: ${uniqueId})`
    );
    window.open(`https://wa.me/${phone}?text=${msg}`, '_blank');
  };

  const dismiss = async (req: PasswordResetRequest) => {
    setDismissingId(req.id);
    try {
      await passwordResetService.dismiss(req.id);
      setRequests(prev => prev.filter(r => r.id !== req.id));
    } catch {
      alert('Ката кетти');
    } finally {
      setDismissingId(null);
    }
  };

  return (
    <div className="prr-page">
      <div className="page-header">
        <div className="prr-title-row">
          <KeyRound size={22} color="#8b5cf6" />
          <h1>Сырсөз баштан коюу суроолору</h1>
          {requests.length > 0 && (
            <span className="prr-count-badge">{requests.length}</span>
          )}
        </div>
        <p className="subtitle">
          Колдонуучулар сырсөздөрүн унутуп, WhatsApp аркылуу суроо жиберишти — кодду алып жөнөтүңүз
        </p>
      </div>

      <div className="prr-refresh-row">
        <button className="prr-refresh-btn" onClick={load} disabled={loading}>
          <RefreshCw size={14} className={loading ? 'prr-spin' : ''} />
          Жаңылоо
        </button>
      </div>

      {loading ? (
        <div className="loading-container">
          <div className="spinner" />
          <p>Жүктөлүүдө...</p>
        </div>
      ) : requests.length === 0 ? (
        <div className="prr-empty">
          <CheckCircle size={48} color="#10b981" opacity={0.4} />
          <p>Күтүүдөгү суроолор жок</p>
        </div>
      ) : (
        <div className="prr-list">
          {requests.map(req => {
            const mins = minutesLeft(req.expires_at);
            const isBusy = dismissingId === req.id;
            const isCopied = copiedId === req.id;

            return (
              <div key={req.id} className="prr-card">
                <div className="prr-card-header">
                  <span className="prr-req-id">Суроо #{req.id}</span>
                  {req.resend_count > 0 && (
                    <span style={{ fontSize: 11, color: '#f59e0b', fontWeight: 600 }}>
                      Кайра жиберүү: {req.resend_count}×
                    </span>
                  )}
                  <span className="prr-date">{fmtDateTime(req.last_sent_at)}</span>
                </div>

                <div className="prr-body">
                  <div className="prr-info-block">
                    <div className="prr-info-label">Колдонуучу</div>
                    <div className="prr-info-value">{req.user?.name ?? '—'}</div>
                    <div className="prr-info-sub">{req.user?.phone}</div>
                    {req.user?.unique_id && (
                      <div className="prr-info-sub" style={{ color: '#8b5cf6', fontWeight: 600 }}>
                        {req.user.unique_id}
                      </div>
                    )}
                  </div>

                  <div className="prr-info-block">
                    <div className="prr-code-label">Код</div>
                    <div className="prr-code-block" style={{ marginTop: 4 }}>
                      <div>
                        <div className="prr-code-value">{req.code}</div>
                        <div className={`prr-expires ${mins <= 5 ? 'urgent' : ''}`}>
                          {mins > 0 ? `${mins} мүнөт калды` : 'Мөөнөтү өткөн'}
                        </div>
                      </div>
                      <button
                        className={`prr-copy-btn ${isCopied ? 'copied' : ''}`}
                        onClick={() => copyCode(req)}
                      >
                        {isCopied ? <CheckCircle size={13} /> : <Copy size={13} />}
                        {isCopied ? 'Көчүрүлдү' : 'Көчүр'}
                      </button>
                    </div>
                  </div>
                </div>

                <div className="prr-actions">
                  <button
                    className="prr-btn prr-btn-whatsapp"
                    onClick={() => openWhatsApp(req)}
                    disabled={!req.user?.phone}
                  >
                    <MessageCircle size={15} />
                    WhatsApp аркылуу жөнөт
                  </button>
                  <button
                    className="prr-btn prr-btn-dismiss"
                    onClick={() => dismiss(req)}
                    disabled={isBusy}
                  >
                    <CheckCircle size={15} />
                    {isBusy ? '...' : 'Жиберилди (жок кыл)'}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
