import { useEffect, useMemo, useState } from 'react';
import { CheckCircle, XCircle, Image as ImageIcon } from 'lucide-react';
import { topupService } from '@/services/admin';
import { TopupRequest } from '@/types';
import { getErrorMessage } from '@/utils/error';
import './TopupPage.css';

export default function TopupPage() {
  const [topups, setTopups] = useState<TopupRequest[]>([]);
  const [history, setHistory] = useState<TopupRequest[]>([]);
  const [activeTab, setActiveTab] = useState<'pending' | 'history'>('pending');
  const [historySearch, setHistorySearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<number | null>(null);
  const [previewLoadingId, setPreviewLoadingId] = useState<number | null>(null);

  const filteredHistory = useMemo(() => {
    const query = historySearch.trim().toLowerCase();
    if (!query) return history;

    return history.filter((item) => {
      const uniqueId = (item.unique_id || '').toLowerCase();
      const userPhone = (item.user?.phone || '').toLowerCase();
      return uniqueId.includes(query) || userPhone.includes(query);
    });
  }, [history, historySearch]);

  const approvedHistoryItems = useMemo(
    () => filteredHistory.filter((item) => item.status === 'approved'),
    [filteredHistory]
  );

  const rejectedHistoryItems = useMemo(
    () => filteredHistory.filter((item) => item.status === 'rejected'),
    [filteredHistory]
  );

  const approvedHistorySum = useMemo(
    () => approvedHistoryItems.reduce((sum, item) => sum + item.requested_amount, 0),
    [approvedHistoryItems]
  );

  const rejectedHistorySum = useMemo(
    () => rejectedHistoryItems.reduce((sum, item) => sum + item.requested_amount, 0),
    [rejectedHistoryItems]
  );

  useEffect(() => {
    loadTopups();
  }, []);

  const loadTopups = async () => {
    try {
      setLoading(true);
      const [pendingData, historyData] = await Promise.all([
        topupService.getPendingTopups(),
        topupService.getTopupHistory(),
      ]);
      setTopups(pendingData);
      setHistory(historyData);
    } catch (err) {
      console.error('Failed to load topups:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenScreenshot = async (topupId: number) => {
    setPreviewLoadingId(topupId);
    try {
      const fileUrl = await topupService.fetchScreenshotUrl(topupId);
      window.open(fileUrl, '_blank', 'noopener,noreferrer');
    } catch (error: unknown) {
      alert(`Скриншот ачылган жок: ${getErrorMessage(error, 'Ката чыкты')}`);
    } finally {
      setPreviewLoadingId(null);
    }
  };

  const handleApprove = async (topupId: number) => {
    if (!confirm('Бул топапты тастыктагонго ишенесизби?')) return;

    setActionLoading(topupId);
    try {
      await topupService.approveTopup(topupId);
      await loadTopups();
    } catch (error: unknown) {
      console.error('Failed to approve topup:', error);
      alert(`Тастыктоо жаңылыштыкка учурады: ${getErrorMessage(error, 'Ката чыкты')}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleReject = async (topupId: number) => {
    const comment = prompt('Четке кагуу себеби:');
    if (!comment) return;

    setActionLoading(topupId);
    try {
      await topupService.rejectTopup(topupId, comment);
      await loadTopups();
    } catch (error: unknown) {
      console.error('Failed to reject topup:', error);
      alert(`Четке кагуу жаңылыштыкка учурады: ${getErrorMessage(error, 'Ката чыкты')}`);
    } finally {
      setActionLoading(null);
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
        <p>Жүктөлүүдө...</p>
      </div>
    );
  }

  return (
    <div className="topup-page">
      <div className="page-header">
        <h1>Топап Өтүнүчтөр</h1>
        <p className="subtitle">Баланс толтуруу өтүнүчтөрүн тастыктоо</p>
      </div>

      <div className="topup-tabs">
        <button
          className={`tab-btn ${activeTab === 'pending' ? 'active' : ''}`}
          onClick={() => setActiveTab('pending')}
        >
          Күтүүдөгү өтүнүчтөр
        </button>
        <button
          className={`tab-btn ${activeTab === 'history' ? 'active' : ''}`}
          onClick={() => setActiveTab('history')}
        >
          Төлөм тарыхы
        </button>
      </div>

      {activeTab === 'history' && (
        <div className="history-search-wrap">
          <input
            type="text"
            className="history-search-input"
            placeholder="Издөө: BJ000123 же +996..."
            value={historySearch}
            onChange={(e) => setHistorySearch(e.target.value)}
          />
        </div>
      )}

      <div className="topup-stats">
        <div className="stat-item">
          <span className="stat-label">Күтүүдө:</span>
          <span className="stat-value">{topups.length}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Тарых:</span>
          <span className="stat-value">{activeTab === 'history' ? filteredHistory.length : history.length}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Жалпы суммасы:</span>
          <span className="stat-value">
            {(activeTab === 'pending' ? topups : filteredHistory).reduce((sum, t) => sum + t.requested_amount, 0)} сом
          </span>
        </div>
        {activeTab === 'history' && (
          <>
            <div className="stat-item">
              <span className="stat-label">Тастыкталгандар:</span>
              <span className="stat-value stat-approved">
                {approvedHistorySum} сом ({approvedHistoryItems.length} даана)
              </span>
            </div>
            <div className="stat-item">
              <span className="stat-label">Четке кагылгандар:</span>
              <span className="stat-value stat-rejected">
                {rejectedHistorySum} сом ({rejectedHistoryItems.length} даана)
              </span>
            </div>
          </>
        )}
      </div>

      {activeTab === 'pending' && topups.length === 0 ? (
        <div className="empty-state">
          <CheckCircle size={64} color="#10b981" />
          <h3>Күтүүдөгү өтүнүчтөр жок</h3>
          <p>Топап өтүнүчтөрүнүн баары тастыкталды</p>
        </div>
      ) : activeTab === 'history' && filteredHistory.length === 0 ? (
        <div className="empty-state">
          <ImageIcon size={64} color="#6b7280" />
          <h3>Издөө боюнча жыйынтык табылган жок</h3>
          <p>Жеке номерди (BJ...) же телефон номерди текшерип кайра издеп көрүңүз</p>
        </div>
      ) : (
        <div className="topup-grid">
          {(activeTab === 'pending' ? topups : filteredHistory).map((topup) => (
            <div key={topup.id} className="topup-card">
              <div className="topup-header">
                <div className="topup-id">Өтүнүч #{topup.id}</div>
                <div className="topup-date">
                  {new Date(topup.created_at).toLocaleString('ru-RU')}
                </div>
              </div>

              <div className="topup-body">
                <div className="user-info">
                  <div className="user-avatar">
                    {topup.user?.phone?.[0] || 'U'}
                  </div>
                  <div className="user-details">
                    <div className="user-phone">{topup.user?.phone}</div>
                    <div className="user-name">{topup.user?.name || 'Колдонуучу'}</div>
                  </div>
                </div>

                <div className="amount-display">
                  <span className="amount-label">Суммасы:</span>
                  <span className="amount-value">{topup.requested_amount} сом</span>
                </div>

                <div className="screenshot-section">
                  <ImageIcon size={20} />
                  <button
                    className="screenshot-open-btn"
                    onClick={() => handleOpenScreenshot(topup.id)}
                    disabled={previewLoadingId === topup.id}
                  >
                    {previewLoadingId === topup.id ? 'Ачылууда...' : 'Скриншотту ачуу'}
                  </button>
                </div>

                <div className="topup-meta">
                  <span>ID: {topup.unique_id || '—'}</span>
                  <span className={`status-badge status-${topup.status}`}>
                    {topup.status === 'pending'
                      ? 'Күтүүдө'
                      : topup.status === 'approved'
                        ? 'Тастыкталды'
                        : 'Четке кагылды'}
                  </span>
                </div>

                {topup.admin_comment && (
                  <div className="admin-note">Админ эскертүүсү: {topup.admin_comment}</div>
                )}

                {topup.user && (
                  <div className="user-balance">
                    <span className="balance-label">Учурдагы баланс:</span>
                    <span className="balance-value">{topup.user.balance} сом</span>
                  </div>
                )}
              </div>

              {activeTab === 'pending' && (
                <div className="topup-actions">
                  <button
                    className="action-btn approve-btn"
                    onClick={() => handleApprove(topup.id)}
                    disabled={actionLoading === topup.id}
                  >
                    <CheckCircle size={18} />
                    Тастыктоо
                  </button>
                  <button
                    className="action-btn reject-btn"
                    onClick={() => handleReject(topup.id)}
                    disabled={actionLoading === topup.id}
                  >
                    <XCircle size={18} />
                    Четке кагуу
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
