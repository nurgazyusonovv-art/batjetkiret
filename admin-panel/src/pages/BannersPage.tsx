import { useState, useEffect, useRef } from 'react';
import { Plus, Trash2, Upload, Eye, EyeOff, GripVertical, Save, X } from 'lucide-react';
import api from '@/services/api';
import './BannersPage.css';

interface Banner {
  id: number;
  title: string | null;
  subtitle: string | null;
  image_data: string | null;
  link_url: string | null;
  is_active: boolean;
  sort_order: number;
}

const emptyForm = { title: '', subtitle: '', link_url: '', is_active: true, sort_order: 0 };

export default function BannersPage() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [uploadingId, setUploadingId] = useState<number | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pendingBannerIdRef = useRef<number | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const res = await api.get<Banner[]>('/admin/banners');
      setBanners(res.data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const handleCreate = async () => {
    setSaving(true);
    try {
      await api.post('/admin/banners', {
        title: form.title || null,
        subtitle: form.subtitle || null,
        link_url: form.link_url || null,
        is_active: form.is_active,
        sort_order: Number(form.sort_order),
      });
      setForm(emptyForm);
      setShowForm(false);
      load();
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Баннерди өчүрөсүзбү?')) return;
    await api.delete(`/admin/banners/${id}`);
    load();
  };

  const handleToggle = async (b: Banner) => {
    await api.put(`/admin/banners/${b.id}`, { is_active: !b.is_active });
    load();
  };

  const handleSortChange = async (b: Banner, order: number) => {
    await api.put(`/admin/banners/${b.id}`, { sort_order: order });
    load();
  };

  const handleUploadClick = (id: number) => {
    pendingBannerIdRef.current = id;
    fileInputRef.current?.click();
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    const id = pendingBannerIdRef.current;
    if (!file || !id) return;
    e.target.value = '';

    setUploadingId(id);
    try {
      const fd = new FormData();
      fd.append('file', file);
      await api.post(`/admin/banners/${id}/image`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      load();
    } finally {
      setUploadingId(null);
    }
  };

  return (
    <div className="banners-page">
      <div className="banners-header">
        <div>
          <h1>Реклама баннерлери</h1>
          <p>Башкы бетте карусель катары көрсөтүлөт</p>
        </div>
        <button className="btn-add" onClick={() => setShowForm(true)}>
          <Plus size={18} /> Баннер кошуу
        </button>
      </div>

      {/* Create form */}
      {showForm && (
        <div className="banner-form-card">
          <div className="banner-form-title">
            <span>Жаңы баннер</span>
            <button onClick={() => setShowForm(false)}><X size={18} /></button>
          </div>
          <div className="banner-form-grid">
            <div className="form-field">
              <label>Аталышы</label>
              <input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="Акция аталышы" />
            </div>
            <div className="form-field">
              <label>Кошумча текст</label>
              <input value={form.subtitle} onChange={e => setForm(f => ({ ...f, subtitle: e.target.value }))} placeholder="Кыскача сыпаттама" />
            </div>
            <div className="form-field">
              <label>Шилтеме (URL)</label>
              <input value={form.link_url} onChange={e => setForm(f => ({ ...f, link_url: e.target.value }))} placeholder="https://..." />
            </div>
            <div className="form-field">
              <label>Иреттелиши</label>
              <input type="number" value={form.sort_order} onChange={e => setForm(f => ({ ...f, sort_order: +e.target.value }))} />
            </div>
            <div className="form-field checkbox-field">
              <label>
                <input type="checkbox" checked={form.is_active} onChange={e => setForm(f => ({ ...f, is_active: e.target.checked }))} />
                Жигердүү (активдүү)
              </label>
            </div>
          </div>
          <div className="banner-form-actions">
            <button className="btn-cancel" onClick={() => setShowForm(false)}>Жокко чыгаруу</button>
            <button className="btn-save" onClick={handleCreate} disabled={saving}>
              <Save size={16} /> {saving ? 'Сакталууда...' : 'Сактоо'}
            </button>
          </div>
        </div>
      )}

      {/* Hidden file input */}
      <input ref={fileInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleFileChange} />

      {/* Banners list */}
      {loading ? (
        <div className="banners-loading">Жүктөлүүдө...</div>
      ) : banners.length === 0 ? (
        <div className="banners-empty">
          <div className="empty-icon">🖼️</div>
          <p>Баннерлер жок. "Баннер кошуу" баскычын басыңыз.</p>
        </div>
      ) : (
        <div className="banners-list">
          {banners.map(b => (
            <div key={b.id} className={`banner-card ${!b.is_active ? 'inactive' : ''}`}>
              {/* Preview */}
              <div className="banner-preview">
                {b.image_data ? (
                  <img src={b.image_data} alt={b.title ?? 'banner'} />
                ) : (
                  <div className="banner-no-image">
                    <span>Сүрөт жок</span>
                  </div>
                )}
                <div className="banner-order-badge">#{b.sort_order}</div>
              </div>

              {/* Info */}
              <div className="banner-info">
                <div className="banner-title">{b.title || <em>Аталышы жок</em>}</div>
                {b.subtitle && <div className="banner-subtitle">{b.subtitle}</div>}
                {b.link_url && <div className="banner-link">🔗 {b.link_url}</div>}
                <div className={`banner-status ${b.is_active ? 'active' : 'hidden'}`}>
                  {b.is_active ? 'Активдүү' : 'Жашырылган'}
                </div>
              </div>

              {/* Actions */}
              <div className="banner-actions">
                <button
                  className="action-btn upload"
                  onClick={() => handleUploadClick(b.id)}
                  disabled={uploadingId === b.id}
                  title="Сүрөт жүктөө"
                >
                  <Upload size={16} />
                  {uploadingId === b.id ? 'Жүктөлүүдө...' : 'Сүрөт'}
                </button>

                <button
                  className={`action-btn ${b.is_active ? 'hide' : 'show'}`}
                  onClick={() => handleToggle(b)}
                  title={b.is_active ? 'Жашыруу' : 'Көрсөтүү'}
                >
                  {b.is_active ? <EyeOff size={16} /> : <Eye size={16} />}
                  {b.is_active ? 'Жашыруу' : 'Көрсөтүү'}
                </button>

                <div className="order-controls">
                  <GripVertical size={14} style={{ color: '#aaa' }} />
                  <input
                    type="number"
                    className="order-input"
                    defaultValue={b.sort_order}
                    onBlur={e => handleSortChange(b, +e.target.value)}
                    title="Иреттелиши"
                  />
                </div>

                <button
                  className="action-btn delete"
                  onClick={() => handleDelete(b.id)}
                  title="Өчүрүү"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
