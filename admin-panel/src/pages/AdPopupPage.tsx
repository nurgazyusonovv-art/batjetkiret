import { useState, useEffect, useRef } from 'react';
import { Send, Trash2, Upload, XCircle, CheckCircle, Clock } from 'lucide-react';
import api from '@/services/api';
import './AdPopupPage.css';

interface AdPopup {
  id: number;
  title: string | null;
  subtitle: string | null;
  image_data: string | null;
  link_url: string | null;
  is_active: boolean;
  created_at: string | null;
}

const emptyForm = { title: '', subtitle: '', link_url: '' };

export default function AdPopupPage() {
  const [popups, setPopups] = useState<AdPopup[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [sending, setSending] = useState(false);
  const [uploadingId, setUploadingId] = useState<number | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pendingIdRef = useRef<number | null>(null);

  const load = async () => {
    try {
      const res = await api.get('/admin/ad-popup');
      setPopups(res.data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const handleSend = async () => {
    setSending(true);
    try {
      await api.post('/admin/ad-popup', {
        title: form.title || null,
        subtitle: form.subtitle || null,
        link_url: form.link_url || null,
      });
      setForm(emptyForm);
      await load();
    } finally {
      setSending(false);
    }
  };

  const handleDeactivate = async (id: number) => {
    await api.patch(`/admin/ad-popup/${id}/deactivate`);
    load();
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Popup өчүрүлсүнбү?')) return;
    await api.delete(`/admin/ad-popup/${id}`);
    load();
  };

  const handleUploadClick = (id: number) => {
    pendingIdRef.current = id;
    fileInputRef.current?.click();
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    const id = pendingIdRef.current;
    if (!file || !id) return;
    e.target.value = '';
    setUploadingId(id);
    const fd = new FormData();
    fd.append('file', file);
    try {
      await api.post(`/admin/ad-popup/${id}/image`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      load();
    } finally {
      setUploadingId(null);
    }
  };

  const activePopup = popups.find(p => p.is_active);

  return (
    <div className="ap-page">
      <h1 className="ap-title">Реклама жиберүү</h1>
      <p className="ap-desc">
        Жиберилген реклама <strong>бардык колдонуучуга</strong> тиркемени ачканда бир жолу гана көрсөтүлөт.
      </p>

      {/* ── Current active popup ── */}
      {activePopup && (
        <div className="ap-active-card">
          <div className="ap-active-header">
            <span className="ap-live-badge">
              <span className="ap-dot" /> Жандуу
            </span>
            <span className="ap-active-date">
              {activePopup.created_at
                ? new Date(activePopup.created_at).toLocaleString('ru-RU')
                : ''}
            </span>
          </div>

          <div className="ap-active-body">
            {activePopup.image_data && (
              <img
                src={activePopup.image_data}
                alt="popup"
                className="ap-active-img"
              />
            )}
            <div className="ap-active-info">
              <div className="ap-active-title">
                {activePopup.title || <em style={{ color: '#aaa' }}>Аталышы жок</em>}
              </div>
              {activePopup.subtitle && (
                <div className="ap-active-sub">{activePopup.subtitle}</div>
              )}
              {activePopup.link_url && (
                <div className="ap-active-link">🔗 {activePopup.link_url}</div>
              )}
            </div>
          </div>

          <div className="ap-active-actions">
            <button
              className="ap-btn ap-btn-upload"
              onClick={() => handleUploadClick(activePopup.id)}
              disabled={uploadingId === activePopup.id}
            >
              <Upload size={15} />
              {uploadingId === activePopup.id ? 'Жүктөлүүдө...' : 'Сүрөт кошуу'}
            </button>
            <button
              className="ap-btn ap-btn-stop"
              onClick={() => handleDeactivate(activePopup.id)}
            >
              <XCircle size={15} /> Токтотуу
            </button>
            <button
              className="ap-btn ap-btn-delete"
              onClick={() => handleDelete(activePopup.id)}
            >
              <Trash2 size={15} /> Өчүрүү
            </button>
          </div>
        </div>
      )}

      {!activePopup && !loading && (
        <div className="ap-no-active">
          <XCircle size={24} color="#ccc" />
          <span>Учурда активдүү реклама жок</span>
        </div>
      )}

      {/* ── Send new popup form ── */}
      <div className="ap-form-card">
        <h2 className="ap-form-title">
          <Send size={18} /> Жаңы реклама жиберүү
        </h2>

        <div className="ap-form-grid">
          <div className="ap-field">
            <label>Аталышы</label>
            <input
              value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              placeholder="Акциянын аталышы"
            />
          </div>
          <div className="ap-field">
            <label>Кошумча текст</label>
            <input
              value={form.subtitle}
              onChange={e => setForm(f => ({ ...f, subtitle: e.target.value }))}
              placeholder="Кыскача сыпаттама"
            />
          </div>
          <div className="ap-field ap-field-full">
            <label>Шилтеме (URL) — милдеттүү эмес</label>
            <input
              value={form.link_url}
              onChange={e => setForm(f => ({ ...f, link_url: e.target.value }))}
              placeholder="https://..."
            />
          </div>
        </div>

        <p className="ap-note">
          ⚡ Жибергенден кийин сүрөт кошо аласыз. Мурунку активдүү реклама автоматтуу токтотулат.
        </p>

        <button
          className="ap-send-btn"
          onClick={handleSend}
          disabled={sending || (!form.title && !form.subtitle && !form.link_url)}
        >
          <Send size={16} />
          {sending ? 'Жиберилүүдө...' : 'Баардык колдонуучуга жиберүү'}
        </button>
      </div>

      {/* ── History ── */}
      {popups.filter(p => !p.is_active).length > 0 && (
        <div className="ap-history">
          <h2 className="ap-history-title">
            <Clock size={16} /> Тарых
          </h2>
          <div className="ap-history-list">
            {popups.filter(p => !p.is_active).map(p => (
              <div key={p.id} className="ap-history-item">
                {p.image_data && (
                  <img src={p.image_data} alt="" className="ap-history-img" />
                )}
                <div className="ap-history-info">
                  <div className="ap-history-name">
                    {p.title || <em>Аталышы жок</em>}
                  </div>
                  {p.subtitle && <div className="ap-history-sub">{p.subtitle}</div>}
                  <div className="ap-history-date">
                    {p.created_at
                      ? new Date(p.created_at).toLocaleString('ru-RU')
                      : ''}
                  </div>
                </div>
                <div className="ap-history-status">
                  <CheckCircle size={14} color="#aaa" />
                  <span>Жиберилди</span>
                </div>
                <button
                  className="ap-btn ap-btn-delete ap-btn-sm"
                  onClick={() => handleDelete(p.id)}
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <input
        type="file"
        ref={fileInputRef}
        style={{ display: 'none' }}
        accept="image/*"
        onChange={handleFileChange}
      />
    </div>
  );
}
