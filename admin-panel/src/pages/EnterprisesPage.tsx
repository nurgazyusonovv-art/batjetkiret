import { useState, useEffect, useCallback, useRef } from 'react';
import {
  Building2, Plus, Pencil, Trash2, CheckCircle, XCircle,
  Search, X, MapPin, KeyRound, Eye, EyeOff,
} from 'lucide-react';
import { Enterprise, EnterpriseCreate, EnterpriseUpdate } from '@/types';
import { enterprisesService, EnterpriseCredentials } from '@/services/enterprises';
import { fmtDate } from '@/utils/date';
import './EnterprisesPage.css';

// ── Yandex Maps types ──────────────────────────────────────────────────────
declare global {
  interface Window {
    ymaps: any;
  }
}

function loadYmaps(apiKey: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (window.ymaps) { resolve(); return; }
    const script = document.createElement('script');
    script.src = `https://api-maps.yandex.ru/2.1/?apikey=${apiKey}&lang=ru_RU`;
    script.onload = () => window.ymaps.ready(resolve);
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

const YANDEX_API_KEY = import.meta.env.VITE_YANDEX_API_KEY ?? '';

const CATEGORIES = [
  { value: 'food', label: 'Тамак-аш' },
  { value: 'groceries', label: 'Азык-түлүк' },
  { value: 'pharmacy', label: 'Дарыкана' },
  { value: 'clothes', label: 'Кийим' },
  { value: 'electronics', label: 'Электроника' },
  { value: 'flowers', label: 'Гүлдөр' },
  { value: 'documents', label: 'Документтер' },
  { value: 'other', label: 'Башка' },
];

const catLabel = (v: string) => CATEGORIES.find((c) => c.value === v)?.label ?? v;

type FilterStatus = 'all' | 'active' | 'inactive';

interface FormState {
  name: string;
  category: string;
  phone: string;
  address: string;
  description: string;
  owner_user_id: string;
  lat: string;
  lon: string;
}

const emptyForm: FormState = {
  name: '', category: 'food', phone: '',
  address: '', description: '', owner_user_id: '',
  lat: '', lon: '',
};

// ── Map Picker ─────────────────────────────────────────────────────────────
interface MapPickerProps {
  initialLat?: number | null;
  initialLon?: number | null;
  onConfirm: (lat: number, lon: number) => void;
  onClose: () => void;
}

function MapPicker({ initialLat, initialLon, onConfirm, onClose }: MapPickerProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const ymapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const [picked, setPicked] = useState<{ lat: number; lon: number } | null>(
    initialLat != null && initialLon != null
      ? { lat: initialLat, lon: initialLon }
      : null
  );
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    loadYmaps(YANDEX_API_KEY).then(() => {
      if (cancelled || !mapRef.current) return;
      const center = picked ? [picked.lat, picked.lon] : [42.87, 74.59]; // Bishkek default
      const ymap = new window.ymaps.Map(mapRef.current, {
        center,
        zoom: 13,
        controls: ['zoomControl', 'fullscreenControl'],
      });
      ymapRef.current = ymap;

      if (picked) {
        const pm = new window.ymaps.Placemark([picked.lat, picked.lon], {}, {
          preset: 'islands#redDotIcon',
        });
        ymap.geoObjects.add(pm);
        markerRef.current = pm;
      }

      ymap.events.add('click', (e: any) => {
        const coords: [number, number] = e.get('coords');
        const lat = parseFloat(coords[0].toFixed(6));
        const lon = parseFloat(coords[1].toFixed(6));
        setPicked({ lat, lon });
        if (markerRef.current) ymap.geoObjects.remove(markerRef.current);
        const pm = new window.ymaps.Placemark([lat, lon], {}, {
          preset: 'islands#redDotIcon',
        });
        ymap.geoObjects.add(pm);
        markerRef.current = pm;
      });

      setLoading(false);
    }).catch(() => setLoading(false));

    return () => { cancelled = true; ymapRef.current?.destroy(); };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="ent-map-overlay" onClick={onClose}>
      <div className="ent-map-modal" onClick={(e) => e.stopPropagation()}>
        <div className="ent-map-modal-header">
          <h3>Картадан жайгашкан жерди белгилеңиз</h3>
          <button className="ent-modal-close" onClick={onClose}><X size={20} /></button>
        </div>
        <div className="ent-map-hint">
          Картага чыкылдатып ишкананын так жайгашкан жерин белгилеңиз
        </div>
        <div
          ref={mapRef}
          className="ent-map-container"
          style={{ background: '#e5e7eb', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          {loading && <span style={{ color: '#6b7280', fontSize: 14 }}>Карта жүктөлүүдө...</span>}
        </div>
        <div className="ent-map-footer">
          <div className="ent-map-coords-display">
            {picked
              ? `${picked.lat}, ${picked.lon}`
              : 'Белги коюлган жок'}
          </div>
          <div className="ent-map-footer-btns">
            <button className="ent-btn-secondary" onClick={onClose}>Жокко чыгаруу</button>
            <button
              className="ent-btn-confirm"
              disabled={!picked}
              onClick={() => picked && onConfirm(picked.lat, picked.lon)}
            >
              Тастыктоо
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────
export default function EnterprisesPage() {
  const [enterprises, setEnterprises] = useState<Enterprise[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState<FilterStatus>('all');
  const [filterCategory, setFilterCategory] = useState('');

  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState('');

  const [showMap, setShowMap] = useState(false);

  // Credentials modal
  const [credEnterprise, setCredEnterprise] = useState<Enterprise | null>(null);
  const [existingCreds, setExistingCreds] = useState<EnterpriseCredentials | null>(null);
  const [credPhone, setCredPhone] = useState('');
  const [credPassword, setCredPassword] = useState('');
  const [credName, setCredName] = useState('');
  const [credShowPwd, setCredShowPwd] = useState(false);
  const [credSaving, setCredSaving] = useState(false);
  const [credError, setCredError] = useState('');
  const [credSuccess, setCredSuccess] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params: { is_active?: boolean; category?: string } = {};
      if (filterStatus === 'active') params.is_active = true;
      if (filterStatus === 'inactive') params.is_active = false;
      if (filterCategory) params.category = filterCategory;
      setEnterprises(await enterprisesService.list(params));
    } catch (e: any) {
      setError(e?.response?.data?.detail ?? 'Жүктөөдө ката кетти');
    } finally {
      setLoading(false);
    }
  }, [filterStatus, filterCategory]);

  useEffect(() => { load(); }, [load]);

  const filtered = enterprises.filter((e) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      e.name.toLowerCase().includes(q) ||
      (e.owner_phone ?? '').toLowerCase().includes(q) ||
      (e.owner_name ?? '').toLowerCase().includes(q) ||
      (e.address ?? '').toLowerCase().includes(q)
    );
  });

  // ── Modal ────────────────────────────────────────────────────────────────

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm);
    setFormError('');
    setShowModal(true);
  };

  const openEdit = (e: Enterprise) => {
    setEditingId(e.id);
    setForm({
      name: e.name,
      category: e.category,
      phone: e.phone ?? '',
      address: e.address ?? '',
      description: e.description ?? '',
      owner_user_id: String(e.owner_user_id),
      lat: e.lat != null ? String(e.lat) : '',
      lon: e.lon != null ? String(e.lon) : '',
    });
    setFormError('');
    setShowModal(true);
  };

  const closeModal = () => { setShowModal(false); setFormError(''); };

  const handleSave = async () => {
    if (!form.name.trim()) { setFormError('Ишканынын аты талап кылынат'); return; }
    setSaving(true);
    setFormError('');
    try {
      const latVal = form.lat !== '' ? parseFloat(form.lat) : undefined;
      const lonVal = form.lon !== '' ? parseFloat(form.lon) : undefined;

      if (editingId !== null) {
        const upd: EnterpriseUpdate = {
          name: form.name.trim(),
          category: form.category,
          phone: form.phone.trim() || undefined,
          address: form.address.trim() || undefined,
          description: form.description.trim() || undefined,
          lat: latVal ?? null,
          lon: lonVal ?? null,
        };
        await enterprisesService.update(editingId, upd);
      } else {
        const cre: EnterpriseCreate = {
          name: form.name.trim(),
          category: form.category,
          phone: form.phone.trim() || undefined,
          address: form.address.trim() || undefined,
          description: form.description.trim() || undefined,
          lat: latVal,
          lon: lonVal,
          owner_user_id: Number(form.owner_user_id) || 0,
        };
        await enterprisesService.create(cre);
      }
      closeModal();
      load();
    } catch (e: any) {
      setFormError(e?.response?.data?.detail ?? 'Сактоодо ката кетти');
    } finally {
      setSaving(false);
    }
  };

  const handleActivate = async (id: number) => {
    try { await enterprisesService.activate(id); load(); }
    catch (e: any) { alert(e?.response?.data?.detail ?? 'Ката кетти'); }
  };

  const handleDeactivate = async (id: number) => {
    try { await enterprisesService.deactivate(id); load(); }
    catch (e: any) { alert(e?.response?.data?.detail ?? 'Ката кетти'); }
  };

  const handleDelete = async (id: number, name: string) => {
    if (!confirm(`"${name}" ишканасын өчүрөсүзбү? Бул аракетти кайтарып болбойт.`)) return;
    try { await enterprisesService.delete(id); load(); }
    catch (e: any) { alert(e?.response?.data?.detail ?? 'Ката кетти'); }
  };

  const handleMapConfirm = (lat: number, lon: number) => {
    setForm((f) => ({ ...f, lat: String(lat), lon: String(lon) }));
    setShowMap(false);
  };

  // ── Credentials modal ────────────────────────────────────────────────────

  const openCredentials = async (e: Enterprise) => {
    setCredEnterprise(e);
    setCredPhone('');
    setCredPassword('');
    setCredName(e.name);
    setCredError('');
    setCredSuccess('');
    setCredShowPwd(false);
    try {
      const creds = await enterprisesService.getCredentials(e.id);
      setExistingCreds(creds);
      if (creds.has_credentials && creds.phone) setCredPhone(creds.phone);
      if (creds.has_credentials && creds.name) setCredName(creds.name);
    } catch {
      setExistingCreds(null);
    }
  };

  const closeCredentials = () => { setCredEnterprise(null); setCredSuccess(''); };

  const handleSaveCreds = async () => {
    if (!credEnterprise) return;
    if (!credPhone.trim()) { setCredError('Телефон талап кылынат'); return; }
    if (!existingCreds?.has_credentials && !credPassword.trim()) {
      setCredError('Сырсөз талап кылынат'); return;
    }
    setCredSaving(true);
    setCredError('');
    setCredSuccess('');
    try {
      await enterprisesService.setCredentials(
        credEnterprise.id,
        credPhone.trim(),
        credPassword.trim() || '___unchanged___',
        credName.trim() || undefined,
      );
      setCredSuccess('Кирүү маалыматтары сакталды!');
      setCredPassword('');
      const creds = await enterprisesService.getCredentials(credEnterprise.id);
      setExistingCreds(creds);
    } catch (e: any) {
      setCredError(e?.response?.data?.detail ?? 'Сактоодо ката кетти');
    } finally {
      setCredSaving(false);
    }
  };

  // ── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="enterprises-page">

      {/* Header */}
      <div className="enterprises-header">
        <div className="enterprises-title">
          <Building2 size={26} />
          <h1>Ишканалар</h1>
          <span className="count-badge">{filtered.length}</span>
        </div>
        <button className="ent-btn-primary" onClick={openCreate}>
          <Plus size={16} />
          Жаңы ишкана
        </button>
      </div>

      {/* Filters */}
      <div className="ent-filters">
        <div className="ent-search">
          <Search size={16} />
          <input
            type="text"
            placeholder="Издөө (ат, телефон, дарек)..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="ent-search-clear" onClick={() => setSearch('')}>
              <X size={14} />
            </button>
          )}
        </div>

        <select
          className="ent-filter-select"
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value as FilterStatus)}
        >
          <option value="all">Баардыгы</option>
          <option value="active">Активдүү</option>
          <option value="inactive">Активдүү эмес</option>
        </select>

        <select
          className="ent-filter-select"
          value={filterCategory}
          onChange={(e) => setFilterCategory(e.target.value)}
        >
          <option value="">Бардык категориялар</option>
          {CATEGORIES.map((c) => (
            <option key={c.value} value={c.value}>{c.label}</option>
          ))}
        </select>
      </div>

      {error && <div className="ent-error">{error}</div>}

      {/* Table */}
      {loading ? (
        <div className="ent-loading">Жүктөлүүдө...</div>
      ) : (
        <div className="ent-table-wrap">
          <table className="ent-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Ишкана</th>
                <th>Категория</th>
                <th>Ээси</th>
                <th>Телефон</th>
                <th>Координаттар</th>
                <th>Статус</th>
                <th>Катталган</th>
                <th>Аракеттер</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={9}>
                    <div className="ent-empty">
                      <Building2 size={40} />
                      <p>Ишкана табылган жок</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map((e) => (
                  <tr key={e.id}>
                    <td><span className="ent-id">#{e.id}</span></td>
                    <td>
                      <div className="ent-name-main">{e.name}</div>
                      {e.address && <div className="ent-name-desc">{e.address}</div>}
                    </td>
                    <td><span className="ent-cat-badge">{catLabel(e.category)}</span></td>
                    <td>
                      <div className="ent-owner-name">{e.owner_name ?? '—'}</div>
                      {e.owner_phone && <div className="ent-owner-phone">{e.owner_phone}</div>}
                    </td>
                    <td>{e.phone ?? <span style={{ color: '#d1d5db' }}>—</span>}</td>
                    <td>
                      {e.lat != null && e.lon != null ? (
                        <span className="ent-coords">{e.lat.toFixed(4)}, {e.lon.toFixed(4)}</span>
                      ) : (
                        <span className="ent-coords-none">—</span>
                      )}
                    </td>
                    <td>
                      {e.is_active
                        ? <span className="ent-status-active"><CheckCircle size={12} />Активдүү</span>
                        : <span className="ent-status-pending">Күтүүдө</span>
                      }
                    </td>
                    <td>{fmtDate(e.created_at)}</td>
                    <td>
                      <div className="ent-actions">
                        <button
                          className="ent-action-btn ent-btn-edit"
                          title="Өзгөртүү"
                          onClick={() => openEdit(e)}
                        >
                          <Pencil size={14} />
                        </button>
                        {e.is_active ? (
                          <button
                            className="ent-action-btn ent-btn-deactivate"
                            title="Деактивдештирүү"
                            onClick={() => handleDeactivate(e.id)}
                          >
                            <XCircle size={14} />
                          </button>
                        ) : (
                          <button
                            className="ent-action-btn ent-btn-activate"
                            title="Активдештирүү"
                            onClick={() => handleActivate(e.id)}
                          >
                            <CheckCircle size={14} />
                          </button>
                        )}
                        <button
                          className="ent-action-btn ent-btn-creds"
                          title="Кирүү маалыматтары"
                          onClick={() => openCredentials(e)}
                        >
                          <KeyRound size={14} />
                        </button>
                        <button
                          className="ent-action-btn ent-btn-delete"
                          title="Өчүрүү"
                          onClick={() => handleDelete(e.id, e.name)}
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Create/Edit Modal */}
      {showModal && (
        <div className="ent-modal-overlay" onClick={closeModal}>
          <div className="ent-modal" onClick={(e) => e.stopPropagation()}>
            <div className="ent-modal-header">
              <h2>{editingId !== null ? 'Ишкананы өзгөртүү' : 'Жаңы ишкана кошуу'}</h2>
              <button className="ent-modal-close" onClick={closeModal}><X size={20} /></button>
            </div>

            <div className="ent-modal-body">
              {formError && <div className="ent-form-error">{formError}</div>}

              <div className="ent-form-row">
                <div className="ent-form-group" style={{ gridColumn: '1 / -1' }}>
                  <label>Аты *</label>
                  <input
                    type="text"
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                    placeholder="Ишканынын аты"
                  />
                </div>
              </div>

              <div className="ent-form-row">
                <div className="ent-form-group">
                  <label>Категория *</label>
                  <select
                    value={form.category}
                    onChange={(e) => setForm({ ...form, category: e.target.value })}
                  >
                    {CATEGORIES.map((c) => (
                      <option key={c.value} value={c.value}>{c.label}</option>
                    ))}
                  </select>
                </div>
                <div className="ent-form-group">
                  <label>Телефон</label>
                  <input
                    type="text"
                    value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                    placeholder="+996 XXX XXX XXX"
                  />
                </div>
              </div>

              <div className="ent-form-group">
                <label>Дарек</label>
                <input
                  type="text"
                  value={form.address}
                  onChange={(e) => setForm({ ...form, address: e.target.value })}
                  placeholder="Шаар, көчө, үй номери"
                />
              </div>

              <div className="ent-form-group">
                <label>Сүрөттөмө</label>
                <textarea
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  placeholder="Кыскача маалымат..."
                />
              </div>

              {/* Coordinates */}
              <div className="ent-coords-section">
                <div className="ent-coords-title">
                  <MapPin size={14} color="#667eea" />
                  Жайгашкан жер (координаттар)
                </div>
                <div className="ent-coords-inputs">
                  <input
                    type="number"
                    step="any"
                    value={form.lat}
                    onChange={(e) => setForm({ ...form, lat: e.target.value })}
                    placeholder="Кеңдик (lat)"
                  />
                  <input
                    type="number"
                    step="any"
                    value={form.lon}
                    onChange={(e) => setForm({ ...form, lon: e.target.value })}
                    placeholder="Узундук (lon)"
                  />
                </div>
                <button className="ent-map-btn" onClick={() => setShowMap(true)}>
                  <MapPin size={15} />
                  Картадан белгилөө
                </button>
              </div>

              {editingId === null && (
                <div className="ent-form-group">
                  <label>Ээсинин колдонуучу ID</label>
                  <input
                    type="number"
                    value={form.owner_user_id}
                    onChange={(e) => setForm({ ...form, owner_user_id: e.target.value })}
                    placeholder="1"
                  />
                  <span className="ent-form-hint">
                    Колдонуучунун ID-син киргизиңиз (0 болсо автоматтык)
                  </span>
                </div>
              )}
            </div>

            <div className="ent-modal-footer">
              <button className="ent-btn-secondary" onClick={closeModal} disabled={saving}>
                Жокко чыгаруу
              </button>
              <button className="ent-btn-primary" onClick={handleSave} disabled={saving}>
                {saving ? 'Сакталууда...' : 'Сактоо'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Map Picker */}
      {showMap && (
        <MapPicker
          initialLat={form.lat !== '' ? parseFloat(form.lat) : null}
          initialLon={form.lon !== '' ? parseFloat(form.lon) : null}
          onConfirm={handleMapConfirm}
          onClose={() => setShowMap(false)}
        />
      )}

      {/* Credentials Modal */}
      {credEnterprise && (
        <div className="ent-modal-overlay" onClick={closeCredentials}>
          <div className="ent-modal" onClick={(e) => e.stopPropagation()}>
            <div className="ent-modal-header">
              <h2>
                <KeyRound size={18} style={{ marginRight: 8, verticalAlign: 'middle', color: '#667eea' }} />
                Кирүү маалыматтары — {credEnterprise.name}
              </h2>
              <button className="ent-modal-close" onClick={closeCredentials}><X size={20} /></button>
            </div>

            <div className="ent-modal-body">
              {/* Status banner */}
              {existingCreds?.has_credentials ? (
                <div className="ent-creds-info ent-creds-has">
                  <CheckCircle size={15} />
                  <div>
                    <strong>Кирүү маалыматтары бар:</strong> {existingCreds.phone}
                    <div style={{ fontSize: 12, marginTop: 2, color: '#065f46' }}>
                      Ишкана панелине кире алат
                    </div>
                  </div>
                </div>
              ) : (
                <div className="ent-creds-info ent-creds-none">
                  <XCircle size={15} />
                  <div>
                    <strong>Кирүү маалыматтары жок</strong>
                    <div style={{ fontSize: 12, marginTop: 2 }}>
                      Ишкана панелине кирүү үчүн телефон жана сырсөз белгилеңиз
                    </div>
                  </div>
                </div>
              )}

              {credError && <div className="ent-form-error">{credError}</div>}
              {credSuccess && (
                <div className="ent-creds-success">
                  <CheckCircle size={14} />
                  {credSuccess}
                </div>
              )}

              <div className="ent-form-group">
                <label>Колдонуучунун аты</label>
                <input
                  type="text"
                  value={credName}
                  onChange={(e) => setCredName(e.target.value)}
                  placeholder="Ишкана аты же жооптуу адам"
                />
              </div>

              <div className="ent-form-group">
                <label>Телефон номери (логин) *</label>
                <input
                  type="text"
                  value={credPhone}
                  onChange={(e) => setCredPhone(e.target.value)}
                  placeholder="+996XXXXXXXXX"
                />
              </div>

              <div className="ent-form-group">
                <label>
                  {existingCreds?.has_credentials ? 'Жаңы сырсөз (бош калтырсаңыз өзгөрбөйт)' : 'Сырсөз *'}
                </label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={credShowPwd ? 'text' : 'password'}
                    value={credPassword}
                    onChange={(e) => setCredPassword(e.target.value)}
                    placeholder={existingCreds?.has_credentials ? '••••••••  (бош калтырса өзгөрбөйт)' : 'Сырсөз киргизиңиз'}
                    style={{ paddingRight: 40 }}
                  />
                  <button
                    type="button"
                    onClick={() => setCredShowPwd(!credShowPwd)}
                    style={{
                      position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)',
                      background: 'none', border: 'none', cursor: 'pointer', color: '#9ca3af',
                    }}
                  >
                    {credShowPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              <div className="ent-creds-hint">
                Ишкана жооптуу адамына бул телефон жана сырсөздү бериңиз. Алар
                <strong> ишкана панелине</strong> кирип, заказдарды башкара алат.
              </div>
            </div>

            <div className="ent-modal-footer">
              <button className="ent-btn-secondary" onClick={closeCredentials} disabled={credSaving}>
                Жабуу
              </button>
              <button className="ent-btn-primary" onClick={handleSaveCreds} disabled={credSaving}>
                {credSaving ? 'Сакталууда...' : 'Сактоо'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
