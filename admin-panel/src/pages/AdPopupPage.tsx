import { useState, useEffect, useRef } from 'react';
import { Send, Trash2, Upload, XCircle, CheckCircle, Clock, ImagePlus, X, Building2, Search } from 'lucide-react';
import api from '@/services/api';
import './AdPopupPage.css';

interface AdPopup {
  id: number;
  title: string | null;
  subtitle: string | null;
  image_data: string | null;
  link_url: string | null;
  enterprise_id: number | null;
  enterprise_name: string | null;
  enterprise_category: string | null;
  is_active: boolean;
  created_at: string | null;
}

interface EnterpriseOption {
  id: number;
  name: string;
  category: string;
}

const emptyForm = { title: '', subtitle: '', enterprise_id: null as number | null };

export default function AdPopupPage() {
  const [popups, setPopups] = useState<AdPopup[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [formImage, setFormImage] = useState<File | null>(null);
  const [formImagePreview, setFormImagePreview] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [uploadingId, setUploadingId] = useState<number | null>(null);
  const [enterprises, setEnterprises] = useState<EnterpriseOption[]>([]);
  const [entSearch, setEntSearch] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);
  const formImageInputRef = useRef<HTMLInputElement>(null);
  const pendingIdRef = useRef<number | null>(null);

  const load = async () => {
    try {
      const res = await api.get('/admin/ad-popup');
      setPopups(res.data);
    } finally {
      setLoading(false);
    }
  };

  const loadEnterprises = async () => {
    try {
      const res = await api.get('/enterprises/admin/list?limit=500&is_active=true');
      setEnterprises((res.data ?? []).map((e: any) => ({
        id: e.id, name: e.name, category: e.category,
      })));
    } catch {}
  };

  useEffect(() => { load(); loadEnterprises(); }, []);

  const handleFormImagePick = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setFormImage(file);
    setFormImagePreview(URL.createObjectURL(file));
  };

  const clearFormImage = () => {
    setFormImage(null);
    if (formImagePreview) URL.revokeObjectURL(formImagePreview);
    setFormImagePreview(null);
  };

  const handleSend = async () => {
    setSending(true);
    try {
      const res = await api.post('/admin/ad-popup', {
        title: form.title || null,
        subtitle: form.subtitle || null,
        enterprise_id: form.enterprise_id ?? null,
      });
      const newId: number = res.data.id;

      if (formImage) {
        const fd = new FormData();
        fd.append('file', formImage);
        await api.post(`/admin/ad-popup/${newId}/image`, fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }

      setForm(emptyForm);
      setEntSearch('');
      clearFormImage();
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
              {activePopup.enterprise_name && (
                <div className="ap-active-link">🏪 {activePopup.enterprise_name}</div>
              )}
              {activePopup.link_url && !activePopup.enterprise_name && (
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
          {/* Enterprise selector */}
          <div className="ap-field ap-field-full">
            <label><Building2 size={12} style={{ verticalAlign: 'middle', marginRight: 4 }} />Ишкана тандоо — милдеттүү эмес</label>
            {form.enterprise_id ? (
              <div className="ap-ent-selected">
                <Building2 size={16} color="#1565c0" />
                <span>{enterprises.find(e => e.id === form.enterprise_id)?.name ?? `#${form.enterprise_id}`}</span>
                <button className="ap-ent-clear" onClick={() => setForm(f => ({ ...f, enterprise_id: null }))}>
                  <X size={14} />
                </button>
              </div>
            ) : (
              <div className="ap-ent-search-wrap">
                <Search size={15} className="ap-ent-search-icon" />
                <input
                  className="ap-ent-search-input"
                  placeholder="Ишкана атын жаз..."
                  value={entSearch}
                  onChange={e => setEntSearch(e.target.value)}
                />
                {entSearch && (
                  <div className="ap-ent-dropdown">
                    {enterprises
                      .filter(e => e.name.toLowerCase().includes(entSearch.toLowerCase()))
                      .slice(0, 8)
                      .map(e => (
                        <div
                          key={e.id}
                          className="ap-ent-option"
                          onClick={() => { setForm(f => ({ ...f, enterprise_id: e.id })); setEntSearch(''); }}
                        >
                          <span className="ap-ent-name">{e.name}</span>
                          <span className="ap-ent-cat">{e.category}</span>
                        </div>
                      ))}
                    {enterprises.filter(e => e.name.toLowerCase().includes(entSearch.toLowerCase())).length === 0 && (
                      <div className="ap-ent-empty">Табылган жок</div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Image picker */}
          <div className="ap-field ap-field-full">
            <label>Сүрөт — милдеттүү эмес</label>
            {formImagePreview ? (
              <div className="ap-img-preview-wrap">
                <img src={formImagePreview} alt="preview" className="ap-img-preview" />
                <button className="ap-img-clear" onClick={clearFormImage} type="button">
                  <X size={16} />
                </button>
              </div>
            ) : (
              <button
                type="button"
                className="ap-img-pick-btn"
                onClick={() => formImageInputRef.current?.click()}
              >
                <ImagePlus size={20} />
                <span>Сүрөт тандоо</span>
              </button>
            )}
          </div>
        </div>

        <p className="ap-note">
          ⚡ Мурунку активдүү реклама автоматтуу токтотулат.
        </p>

        <button
          className="ap-send-btn"
          onClick={handleSend}
          disabled={sending || (!form.title && !form.subtitle && !form.enterprise_id && !formImage)}
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

      {/* hidden file inputs */}
      <input
        type="file"
        ref={fileInputRef}
        style={{ display: 'none' }}
        accept="image/*"
        onChange={handleFileChange}
      />
      <input
        type="file"
        ref={formImageInputRef}
        style={{ display: 'none' }}
        accept="image/*"
        onChange={handleFormImagePick}
      />
    </div>
  );
}
