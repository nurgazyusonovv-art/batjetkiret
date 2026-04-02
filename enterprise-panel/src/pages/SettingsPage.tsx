import { useEffect, useRef, useState } from 'react';
import { Settings, QrCode, Trash2, Upload, MapPin, Check } from 'lucide-react';
import { ordersService } from '../services/orders';
import './SettingsPage.css';

// ── Yandex Maps ───────────────────────────────────────────────────────────────
const YANDEX_API_KEY = '815b5065-2f27-4e69-aab3-45df9fed1bda';

declare global {
  interface Window { ymaps: any; }
}

function loadYmaps(): Promise<void> {
  return new Promise((resolve) => {
    if (window.ymaps) { resolve(); return; }
    const script = document.createElement('script');
    script.src = `https://api-maps.yandex.ru/2.1/?apikey=${YANDEX_API_KEY}&lang=ru_RU`;
    script.onload = () => window.ymaps.ready(resolve);
    document.head.appendChild(script);
  });
}

// ── Map Picker Modal ──────────────────────────────────────────────────────────
interface MapPickerProps {
  initialLat: number | null;
  initialLon: number | null;
  onConfirm: (lat: number, lon: number) => void;
  onClose: () => void;
}

function MapPicker({ initialLat, initialLon, onConfirm, onClose }: MapPickerProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const ymapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);

  const [picked, setPicked] = useState<{ lat: number; lon: number } | null>(
    initialLat != null && initialLon != null ? { lat: initialLat, lon: initialLon } : null
  );

  useEffect(() => {
    let cancelled = false;
    loadYmaps().then(() => {
      if (cancelled || !mapRef.current) return;
      // Default center: Batken
      const center = picked ? [picked.lat, picked.lon] : [37.85, 70.03];
      const ymap = new window.ymaps.Map(mapRef.current, {
        center,
        zoom: 14,
        controls: ['zoomControl', 'fullscreenControl'],
      });
      ymapRef.current = ymap;

      if (picked) {
        const pm = new window.ymaps.Placemark([picked.lat, picked.lon], {}, { preset: 'islands#redDotIcon' });
        markerRef.current = pm;
        ymap.geoObjects.add(pm);
      }

      ymap.events.add('click', (e: any) => {
        const coords = e.get('coords');
        const lat = parseFloat(coords[0].toFixed(6));
        const lon = parseFloat(coords[1].toFixed(6));
        setPicked({ lat, lon });
        if (markerRef.current) ymap.geoObjects.remove(markerRef.current);
        const pm = new window.ymaps.Placemark([lat, lon], {}, { preset: 'islands#redDotIcon' });
        markerRef.current = pm;
        ymap.geoObjects.add(pm);
      });
    });
    return () => { cancelled = true; ymapRef.current?.destroy(); };
  }, []);

  return (
    <div className="ep-map-overlay" onClick={onClose}>
      <div className="ep-map-modal" onClick={e => e.stopPropagation()}>
        <div className="ep-map-header">
          <span>Жайгашкан жерди тандаңыз</span>
          <button className="ep-map-close" onClick={onClose}>✕</button>
        </div>
        <p className="ep-map-hint">Картага басып жайгашкан жерди белгилеңиз</p>
        <div ref={mapRef} className="ep-map-container" />
        <div className="ep-map-footer">
          <span className="ep-map-coords">
            {picked ? `${picked.lat.toFixed(5)}, ${picked.lon.toFixed(5)}` : 'Картага басыңыз'}
          </span>
          <div className="ep-map-footer-btns">
            <button className="ep-map-btn-cancel" onClick={onClose}>Жокко чыгаруу</button>
            <button
              className="ep-map-btn-confirm"
              disabled={!picked}
              onClick={() => picked && onConfirm(picked.lat, picked.lon)}
            >
              <Check size={15} /> Тастыктоо
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Main Settings Page ────────────────────────────────────────────────────────
export default function SettingsPage() {
  const [qrUrl, setQrUrl] = useState<string | null>(null);
  const [currentLat, setCurrentLat] = useState<number | null>(null);
  const [currentLon, setCurrentLon] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [showMap, setShowMap] = useState(false);
  const [locationSaving, setLocationSaving] = useState(false);
  const [locationMsg, setLocationMsg] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    ordersService.getMe()
      .then((data) => {
        setQrUrl(data.payment_qr_url);
        setCurrentLat(data.lat);
        setCurrentLon(data.lon);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    setSuccess(null);
    setUploading(true);
    try {
      const res = await ordersService.uploadPaymentQr(file);
      setQrUrl(res.payment_qr_url);
      setSuccess('QR код ийгиликтүү жүктөлдү!');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setError(err?.response?.data?.detail ?? 'Жүктөөдө ката кетти');
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleDelete = async () => {
    if (!window.confirm('QR кодду өчүрөсүзбү?')) return;
    setDeleting(true);
    setError(null);
    setSuccess(null);
    try {
      await ordersService.deletePaymentQr();
      setQrUrl(null);
      setSuccess('QR код өчүрүлдү');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setError(err?.response?.data?.detail ?? 'Өчүрүүдө ката кетти');
    } finally {
      setDeleting(false);
    }
  };

  const handleMapConfirm = async (lat: number, lon: number) => {
    setShowMap(false);
    setLocationSaving(true);
    setLocationMsg(null);
    try {
      const res = await ordersService.updateLocation(lat, lon);
      setCurrentLat(res.lat);
      setCurrentLon(res.lon);
      setLocationMsg('✓ Жайгашкан жер сакталды');
    } catch {
      setLocationMsg('Сактоодо ката кетти');
    } finally {
      setLocationSaving(false);
    }
  };

  return (
    <div className="ep-settings">
      <div className="ep-settings-header">
        <Settings size={22} />
        <h1>Жөндөөлөр</h1>
      </div>

      {/* ── Location section ── */}
      <div className="ep-settings-card">
        <div className="ep-settings-section-title">
          <MapPin size={18} />
          <span>Картадагы жайгашкан жер</span>
        </div>
        <p className="ep-settings-desc">
          Кардарлар ишкананызды картада таба алышы үчүн так жайгашкан жериңизди белгилеңиз.
        </p>

        {loading ? (
          <div className="ep-settings-loading">Жүктөлүүдө...</div>
        ) : (
          <div className="ep-location-area">
            <div className="ep-location-current">
              {currentLat != null && currentLon != null ? (
                <span className="ep-location-coords">
                  📍 {currentLat.toFixed(5)}, {currentLon.toFixed(5)}
                </span>
              ) : (
                <span className="ep-location-empty">Жайгашкан жер белгиленген жок</span>
              )}
            </div>
            <button
              className="ep-location-btn"
              onClick={() => setShowMap(true)}
              disabled={locationSaving}
            >
              <MapPin size={15} />
              {locationSaving ? 'Сакталууда...' : currentLat != null ? 'Жерди өзгөртүү' : 'Жерди белгилөө'}
            </button>
          </div>
        )}

        {locationMsg && (
          <p className={locationMsg.startsWith('✓') ? 'ep-settings-success' : 'ep-settings-error'}>
            {locationMsg}
          </p>
        )}
      </div>

      {/* ── QR section ── */}
      <div className="ep-settings-card">
        <div className="ep-settings-section-title">
          <QrCode size={18} />
          <span>Төлөм QR коду</span>
        </div>
        <p className="ep-settings-desc">
          Кардарлар заказ кылганда QR кодуңузду сканерлеп төлөм жүргүзөт.
        </p>

        {loading ? (
          <div className="ep-settings-loading">Жүктөлүүдө...</div>
        ) : (
          <div className="ep-qr-area">
            {qrUrl ? (
              <div className="ep-qr-preview">
                <img src={qrUrl} alt="Payment QR" className="ep-qr-img" />
                <div className="ep-qr-actions">
                  <button
                    className="ep-qr-btn ep-qr-btn-replace"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploading}
                  >
                    <Upload size={15} />
                    {uploading ? 'Жүктөлүүдө...' : 'Алмаштыруу'}
                  </button>
                  <button
                    className="ep-qr-btn ep-qr-btn-delete"
                    onClick={handleDelete}
                    disabled={deleting}
                  >
                    <Trash2 size={15} />
                    {deleting ? '...' : 'Өчүрүү'}
                  </button>
                </div>
              </div>
            ) : (
              <div className="ep-qr-empty">
                <QrCode size={52} opacity={0.2} />
                <p>QR код жок</p>
                <button
                  className="ep-qr-btn ep-qr-btn-upload"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={uploading}
                >
                  <Upload size={15} />
                  {uploading ? 'Жүктөлүүдө...' : 'QR код жүктөө'}
                </button>
              </div>
            )}

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={handleFileChange}
            />
          </div>
        )}

        {error && <p className="ep-settings-error">{error}</p>}
        {success && <p className="ep-settings-success">{success}</p>}
      </div>

      {/* ── Map Picker Modal ── */}
      {showMap && (
        <MapPicker
          initialLat={currentLat}
          initialLon={currentLon}
          onConfirm={handleMapConfirm}
          onClose={() => setShowMap(false)}
        />
      )}
    </div>
  );
}
