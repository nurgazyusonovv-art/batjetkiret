import { useEffect, useState, useCallback } from 'react';
import { CreditCard, RefreshCw, CheckCircle, XCircle, Eye } from 'lucide-react';
import { ordersService, OrderPayment } from '../services/orders';
import { fmtDate } from '../utils/date';
import './PaymentsPage.css';

const STATUS_LABELS: Record<string, string> = {
  pending: 'Күтүүдө',
  confirmed: 'Тастыкталды',
  rejected: 'Четке кагылды',
};

const STATUS_COLORS: Record<string, string> = {
  pending: '#d97706',
  confirmed: '#059669',
  rejected: '#dc2626',
};

const FILTER_OPTIONS = [
  { value: '', label: 'Баардыгы' },
  { value: 'pending', label: 'Күтүүдө' },
  { value: 'confirmed', label: 'Тастыкталды' },
  { value: 'rejected', label: 'Четке кагылды' },
];

export default function PaymentsPage() {
  const [payments, setPayments] = useState<OrderPayment[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState('pending');
  const [actionId, setActionId] = useState<number | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [rejectNote, setRejectNote] = useState('');
  const [rejectingId, setRejectingId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await ordersService.getPayments(filterStatus || undefined);
      setPayments(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, [filterStatus]);

  useEffect(() => { load(); }, [load]);

  const handleConfirm = async (paymentId: number) => {
    setActionId(paymentId);
    try {
      await ordersService.confirmPayment(paymentId);
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      alert(err?.response?.data?.detail ?? 'Ката кетти');
    } finally {
      setActionId(null);
    }
  };

  const handleReject = async (paymentId: number) => {
    setActionId(paymentId);
    try {
      await ordersService.rejectPayment(paymentId, rejectNote || undefined);
      setRejectingId(null);
      setRejectNote('');
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      alert(err?.response?.data?.detail ?? 'Ката кетти');
    } finally {
      setActionId(null);
    }
  };

  return (
    <div className="ep-payments">
      {previewUrl && (
        <div className="ep-screenshot-overlay" onClick={() => setPreviewUrl(null)}>
          <img src={previewUrl} alt="screenshot" className="ep-screenshot-full" />
          <button className="ep-screenshot-close" onClick={() => setPreviewUrl(null)}>✕</button>
        </div>
      )}

      <div className="ep-payments-header">
        <div className="ep-payments-title">
          <CreditCard size={22} />
          <h1>Төлөмдөр</h1>
          <span className="ep-payments-count">{payments.length}</span>
        </div>
        <button className="ep-refresh-btn" onClick={load} disabled={loading}>
          <RefreshCw size={15} className={loading ? 'spin' : ''} />
          Жаңыртуу
        </button>
      </div>

      <div className="ep-filter-tabs">
        {FILTER_OPTIONS.map((opt) => (
          <button
            key={opt.value}
            className={`ep-filter-tab ${filterStatus === opt.value ? 'active' : ''}`}
            onClick={() => setFilterStatus(opt.value)}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="ep-loading">Жүктөлүүдө...</div>
      ) : payments.length === 0 ? (
        <div className="ep-empty">
          <CreditCard size={48} opacity={0.2} />
          <p>Төлөм табылган жок</p>
        </div>
      ) : (
        <div className="ep-payments-list">
          {payments.map((p) => (
            <div key={p.id} className="ep-payment-card">
              <div className="ep-payment-top">
                <div className="ep-payment-meta">
                  <span className="ep-payment-order">Заказ #{p.order_id}</span>
                  <span
                    className="ep-payment-status"
                    style={{ color: STATUS_COLORS[p.status] ?? '#6b7280' }}
                  >
                    {STATUS_LABELS[p.status] ?? p.status}
                  </span>
                </div>
                <span className="ep-payment-amount">{Number(p.amount).toFixed(0)} сом</span>
              </div>

              <div className="ep-payment-user">
                <span>{p.user_name ?? '—'}</span>
                <span className="ep-payment-phone">{p.user_phone ?? ''}</span>
                <span className="ep-payment-date">{fmtDate(p.created_at)}</span>
              </div>

              {p.note && (
                <div className="ep-payment-note">📝 {p.note}</div>
              )}

              <div className="ep-payment-actions">
                {p.screenshot_url && (
                  <button
                    className="ep-action-btn ep-action-preview"
                    onClick={() => setPreviewUrl(p.screenshot_url)}
                  >
                    <Eye size={14} />
                    Скриншот
                  </button>
                )}

                {p.status === 'pending' && (
                  <>
                    <button
                      className="ep-action-btn ep-action-confirm"
                      disabled={actionId === p.id}
                      onClick={() => handleConfirm(p.id)}
                    >
                      <CheckCircle size={14} />
                      {actionId === p.id ? '...' : 'Тастыктоо'}
                    </button>

                    {rejectingId === p.id ? (
                      <div className="ep-reject-row">
                        <input
                          className="ep-reject-input"
                          placeholder="Себеп (милдеттүү эмес)"
                          value={rejectNote}
                          onChange={(e) => setRejectNote(e.target.value)}
                        />
                        <button
                          className="ep-action-btn ep-action-reject"
                          disabled={actionId === p.id}
                          onClick={() => handleReject(p.id)}
                        >
                          <XCircle size={14} />
                          Жөнөтүү
                        </button>
                        <button
                          className="ep-action-btn ep-action-cancel"
                          onClick={() => { setRejectingId(null); setRejectNote(''); }}
                        >
                          Жок
                        </button>
                      </div>
                    ) : (
                      <button
                        className="ep-action-btn ep-action-reject"
                        onClick={() => setRejectingId(p.id)}
                      >
                        <XCircle size={14} />
                        Четке кагуу
                      </button>
                    )}
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
