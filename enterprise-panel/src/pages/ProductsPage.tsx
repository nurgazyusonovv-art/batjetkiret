import { useState, useEffect, useCallback } from 'react';
import { Plus, Pencil, Trash2, Tag, Package, X, ChevronRight, ToggleLeft, ToggleRight } from 'lucide-react';
import { productsService, Category, Product } from '../services/products';
import './ProductsPage.css';

interface CatForm { name: string; sort_order: string; }
interface ProdForm { name: string; price: string; description: string; category_id: string; sort_order: string; }

const emptyCatForm: CatForm = { name: '', sort_order: '0' };
const emptyProdForm: ProdForm = { name: '', price: '', description: '', category_id: '', sort_order: '0' };

export default function ProductsPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedCat, setSelectedCat] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);

  // Category modal
  const [showCatModal, setShowCatModal] = useState(false);
  const [editingCat, setEditingCat] = useState<Category | null>(null);
  const [catForm, setCatForm] = useState<CatForm>(emptyCatForm);
  const [catSaving, setCatSaving] = useState(false);
  const [catError, setCatError] = useState('');

  // Product modal
  const [showProdModal, setShowProdModal] = useState(false);
  const [editingProd, setEditingProd] = useState<Product | null>(null);
  const [prodForm, setProdForm] = useState<ProdForm>(emptyProdForm);
  const [prodSaving, setProdSaving] = useState(false);
  const [prodError, setProdError] = useState('');

  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      const [cats, prods] = await Promise.all([
        productsService.getCategories(),
        productsService.getProducts(),
      ]);
      setCategories(cats);
      setProducts(prods);
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { loadAll(); }, [loadAll]);

  const filteredProducts = selectedCat === null
    ? products
    : selectedCat === 0
    ? products.filter(p => !p.category_id)
    : products.filter(p => p.category_id === selectedCat);

  // ── Category handlers ──────────────────────────────────────────────────
  const openCatCreate = () => { setEditingCat(null); setCatForm(emptyCatForm); setCatError(''); setShowCatModal(true); };
  const openCatEdit = (c: Category) => { setEditingCat(c); setCatForm({ name: c.name, sort_order: String(c.sort_order) }); setCatError(''); setShowCatModal(true); };

  const saveCat = async () => {
    if (!catForm.name.trim()) { setCatError('Аты талап кылынат'); return; }
    setCatSaving(true); setCatError('');
    try {
      if (editingCat) {
        await productsService.updateCategory(editingCat.id, { name: catForm.name.trim(), sort_order: Number(catForm.sort_order) });
      } else {
        await productsService.createCategory(catForm.name.trim(), Number(catForm.sort_order));
      }
      setShowCatModal(false);
      loadAll();
    } catch (e: unknown) { setCatError((e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? 'Ката кетти'); }
    finally { setCatSaving(false); }
  };

  const deleteCat = async (id: number, name: string) => {
    if (!confirm(`"${name}" категориясын өчүрөсүзбү?`)) return;
    try { await productsService.deleteCategory(id); loadAll(); }
    catch (e: unknown) { alert((e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? 'Ката кетти'); }
  };

  const toggleCat = async (c: Category) => {
    try { await productsService.updateCategory(c.id, { is_active: !c.is_active }); loadAll(); }
    catch (e: unknown) { alert((e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? 'Ката кетти'); }
  };

  // ── Product handlers ───────────────────────────────────────────────────
  const openProdCreate = () => {
    setEditingProd(null);
    setProdForm({ ...emptyProdForm, category_id: selectedCat && selectedCat > 0 ? String(selectedCat) : '' });
    setProdError(''); setShowProdModal(true);
  };
  const openProdEdit = (p: Product) => {
    setEditingProd(p);
    setProdForm({ name: p.name, price: String(p.price), description: p.description ?? '', category_id: p.category_id ? String(p.category_id) : '', sort_order: String(p.sort_order) });
    setProdError(''); setShowProdModal(true);
  };

  const saveProd = async () => {
    if (!prodForm.name.trim()) { setProdError('Аты талап кылынат'); return; }
    if (!prodForm.price || isNaN(Number(prodForm.price))) { setProdError('Баасы талап кылынат'); return; }
    setProdSaving(true); setProdError('');
    try {
      const payload = {
        name: prodForm.name.trim(),
        price: Number(prodForm.price),
        description: prodForm.description.trim() || undefined,
        category_id: prodForm.category_id ? Number(prodForm.category_id) : undefined,
        sort_order: Number(prodForm.sort_order),
      };
      if (editingProd) {
        await productsService.updateProduct(editingProd.id, payload);
      } else {
        await productsService.createProduct(payload);
      }
      setShowProdModal(false);
      loadAll();
    } catch (e: unknown) { setProdError((e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? 'Ката кетти'); }
    finally { setProdSaving(false); }
  };

  const deleteProd = async (id: number, name: string) => {
    if (!confirm(`"${name}" товарын өчүрөсүзбү?`)) return;
    try { await productsService.deleteProduct(id); loadAll(); }
    catch (e: unknown) { alert((e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? 'Ката кетти'); }
  };

  const toggleProd = async (p: Product) => {
    try { await productsService.updateProduct(p.id, { is_active: !p.is_active }); loadAll(); }
    catch (e: unknown) { alert((e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? 'Ката кетти'); }
  };

  return (
    <div className="products-page">
      <div className="products-header">
        <div className="products-title">
          <Package size={24} />
          <h1>Менюну башкаруу</h1>
        </div>
      </div>

      <div className="products-layout">
        {/* Left: Categories */}
        <aside className="categories-panel">
          <div className="panel-header">
            <span className="panel-title"><Tag size={15} />Категориялар</span>
            <button className="ep-btn-icon-add" onClick={openCatCreate} title="Кошуу"><Plus size={15} /></button>
          </div>

          {loading ? <div className="panel-loading">Жүктөлүүдө...</div> : (
            <ul className="cat-list">
              <li className={`cat-item ${selectedCat === null ? 'active' : ''}`} onClick={() => setSelectedCat(null)}>
                <span>Баардыгы</span>
                <span className="cat-count">{products.length}</span>
              </li>
              <li className={`cat-item ${selectedCat === 0 ? 'active' : ''}`} onClick={() => setSelectedCat(0)}>
                <span>Категориясыз</span>
                <span className="cat-count">{products.filter(p => !p.category_id).length}</span>
              </li>
              {categories.map(c => (
                <li key={c.id} className={`cat-item ${selectedCat === c.id ? 'active' : ''} ${!c.is_active ? 'inactive' : ''}`}>
                  <span className="cat-name" onClick={() => setSelectedCat(c.id)}>
                    <ChevronRight size={13} />
                    {c.name}
                  </span>
                  <span className="cat-count">{products.filter(p => p.category_id === c.id).length}</span>
                  <div className="cat-actions">
                    <button onClick={() => openCatEdit(c)} title="Өзгөртүү"><Pencil size={12} /></button>
                    <button onClick={() => toggleCat(c)} title={c.is_active ? 'Өчүрүү' : 'Күйгүзүү'}>
                      {c.is_active ? <ToggleRight size={14} color="#4f46e5" /> : <ToggleLeft size={14} color="#9ca3af" />}
                    </button>
                    <button onClick={() => deleteCat(c.id, c.name)} title="Жок кылуу"><Trash2 size={12} /></button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </aside>

        {/* Right: Products */}
        <main className="products-panel">
          <div className="panel-header">
            <span className="panel-title">
              <Package size={15} />
              {selectedCat === null ? 'Бардык товарлар' : selectedCat === 0 ? 'Категориясыз' : categories.find(c => c.id === selectedCat)?.name ?? ''}
              <span className="cat-count">{filteredProducts.length}</span>
            </span>
            <button className="ep-btn-primary-sm" onClick={openProdCreate}>
              <Plus size={14} />Товар кошуу
            </button>
          </div>

          {loading ? <div className="panel-loading">Жүктөлүүдө...</div> : filteredProducts.length === 0 ? (
            <div className="products-empty">
              <Package size={40} opacity={0.2} />
              <p>Товар табылган жок</p>
              <button className="ep-btn-primary-sm" onClick={openProdCreate}><Plus size={14} />Биринчи товарды кошуу</button>
            </div>
          ) : (
            <div className="products-grid">
              {filteredProducts.map(p => (
                <div key={p.id} className={`product-card ${!p.is_active ? 'inactive' : ''}`}>
                  <div className="product-card-header">
                    <span className="product-name">{p.name}</span>
                    <span className="product-price">{p.price.toFixed(0)} сом</span>
                  </div>
                  {p.description && <p className="product-desc">{p.description}</p>}
                  {p.category_name && <span className="product-cat-tag">{p.category_name}</span>}
                  <div className="product-card-footer">
                    <span className={`product-status ${p.is_active ? 'active' : 'inactive'}`}>
                      {p.is_active ? 'Активдүү' : 'Жашырылган'}
                    </span>
                    <div className="product-actions">
                      <button onClick={() => toggleProd(p)} title={p.is_active ? 'Жашыруу' : 'Көрсөтүү'}>
                        {p.is_active ? <ToggleRight size={16} color="#4f46e5" /> : <ToggleLeft size={16} color="#9ca3af" />}
                      </button>
                      <button onClick={() => openProdEdit(p)} title="Өзгөртүү"><Pencil size={14} /></button>
                      <button onClick={() => deleteProd(p.id, p.name)} title="Өчүрүү"><Trash2 size={14} /></button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </main>
      </div>

      {/* Category Modal */}
      {showCatModal && (
        <div className="ep-modal-overlay" onClick={() => setShowCatModal(false)}>
          <div className="ep-modal-sm" onClick={e => e.stopPropagation()}>
            <div className="ep-modal-header">
              <h3>{editingCat ? 'Категорияны өзгөртүү' : 'Жаңы категория'}</h3>
              <button onClick={() => setShowCatModal(false)}><X size={18} /></button>
            </div>
            <div className="ep-modal-body">
              {catError && <div className="ep-form-error">{catError}</div>}
              <div className="ep-form-group">
                <label>Аты *</label>
                <input value={catForm.name} onChange={e => setCatForm({...catForm, name: e.target.value})} placeholder="Мис: Бургерлер, Суусундуктар" autoFocus />
              </div>
              <div className="ep-form-group">
                <label>Тартип (аз = биринчи)</label>
                <input type="number" value={catForm.sort_order} onChange={e => setCatForm({...catForm, sort_order: e.target.value})} />
              </div>
            </div>
            <div className="ep-modal-footer">
              <button className="ep-btn-secondary-sm" onClick={() => setShowCatModal(false)}>Жокко</button>
              <button className="ep-btn-primary-sm" onClick={saveCat} disabled={catSaving}>{catSaving ? 'Сакталууда...' : 'Сактоо'}</button>
            </div>
          </div>
        </div>
      )}

      {/* Product Modal */}
      {showProdModal && (
        <div className="ep-modal-overlay" onClick={() => setShowProdModal(false)}>
          <div className="ep-modal-sm" style={{ width: 480 }} onClick={e => e.stopPropagation()}>
            <div className="ep-modal-header">
              <h3>{editingProd ? 'Товарды өзгөртүү' : 'Жаңы товар'}</h3>
              <button onClick={() => setShowProdModal(false)}><X size={18} /></button>
            </div>
            <div className="ep-modal-body">
              {prodError && <div className="ep-form-error">{prodError}</div>}
              <div className="ep-form-row">
                <div className="ep-form-group" style={{ flex: 2 }}>
                  <label>Аты *</label>
                  <input value={prodForm.name} onChange={e => setProdForm({...prodForm, name: e.target.value})} placeholder="Товардын аты" autoFocus />
                </div>
                <div className="ep-form-group" style={{ flex: 1 }}>
                  <label>Баасы (сом) *</label>
                  <input type="number" value={prodForm.price} onChange={e => setProdForm({...prodForm, price: e.target.value})} placeholder="0" />
                </div>
              </div>
              <div className="ep-form-group">
                <label>Сүрөттөмө</label>
                <textarea value={prodForm.description} onChange={e => setProdForm({...prodForm, description: e.target.value})} placeholder="Кыскача маалымат..." rows={2} />
              </div>
              <div className="ep-form-row">
                <div className="ep-form-group" style={{ flex: 2 }}>
                  <label>Категория</label>
                  <select value={prodForm.category_id} onChange={e => setProdForm({...prodForm, category_id: e.target.value})}>
                    <option value="">— Категориясыз —</option>
                    {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                  </select>
                </div>
                <div className="ep-form-group" style={{ flex: 1 }}>
                  <label>Тартип</label>
                  <input type="number" value={prodForm.sort_order} onChange={e => setProdForm({...prodForm, sort_order: e.target.value})} />
                </div>
              </div>
            </div>
            <div className="ep-modal-footer">
              <button className="ep-btn-secondary-sm" onClick={() => setShowProdModal(false)}>Жокко</button>
              <button className="ep-btn-primary-sm" onClick={saveProd} disabled={prodSaving}>{prodSaving ? 'Сакталууда...' : 'Сактоо'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
