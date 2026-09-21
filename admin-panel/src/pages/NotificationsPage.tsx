import { useEffect, useRef, useState } from 'react';
import { notificationsService } from '@/services/notifications';
import { enterprisesService } from '@/services/enterprises';
import { Enterprise, Notification } from '@/types';
import { Trash2, Check, Send, Eraser, ImagePlus, X, Store } from 'lucide-react';
import { fmtDateTime } from '@/utils/date';
import api from '@/services/api';
import './NotificationsPage.css';

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Broadcast form state
  const [bcTitle, setBcTitle] = useState('');
  const [bcMessage, setBcMessage] = useState('');
  const [bcSending, setBcSending] = useState(false);
  const [bcResult, setBcResult] = useState<{ ok: boolean; text: string } | null>(null);

  // Campaign picture + the shop the notification advertises
  const [bcImageUrl, setBcImageUrl] = useState<string | null>(null);
  const [bcUploading, setBcUploading] = useState(false);
  const [bcEnterpriseId, setBcEnterpriseId] = useState<number | ''>('');
  const [enterprises, setEnterprises] = useState<Enterprise[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const loadNotifications = async () => {
    try {
      setLoading(true);
      const data = await notificationsService.getNotifications(0, 100);
      setNotifications(data);
      setError('');
    } catch (e) {
      setError('Билдирүүлөрдү жүктөө мүмкүн болгон жок');
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadNotifications();
    const interval = setInterval(loadNotifications, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    enterprisesService
      .list({ is_active: true, limit: 200 })
      .then(setEnterprises)
      .catch(() => setEnterprises([]));
  }, []);

  const handlePickImage = async (file: File | undefined) => {
    if (!file) return;
    setBcUploading(true);
    setBcResult(null);
    try {
      const fd = new FormData();
      fd.append('file', file);
      // FCM needs a real HTTPS URL, so the picture goes to R2 — not base64.
      const res = await api.post('/admin/notifications/image', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setBcImageUrl(res.data.url);
    } catch {
      setBcResult({ ok: false, text: 'Сүрөттү жүктөөдө ката чыкты' });
    } finally {
      setBcUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleMarkAsRead = async (id: number) => {
    try {
      await notificationsService.markAsRead(id);
      setNotifications(notifications.map(n => 
        n.id === id ? { ...n, is_read: true } : n
      ));
    } catch (e) {
      console.error('Error marking as read:', e);
    }
  };

  const handleBroadcast = async () => {
    if (!bcTitle.trim() || !bcMessage.trim()) {
      setBcResult({ ok: false, text: 'Аталышты жана текстти толтуруңуз' });
      return;
    }
    setBcSending(true);
    setBcResult(null);
    try {
      const res = await api.post('/admin/notifications/broadcast', {
        title: bcTitle.trim(),
        message: bcMessage.trim(),
        image_url: bcImageUrl,
        enterprise_id: bcEnterpriseId === '' ? null : Number(bcEnterpriseId),
        type: 'promo',
      });
      setBcResult({ ok: true, text: res.data.message });
      setBcTitle('');
      setBcMessage('');
      setBcImageUrl(null);
      setBcEnterpriseId('');
    } catch {
      setBcResult({ ok: false, text: 'Жөнөтүүдө ката чыкты' });
    } finally {
      setBcSending(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Ошол билдирүүнү чындай эле өчүргүсүз бе?')) return;

    try {
      await notificationsService.deleteNotification(id);
      setNotifications(notifications.filter(n => n.id !== id));
    } catch (e) {
      console.error('Error deleting notification:', e);
    }
  };

  const handleClearAll = async () => {
    if (!confirm(`Бардык ${notifications.length} билдирүүнү өчүргүсүз бе? Бул аракетти кайтаруу мүмкүн эмес.`)) return;
    try {
      await api.delete('/admin/notifications');
      setNotifications([]);
    } catch (e) {
      console.error('Error clearing notifications:', e);
    }
  };

  if (loading) {
    return <div className="loading-container"><p>Жүктөлүүдө...</p></div>;
  }

  if (error) {
    return (
      <div className="error-container">
        <p>{error}</p>
        <button onClick={loadNotifications}>Кайра аракет</button>
      </div>
    );
  }

  const unreadCount = notifications.filter(n => !n.is_read).length;

  return (
    <div className="notifications-page">
      <div className="notifications-header">
        <div>
          <h1>Билдирүүлөр</h1>
          <p className="notifications-subtitle">
            Жалпы: {notifications.length} | Окулбаган: {unreadCount}
          </p>
        </div>
        <div className="header-actions">
          <button className="refresh-btn" onClick={loadNotifications}>Жаңылоо</button>
          {notifications.length > 0 && (
            <button className="clear-all-btn" onClick={handleClearAll}>
              <Eraser size={15} /> Баарын тазала
            </button>
          )}
        </div>
      </div>

      {/* Broadcast card */}
      <div className="broadcast-card">
        <div className="broadcast-title">
          <Send size={18} />
          Баардык колдонуучуларга билдирүү жөнөтүү
        </div>
        <div className="broadcast-form">
          <input
            className="bc-input"
            placeholder="Аталышы (мис: Акция! Жаңы тариф)"
            value={bcTitle}
            onChange={e => setBcTitle(e.target.value)}
            maxLength={120}
          />
          <textarea
            className="bc-textarea"
            placeholder="Билдирүү тексти..."
            rows={3}
            value={bcMessage}
            onChange={e => setBcMessage(e.target.value)}
            maxLength={500}
          />

          <div className="bc-row">
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              hidden
              onChange={e => handlePickImage(e.target.files?.[0])}
            />
            <button
              type="button"
              className="bc-image-btn"
              onClick={() => fileInputRef.current?.click()}
              disabled={bcUploading}
            >
              <ImagePlus size={15} />
              {bcUploading ? 'Жүктөлүүдө...' : bcImageUrl ? 'Сүрөттү алмаштыруу' : 'Сүрөт кошуу'}
            </button>

            <div className="bc-enterprise">
              <Store size={15} />
              <select
                className="bc-select"
                value={bcEnterpriseId}
                onChange={e =>
                  setBcEnterpriseId(e.target.value === '' ? '' : Number(e.target.value))
                }
              >
                <option value="">Ишкана тандалган жок</option>
                {enterprises.map(e => (
                  <option key={e.id} value={e.id}>{e.name}</option>
                ))}
              </select>
            </div>
          </div>

          {bcImageUrl && (
            <div className="bc-preview">
              <div className="bc-preview-label">Колдонуучу мындай көрөт:</div>
              <div className="bc-preview-card">
                <img src={bcImageUrl} alt="preview" className="bc-preview-img" />
                <button
                  type="button"
                  className="bc-preview-remove"
                  title="Сүрөттү алып салуу"
                  onClick={() => setBcImageUrl(null)}
                >
                  <X size={14} />
                </button>
                <div className="bc-preview-body">
                  <div className="bc-preview-title">{bcTitle || 'Аталышы'}</div>
                  <div className="bc-preview-text">{bcMessage || 'Билдирүү тексти'}</div>
                  {bcEnterpriseId !== '' && (
                    <div className="bc-preview-shop">
                      <Store size={12} />
                      {enterprises.find(e => e.id === bcEnterpriseId)?.name}
                      <span className="bc-preview-arrow">→ басканда ачылат</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {bcResult && (
            <div className={`bc-result ${bcResult.ok ? 'ok' : 'err'}`}>
              {bcResult.text}
            </div>
          )}
          <button
            className="bc-send-btn"
            onClick={handleBroadcast}
            disabled={bcSending}
          >
            {bcSending ? 'Жөнөтүлүүдө...' : <><Send size={15} /> Баарына жөнөтүү</>}
          </button>
        </div>
      </div>

      {notifications.length === 0 ? (
        <div className="empty-state">
          <p>Билдирүүлөр жок</p>
        </div>
      ) : (
        <div className="notifications-list">
          {notifications.map((notif) => (
            <div 
              key={notif.id} 
              className={`notification-item ${notif.is_read ? 'read' : 'unread'}`}
            >
              <div className="notification-content">
                <div className="notification-header">
                  <h3 className="notification-title">{notif.title}</h3>
                  <span className="notification-time">
                    {fmtDateTime(notif.created_at)}
                  </span>
                </div>
                <p className="notification-message">{notif.message}</p>
                {notif.image_url && (
                  <img
                    src={notif.image_url}
                    alt={notif.title}
                    className="notification-image"
                  />
                )}
              </div>
              <div className="notification-actions">
                {!notif.is_read && (
                  <button 
                    className="action-btn read-btn"
                    title="Окуу"
                    onClick={() => handleMarkAsRead(notif.id)}
                  >
                    <Check size={18} />
                  </button>
                )}
                <button 
                  className="action-btn delete-btn"
                  title="Өчүү"
                  onClick={() => handleDelete(notif.id)}
                >
                  <Trash2 size={18} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
