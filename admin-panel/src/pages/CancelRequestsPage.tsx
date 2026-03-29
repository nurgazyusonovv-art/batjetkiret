import { useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle, XCircle, RefreshCw } from 'lucide-react';
import { cancelRequestsService, CancelRequest } from '@/services/cancelRequests';
import { fmtDateTime } from '@/utils/date';
import './CancelRequestsPage.css';

const STATUS_LABELS: Record<string, string> = {
  ACCEPTED: 'Кабыл алынды',
  ON_THE_WAY: 'Жолдо',
  DELIVERED: 'Жеткирилди',
};

const STATUS_COLORS: Record<string, string> = {
  ACCEPTED: '#3b82f6',
  ON_THE_WAY: '#8b5cf6',
  DELIVERED: '#10b981',
};

export default function CancelRequestsPage() {
  const [requests, setRequests] = useState<CancelRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionId, setActionId] = useState<number | null>(null);
  const [noteMap, setNoteMap] = useState<Record<number, string>>({});

  const load = async () => {
    setLoading(true);
    try {
      const data = await cancelRequestsService.list();
      setRequests(data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const approve = async (id: number) => {
    if (!confirm(`Заказ #${id} жокко чыгарылсынбы?`)) return;
    setActionId(id);
    try {
      await cancelRequestsService.approve(id, noteMap[id] || '');
      setRequests(prev => prev.filter(r => r.id !== id));
    } catch {
      alert('Ката кетти');
    } finally {
      setActionId(null);
    }
  };

  const reject = async (id: number) => {
    if (!confirm(`Заказ #${id} жокко чыгаруу суроосу четке кагылсынбы?`)) return;
    setActionId(id);
    try {
      await cancelRequestsService.reject(id, noteMap[id] || '');
      setRequests(prev => prev.filter(r => r.id !== id));
    } catch {
      alert('Ката кетти');
    } finally {
      setActionId(null);
    }
  };

  return (
    <div className="crp-page">
      <div className="page-header">
        <div className="crp-title-row">
          <AlertTriangle size={22} color="#f59e0b" />
          <h1>Жокко чыгаруу суроолору</h1>
          {requests.length > 0 && (
            <span className="crp-count-badge">{requests.length}</span>
          )}
        </div>
        <p className="subtitle">Курьер жеткирүүнү баштаган заказдарга колдонуучу жокко чыгаруу суроосу жөнөткөн</p>
      </div>

      <div className="crp-refresh-row">
        <button className="crp-refresh-btn" onClick={load} disabled={loading}>
          <RefreshCw size={14} className={loading ? 'crp-spin' : ''} />
          Жаңылоо
        </button>
      </div>

      {loading ? (
        <div className="loading-container">
          <div className="spinner" />
          <p>Жүктөлүүдө...</p>
        </div>
      ) : requests.length === 0 ? (
        <div className="crp-empty">
          <CheckCircle size={48} color="#10b981" opacity={0.4} />
          <p>Күтүүдөгү суроолор жок</p>
        </div>
      ) : (
        <div className="crp-list">
          {requests.map(req => {
            const isBusy = actionId === req.id;
            return (
              <div key={req.id} className="crp-card">
                <div className="crp-card-header">
                  <div className="crp-order-id">Заказ #{req.id}</div>
                  <span
                    className="crp-status-badge"
                    style={{ background: STATUS_COLORS[req.status] ?? '#6b7280' }}
                  >
                    {STATUS_LABELS[req.status] ?? req.status}
                  </span>
                  <span className="crp-date">{fmtDateTime(req.created_at)}</span>
                </div>

                <div className="crp-info-grid">
                  <div className="crp-info-block">
                    <div className="crp-info-label">Колдонуучу</div>
                    <div className="crp-info-value">{req.user_name || '—'}</div>
                    <div className="crp-info-sub">{req.user_phone}</div>
                  </div>
                  <div className="crp-info-block">
                    <div className="crp-info-label">Курьер</div>
                    <div className="crp-info-value">{req.courier_name || '—'}</div>
                    <div className="crp-info-sub">{req.courier_phone || 'Жок'}</div>
                  </div>
                  <div className="crp-info-block">
                    <div className="crp-info-label">Баасы</div>
                    <div className="crp-info-value crp-price">{req.price} сом</div>
                  </div>
                </div>

                <div className="crp-route">
                  <span className="crp-route-point crp-from">{req.from_address}</span>
                  <span className="crp-route-arrow">→</span>
                  <span className="crp-route-point crp-to">{req.to_address}</span>
                </div>

                {req.cancel_request_reason && (
                  <div className="crp-reason">
                    <span className="crp-reason-label">Себеп:</span> {req.cancel_request_reason}
                  </div>
                )}

                <div className="crp-actions">
                  <input
                    className="crp-note-input"
                    placeholder="Админ эскертмеси (милдеттүү эмес)..."
                    value={noteMap[req.id] || ''}
                    onChange={e => setNoteMap(prev => ({ ...prev, [req.id]: e.target.value }))}
                  />
                  <div className="crp-btn-row">
                    <button
                      className="crp-btn crp-btn-approve"
                      onClick={() => approve(req.id)}
                      disabled={isBusy}
                    >
                      <CheckCircle size={15} />
                      {isBusy ? '...' : 'Бекитүү (Жокко чыгаруу)'}
                    </button>
                    <button
                      className="crp-btn crp-btn-reject"
                      onClick={() => reject(req.id)}
                      disabled={isBusy}
                    >
                      <XCircle size={15} />
                      {isBusy ? '...' : 'Четке кагуу (Улантуу)'}
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
