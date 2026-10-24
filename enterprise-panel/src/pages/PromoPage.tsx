import { useCallback, useEffect, useRef, useState } from 'react';
import { Megaphone, ImagePlus, X, Send, Clock, RefreshCw, Undo2 } from 'lucide-react';
import { productsService, Product } from '../services/products';
import { campaignsService, PromoCampaign, CampaignStatus } from '../services/campaigns';
import { fmtDateTime, parseUtc } from '../utils/date';
import './PromoPage.css';

const TITLE_MAX = 100;
const MESSAGE_MAX = 500;

const STATUS_LABELS: Record<CampaignStatus, string> = {
  pending_review: 'Текшерүүдө',
  scheduled: 'Жөнөтүлөт',
  sending: 'Жөнөтүлүүдө',
  sent: 'Жөнөтүлдү',
  cancelled: 'Кайтарылып алынды',
  failed: 'Ката',
  rejected: 'Четке кагылды',
};

function errorText(err: unknown, fallback: string): string {
  const e = err as { response?: { data?: { detail?: unknown } } };
  const detail = e?.response?.data?.detail;
  return typeof detail === 'string' ? detail : fallback;
}

export default function PromoPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [campaigns, setCampaigns] = useState<PromoCampaign[]>([]);
  const [nextAllowedAt, setNextAllowedAt] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const [productId, setProductId] = useState<number | ''>('');
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [list, prods] = await Promise.all([
        campaignsService.list(),
        productsService.getProducts(undefined, true),
      ]);
      setCampaigns(list.campaigns);
      setNextAllowedAt(list.next_allowed_at);
      setProducts(prods);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const next = parseUtc(nextAllowedAt);
  const limited = next !== null && next.getTime() > Date.now();

  const handleProduct = (value: string) => {
    const id = value === '' ? '' : Number(value);
    setProductId(id);
    const product = products.find((p) => p.id === id);
    if (!product) return;
    // Start from the item itself; the owner can still edit both fields.
    if (!title.trim()) setTitle(product.name.slice(0, TITLE_MAX));
    if (!imageUrl && product.image_url?.startsWith('https://')) setImageUrl(product.image_url);
  };

  const handlePickImage = async (file: File | undefined) => {
    if (!file) return;
    setUploading(true);
    setResult(null);
    try {
      setImageUrl(await campaignsService.uploadImage(file));
    } catch (e) {
      setResult({ ok: false, text: errorText(e, 'Сүрөттү жүктөөдө ката чыкты') });
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const handleSubmit = async () => {
    if (!title.trim() || !message.trim()) {
      setResult({ ok: false, text: 'Аталышты жана текстти толтуруңуз' });
      return;
    }
    setSending(true);
    setResult(null);
    try {
      await campaignsService.submit({
        title: title.trim(),
        message: message.trim(),
        image_url: imageUrl,
        product_id: productId === '' ? null : productId,
      });
      setResult({ ok: true, text: 'Билдирүү админге текшерүүгө жөнөтүлдү. Ырасталганда бардык колдонуучуларга барат.' });
      setTitle('');
      setMessage('');
      setImageUrl(null);
      setProductId('');
      load();
    } catch (e) {
      setResult({ ok: false, text: errorText(e, 'Жөнөтүүдө ката чыкты') });
    } finally {
      setSending(false);
    }
  };

  const handleCancel = async (id: number) => {
    if (!confirm('Билдирүүнү кайтарып аласызбы?')) return;
    try {
      await campaignsService.cancel(id);
      load();
    } catch (e) {
      setResult({ ok: false, text: errorText(e, 'Кайтарып алууда ката чыкты') });
    }
  };

  const selectedProduct = products.find((p) => p.id === productId);

  return (
    <div className="ep-promo">
      <div className="ep-promo-header">
        <div className="ep-promo-title">
          <Megaphone size={22} color="#4f46e5" />
          <h1>Жарнама билдирүүсү</h1>
        </div>
        <button className="ep-promo-refresh" onClick={load} title="Жаңылоо">
          <RefreshCw size={16} />
        </button>
      </div>

      <p className="ep-promo-hint">
        Билдирүү админ текшергенден кийин бардык колдонуучулардын телефонуна сүрөтү менен барат.
        Аны басканда кардар сиздин ишкананын барагына өтөт. Күнүнө бир билдирүү жөнөтсө болот.
      </p>

      <div className="ep-promo-layout">
        <div className="ep-promo-form">
          <label className="ep-promo-label">Менюдан товар (милдеттүү эмес)</label>
          <select
            className="ep-promo-input"
            value={productId}
            onChange={(e) => handleProduct(e.target.value)}
          >
            <option value="">— Жалпы ишкана жөнүндө —</option>
            {products.map((p) => (
              <option key={p.id} value={p.id}>
                {p.category_name ? `${p.category_name} · ` : ''}{p.name} — {p.price} сом
              </option>
            ))}
          </select>

          <label className="ep-promo-label">Сүрөт</label>
          {imageUrl ? (
            <div className="ep-promo-image">
              <img src={imageUrl} alt="" />
              <button className="ep-promo-image-remove" onClick={() => setImageUrl(null)} title="Өчүрүү">
                <X size={14} />
              </button>
            </div>
          ) : (
            <button
              className="ep-promo-upload"
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
            >
              <ImagePlus size={18} />
              {uploading ? 'Жүктөлүүдө...' : 'Сүрөт кошуу (3 МБ чейин)'}
            </button>
          )}
          <input
            ref={fileRef}
            type="file"
            accept="image/png,image/jpeg,image/webp"
            hidden
            onChange={(e) => handlePickImage(e.target.files?.[0])}
          />

          <label className="ep-promo-label">
            Аталыш <span className="ep-promo-count">{title.length}/{TITLE_MAX}</span>
          </label>
          <input
            className="ep-promo-input"
            value={title}
            maxLength={TITLE_MAX}
            placeholder="Мисалы: Палоо бүгүн 20% арзан"
            onChange={(e) => setTitle(e.target.value)}
          />

          <label className="ep-promo-label">
            Текст <span className="ep-promo-count">{message.length}/{MESSAGE_MAX}</span>
          </label>
          <textarea
            className="ep-promo-input ep-promo-textarea"
            value={message}
            maxLength={MESSAGE_MAX}
            placeholder="Кардарларга эмне айткыңыз келет?"
            onChange={(e) => setMessage(e.target.value)}
          />

          {result && (
            <div className={`ep-promo-result ${result.ok ? 'ok' : 'err'}`}>{result.text}</div>
          )}

          {limited ? (
            <div className="ep-promo-limit">
              <Clock size={16} />
              Кийинки билдирүүнү {fmtDateTime(nextAllowedAt)} кийин жөнөтө аласыз
            </div>
          ) : (
            <button
              className="ep-promo-send"
              onClick={handleSubmit}
              disabled={loading || sending || uploading}
            >
              <Send size={16} />
              {sending ? 'Жөнөтүлүүдө...' : 'Текшерүүгө жөнөтүү'}
            </button>
          )}
        </div>

        <div className="ep-promo-preview">
          <div className="ep-promo-preview-label">Телефондо мындай көрүнөт</div>
          <div className="ep-promo-phone">
            <div className="ep-promo-push">
              <div className="ep-promo-push-head">
                <img src="/logo.png" alt="" className="ep-promo-push-icon" />
                <span>Баткен Экспресс</span>
              </div>
              <div className="ep-promo-push-title">{title || 'Аталыш'}</div>
              <div className="ep-promo-push-body">{message || 'Билдирүүнүн тексти'}</div>
              {imageUrl && <img src={imageUrl} alt="" className="ep-promo-push-image" />}
            </div>
            {selectedProduct && (
              <div className="ep-promo-preview-note">Товар: {selectedProduct.name}</div>
            )}
          </div>
        </div>
      </div>

      <h2 className="ep-promo-history-title">Жөнөтүлгөн билдирүүлөр</h2>
      {loading ? (
        <div className="ep-promo-empty">Жүктөлүүдө...</div>
      ) : campaigns.length === 0 ? (
        <div className="ep-promo-empty">Азырынча билдирүү жок</div>
      ) : (
        <div className="ep-promo-list">
          {campaigns.map((c) => (
            <div key={c.id} className="ep-promo-row">
              {c.image_url && <img src={c.image_url} alt="" className="ep-promo-thumb" />}
              <div className="ep-promo-row-body">
                <div className="ep-promo-row-head">
                  <span className="ep-promo-row-title">{c.title}</span>
                  <span className={`ep-promo-status ${c.status}`}>{STATUS_LABELS[c.status] ?? c.status}</span>
                </div>
                <div className="ep-promo-row-text">{c.message}</div>
                <div className="ep-promo-row-meta">
                  {c.product_name && <span>Товар: {c.product_name}</span>}
                  <span>
                    {c.status === 'sent' && c.sent_at
                      ? `${fmtDateTime(c.sent_at)} — ${c.sent_count} колдонуучу`
                      : fmtDateTime(c.created_at)}
                  </span>
                </div>
                {c.review_note && (
                  <div className={`ep-promo-row-note ${c.status}`}>Админ: {c.review_note}</div>
                )}
              </div>
              {c.status === 'pending_review' && (
                <button className="ep-promo-cancel" onClick={() => handleCancel(c.id)} title="Кайтарып алуу">
                  <Undo2 size={16} />
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
