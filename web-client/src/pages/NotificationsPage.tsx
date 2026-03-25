import { useState, useEffect } from 'react';
import api from '../services/api';
import './NotificationsPage.css';

interface Notif {
  id: number;
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
}

export default function NotificationsPage() {
  const [notifs, setNotifs] = useState<Notif[]>([]);
  const [loading, setLoading] = useState(true);
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    api.get('/notifications/')
      .then(r => {
        setNotifs(r.data);
        setUnread(r.data.filter((n: Notif) => !n.is_read).length);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  async function markRead(id: number) {
    await api.post(`/notifications/${id}/read`).catch(() => {});
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, is_read: true } : n));
    setUnread(prev => Math.max(0, prev - 1));
  }

  async function markAllRead() {
    const unreadList = notifs.filter(n => !n.is_read);
    await Promise.all(unreadList.map(n => api.post(`/notifications/${n.id}/read`).catch(() => {})));
    setNotifs(prev => prev.map(n => ({ ...n, is_read: true })));
    setUnread(0);
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
        <h1 className="page-title" style={{ margin: 0 }}>
          🔔 Билдирүүлөр
          {unread > 0 && <span className="notif-badge">{unread}</span>}
        </h1>
        {unread > 0 && (
          <button className="btn btn-ghost btn-sm" onClick={markAllRead}>
            Баарын окулду деп белгилөө
          </button>
        )}
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: 80 }}><span className="spinner spinner-dark" /></div>
      ) : notifs.length === 0 ? (
        <div className="empty-state">
          <div style={{ fontSize: 64, marginBottom: 16 }}>🔕</div>
          <p>Азырынча билдирүү жок</p>
        </div>
      ) : (
        <div className="notif-list">
          {notifs.map(n => (
            <div
              key={n.id}
              className={`notif-card ${n.is_read ? 'read' : 'unread'}`}
              onClick={() => !n.is_read && markRead(n.id)}
            >
              <div className="notif-header">
                <span className="notif-title">{n.title}</span>
                <span className="notif-time">
                  {new Date(n.created_at).toLocaleString('ru-RU', {
                    day: '2-digit', month: '2-digit',
                    hour: '2-digit', minute: '2-digit',
                  })}
                </span>
              </div>
              <p className="notif-message">{n.message}</p>
              {!n.is_read && <span className="notif-dot" />}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
