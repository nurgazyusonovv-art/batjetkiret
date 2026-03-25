import { useEffect, useState } from 'react';
import { notificationsService } from '@/services/notifications';
import { Notification } from '@/types';
import { Trash2, Check, Send } from 'lucide-react';
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
      });
      setBcResult({ ok: true, text: res.data.message });
      setBcTitle('');
      setBcMessage('');
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
        <button className="refresh-btn" onClick={loadNotifications}>Жаңылоо</button>
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
                    {new Date(notif.created_at).toLocaleString('ru-RU')}
                  </span>
                </div>
                <p className="notification-message">{notif.message}</p>
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
