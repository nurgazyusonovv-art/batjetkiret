import { useEffect, useState } from 'react';
import { Plus, Pencil, Trash2, Check, X, ToggleLeft, ToggleRight } from 'lucide-react';
import api from '@/services/api';
import './IntercityPage.css';

interface IntercityCity {
  id: number;
  name: string;
  price: number;
  is_active: boolean;
}

export default function IntercityPage() {
  const [cities, setCities] = useState<IntercityCity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Add form
  const [addOpen, setAddOpen] = useState(false);
  const [addName, setAddName] = useState('');
  const [addPrice, setAddPrice] = useState('');
  const [addLoading, setAddLoading] = useState(false);

  // Edit form
  const [editId, setEditId] = useState<number | null>(null);
  const [editName, setEditName] = useState('');
  const [editPrice, setEditPrice] = useState('');
  const [editLoading, setEditLoading] = useState(false);

  const loadCities = async () => {
    try {
      setLoading(true);
      const res = await api.get<IntercityCity[]>('/admin/intercity/cities');
      setCities(res.data);
      setError('');
    } catch {
      setError('Шаарларды жүктөөдө ката');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadCities(); }, []);

  const handleAdd = async () => {
    if (!addName.trim() || !addPrice) return;
    setAddLoading(true);
    try {
      await api.post('/admin/intercity/cities', { name: addName.trim(), price: parseFloat(addPrice) });
      setAddName(''); setAddPrice(''); setAddOpen(false);
      await loadCities();
    } catch {
      alert('Кошууда ката кетти');
    } finally {
      setAddLoading(false);
    }
  };

  const startEdit = (c: IntercityCity) => {
    setEditId(c.id);
    setEditName(c.name);
    setEditPrice(String(c.price));
  };

  const cancelEdit = () => setEditId(null);

  const handleEdit = async (id: number) => {
    setEditLoading(true);
    try {
      await api.put(`/admin/intercity/cities/${id}`, { name: editName.trim(), price: parseFloat(editPrice) });
      setEditId(null);
      await loadCities();
    } catch {
      alert('Өзгөртүүдө ката кетти');
    } finally {
      setEditLoading(false);
    }
  };

  const handleToggle = async (c: IntercityCity) => {
    try {
      await api.put(`/admin/intercity/cities/${c.id}`, { is_active: !c.is_active });
      await loadCities();
    } catch {
      alert('Статусту өзгөртүүдө ката');
    }
  };

  const handleDelete = async (id: number, name: string) => {
    if (!confirm(`"${name}" шаарын жок кылуу?`)) return;
    try {
      await api.delete(`/admin/intercity/cities/${id}`);
      await loadCities();
    } catch {
      alert('Жок кылууда ката кетти');
    }
  };

  return (
    <div className="intercity-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Шаарлар аралык</h1>
          <p className="page-subtitle">Ар бир шаарга жеткирүү баасын башкаруу</p>
        </div>
        <button className="add-city-btn" onClick={() => setAddOpen(true)}>
          <Plus size={16} />
          Шаар кошуу
        </button>
      </div>

      {/* Add city form */}
      {addOpen && (
        <div className="city-form-card">
          <h3>Жаңы шаар кошуу</h3>
          <div className="city-form-row">
            <input
              className="city-input"
              placeholder="Шаардын аты (мисал: Бишкек)"
              value={addName}
              onChange={e => setAddName(e.target.value)}
            />
            <input
              className="city-input price-input"
              placeholder="Баасы (сом)"
              type="number"
              min="0"
              value={addPrice}
              onChange={e => setAddPrice(e.target.value)}
            />
            <button className="confirm-btn" onClick={handleAdd} disabled={addLoading}>
              {addLoading ? '...' : <Check size={16} />}
            </button>
            <button className="cancel-btn" onClick={() => { setAddOpen(false); setAddName(''); setAddPrice(''); }}>
              <X size={16} />
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="loading-text">Жүктөлүүдө...</div>
      ) : error ? (
        <div className="error-text">{error}</div>
      ) : cities.length === 0 ? (
        <div className="empty-state">
          <p>Шаарлар азырынча кошулган жок</p>
          <button className="add-city-btn" onClick={() => setAddOpen(true)}>
            <Plus size={16} /> Биринчи шаарды кошуу
          </button>
        </div>
      ) : (
        <div className="cities-grid">
          {cities.map(city => (
            <div key={city.id} className={`city-card ${!city.is_active ? 'inactive' : ''}`}>
              {editId === city.id ? (
                <div className="city-edit-form">
                  <input
                    className="city-input"
                    value={editName}
                    onChange={e => setEditName(e.target.value)}
                  />
                  <input
                    className="city-input price-input"
                    type="number"
                    min="0"
                    value={editPrice}
                    onChange={e => setEditPrice(e.target.value)}
                  />
                  <div className="city-edit-actions">
                    <button className="confirm-btn" onClick={() => handleEdit(city.id)} disabled={editLoading}>
                      {editLoading ? '...' : <Check size={15} />}
                    </button>
                    <button className="cancel-btn" onClick={cancelEdit}><X size={15} /></button>
                  </div>
                </div>
              ) : (
                <>
                  <div className="city-card-header">
                    <div className="city-icon">🏙️</div>
                    <div className={`city-status-dot ${city.is_active ? 'active' : 'inactive'}`} />
                  </div>
                  <div className="city-name">{city.name}</div>
                  <div className="city-price">{city.price.toLocaleString()} сом</div>
                  <div className="city-actions">
                    <button
                      className={`toggle-btn ${city.is_active ? 'on' : 'off'}`}
                      title={city.is_active ? 'Өчүрүү' : 'Күйгүзүү'}
                      onClick={() => handleToggle(city)}
                    >
                      {city.is_active ? <ToggleRight size={18} /> : <ToggleLeft size={18} />}
                    </button>
                    <button className="edit-btn" title="Өзгөртүү" onClick={() => startEdit(city)}>
                      <Pencil size={15} />
                    </button>
                    <button className="delete-btn" title="Жок кылуу" onClick={() => handleDelete(city.id, city.name)}>
                      <Trash2 size={15} />
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
