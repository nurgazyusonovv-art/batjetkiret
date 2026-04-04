import { useState, useEffect, useRef } from 'react';
import { Plus, Trash2, Upload, Eye, EyeOff, GripVertical, Save, X, Pencil } from 'lucide-react';
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
  view_count: number;
  show_days: number;
}

const emptyForm = { title: '', subtitle: '', link_url: '', is_active: true, sort_order: 0, show_days: 0 };

export default function BannersPage() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState(emptyForm);
  const [editSaving, setEditSaving] = useState(false);
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
        show_days: Number(form.show_days),
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

  const startEdit = (b: Banner) => {
    setEditingId(b.id);
    setEditForm({
      title: b.title ?? '',
      subtitle: b.subtitle ?? '',
      link_url: b.link_url ?? '',
      is_active: b.is_active,
      sort_order: b.sort_order,
      show_days: b.show_days ?? 0,
    });
  };

  const cancelEdit = () => {
    setEditingId(null);
  };

  const handleEdit = async () => {
    if (!editingId) return;
    setEditSaving(true);
    try {
      await api.put(`/admin/banners/${editingId}`, {
        title: editForm.title || null,
        subtitle: editForm.subtitle || null,
        link_url: editForm.link_url || null,
        is_active: editForm.is_active,
        sort_order: Number(editForm.sort_order),
        show_days: Number(editForm.show_days),
      });
      setEditingId(null);
      load();
    } finally {
      setEditSaving(false);
    }
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
            <div className="form-field">
              <label>Канча күн көрүнсүн (0 = чексиз)</label>
              <input type="number" min={0} value={form.show_days} onChange={e => setForm(f => ({ ...f, show_days: +e.target.value }))} placeholder="0" />
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
              {editingId === b.id ? (
                /* ── Edit form inline ── */
                <div className="banner-edit-form">
                  <div className="banner-form-title">
                    <span>Баннерди өзгөртүү</span>
                    <button onClick={cancelEdit}><X size={18} /></button>
                  </div>
                  <div className="banner-form-grid">
                    <div className="form-field">
                      <label>Аталышы</label>
                      <input value={editForm.title} onChange={e => setEditForm(f => ({ ...f, title: e.target.value }))} placeholder="Акция аталышы" />
                    </div>
                    <div className="form-field">
                      <label>Кошумча текст</label>
                      <input value={editForm.subtitle} onChange={e => setEditForm(f => ({ ...f, subtitle: e.target.value }))} placeholder="Кыскача сыпаттама" />
                    </div>
                    <div className="form-field">
                      <label>Шилтеме (URL)</label>
                      <input value={editForm.link_url} onChange={e => setEditForm(f => ({ ...f, link_url: e.target.value }))} placeholder="https://..." />
                    </div>
                    <div className="form-field">
                      <label>Иреттелиши</label>
                      <input type="number" value={editForm.sort_order} onChange={e => setEditForm(f => ({ ...f, sort_order: +e.target.value }))} />
                    </div>
                    <div className="form-field">
                      <label>Канча күн көрүнсүн (0 = чексиз)</label>
                      <input type="number" min={0} value={editForm.show_days} onChange={e => setEditForm(f => ({ ...f, show_days: +e.target.value }))} placeholder="0" />
                    </div>
                    <div className="form-field checkbox-field">
                      <label>
                        <input type="checkbox" checked={editForm.is_active} onChange={e => setEditForm(f => ({ ...f, is_active: e.target.checked }))} />
                        Жигердүү (активдүү)
                      </label>
                    </div>
                  </div>
                  <div className="banner-form-actions">
                    <button className="btn-cancel" onClick={cancelEdit}>Жокко чыгаруу</button>
                    <button className="btn-save" onClick={handleEdit} disabled={editSaving}>
                      <Save size={16} /> {editSaving ? 'Сакталууда...' : 'Сактоо'}
                    </button>
                  </div>
                </div>
              ) : (
                <>
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
                    <div className="banner-meta-row">
                      <span className="banner-views">👁 {b.view_count ?? 0} просмотр</span>
                      {b.show_days > 0 && (
                        <span className="banner-show-days">📅 {b.show_days} күн</span>
                      )}
                    </div>
                    <div className={`banner-status ${b.is_active ? 'active' : 'hidden'}`}>
                      {b.is_active ? 'Активдүү' : 'Жашырылган'}
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="banner-actions">
                    <button
                      className="action-btn edit"
                      onClick={() => startEdit(b)}
                      title="Өзгөртүү"
                    >
                      <Pencil size={16} /> Өзгөртүү
                    </button>

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
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
