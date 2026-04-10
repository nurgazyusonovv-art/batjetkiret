import { useEffect, useRef, useState } from 'react';
import { Settings, QrCode, Trash2, Upload, MapPin, Check, Clock, Image, Timer, Lock, Eye, EyeOff } from 'lucide-react';
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
  const [enterpriseId, setEnterpriseId] = useState<number | null>(null);
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

  // Logo state
  const [logoData, setLogoData] = useState<string | null>(null);
  const [logoUploading, setLogoUploading] = useState(false);
  const [logoMsg, setLogoMsg] = useState<string | null>(null);
  const logoInputRef = useRef<HTMLInputElement>(null);

  // Working hours state
  const [openTime, setOpenTime] = useState('');
  const [closeTime, setCloseTime] = useState('');
  const [hoursSaving, setHoursSaving] = useState(false);
  const [hoursMsg, setHoursMsg] = useState<string | null>(null);

  // Prep time state
  const [prepTime, setPrepTime] = useState<string>('');
  const [prepSaving, setPrepSaving] = useState(false);
  const [prepMsg, setPrepMsg] = useState<string | null>(null);

  // Change password state
  const [currentPwd, setCurrentPwd] = useState('');
  const [newPwd, setNewPwd] = useState('');
  const [confirmPwd, setConfirmPwd] = useState('');
  const [showCurrentPwd, setShowCurrentPwd] = useState(false);
  const [showNewPwd, setShowNewPwd] = useState(false);
  const [pwdSaving, setPwdSaving] = useState(false);
  const [pwdMsg, setPwdMsg] = useState<string | null>(null);

  useEffect(() => {
    ordersService.getMe()
      .then((data) => {
        setEnterpriseId(data.id);
        setQrUrl(data.payment_qr_url);
        setCurrentLat(data.lat);
        setCurrentLon(data.lon);
        setLogoData(data.logo_data);
        setOpenTime(data.open_time ?? '');
        setCloseTime(data.close_time ?? '');
        setPrepTime(data.prep_time_minutes != null ? String(data.prep_time_minutes) : '');
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

  const handleLogoChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !enterpriseId) return;
    setLogoMsg(null);
    setLogoUploading(true);
    try {
      const res = await ordersService.uploadLogo(enterpriseId, file);
      setLogoData(res.logo_data);
      setLogoMsg('✓ Логотип ийгиликтүү жүктөлдү!');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setLogoMsg(err?.response?.data?.detail ?? 'Жүктөөдө ката кетти');
    } finally {
      setLogoUploading(false);
      if (logoInputRef.current) logoInputRef.current.value = '';
    }
  };

  const handleHoursSave = async () => {
    if (!enterpriseId || !openTime || !closeTime) return;
    setHoursSaving(true);
    setHoursMsg(null);
    try {
      await ordersService.updateWorkingHours(enterpriseId, openTime, closeTime);
      setHoursMsg('✓ Иштөө убактысы сакталды!');
    } catch {
      setHoursMsg('Сактоодо ката кетти');
    } finally {
      setHoursSaving(false);
    }
  };

  const handlePrepSave = async () => {
    if (!enterpriseId) return;
    const minutes = prepTime === '' ? null : parseInt(prepTime, 10);
    if (minutes !== null && (isNaN(minutes) || minutes < 0)) {
      setPrepMsg('Туура убакыт киргизиңиз');
      return;
    }
    setPrepSaving(true);
    setPrepMsg(null);
    try {
      await ordersService.updatePrepTime(enterpriseId, minutes);
      setPrepMsg('✓ Даярдоо убактысы сакталды!');
    } catch {
      setPrepMsg('Сактоодо ката кетти');
    } finally {
      setPrepSaving(false);
    }
  };

  const handleChangePassword = async () => {
    if (!currentPwd) { setPwdMsg('Учурдагы сырсөздү киргизиңиз'); return; }
    if (newPwd.length < 6) { setPwdMsg('Жаңы сырсөз кеминде 6 символ болуш керек'); return; }
    if (newPwd !== confirmPwd) { setPwdMsg('Жаңы сырсөздөр дал келбейт'); return; }
    setPwdSaving(true);
    setPwdMsg(null);
    try {
      await ordersService.changePassword(currentPwd, newPwd);
      setPwdMsg('✓ Сырсөз ийгиликтүү өзгөртүлдү!');
      setCurrentPwd(''); setNewPwd(''); setConfirmPwd('');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setPwdMsg(err?.response?.data?.detail ?? 'Сактоодо ката кетти');
    } finally {
      setPwdSaving(false);
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

      {/* ── Logo section ── */}
      <div className="ep-settings-card">
        <div className="ep-settings-section-title">
          <Image size={18} />
          <span>Ишкананын логотиби</span>
        </div>
        <p className="ep-settings-desc">
          Логотип кардарларга ишкананы тез таануу үчүн колдонулат.
        </p>

        {loading ? (
          <div className="ep-settings-loading">Жүктөлүүдө...</div>
        ) : (
          <div className="ep-logo-area">
            {logoData ? (
              <div className="ep-logo-preview">
                <img src={logoData} alt="Logo" className="ep-logo-img" />
                <button
                  className="ep-qr-btn ep-qr-btn-replace"
                  onClick={() => logoInputRef.current?.click()}
                  disabled={logoUploading}
                >
                  <Upload size={15} />
                  {logoUploading ? 'Жүктөлүүдө...' : 'Логотибди өзгөртүү'}
                </button>
              </div>
            ) : (
              <div className="ep-qr-empty">
                <Image size={48} opacity={0.2} />
                <p>Логотип жок</p>
                <button
                  className="ep-qr-btn ep-qr-btn-upload"
                  onClick={() => logoInputRef.current?.click()}
                  disabled={logoUploading}
                >
                  <Upload size={15} />
                  {logoUploading ? 'Жүктөлүүдө...' : 'Логотип жүктөө'}
                </button>
              </div>
            )}
            <input
              ref={logoInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={handleLogoChange}
            />
          </div>
        )}
        {logoMsg && (
          <p className={logoMsg.startsWith('✓') ? 'ep-settings-success' : 'ep-settings-error'}>
            {logoMsg}
          </p>
        )}
      </div>

      {/* ── Working Hours section ── */}
      <div className="ep-settings-card">
        <div className="ep-settings-section-title">
          <Clock size={18} />
          <span>Иштөө убактысы</span>
        </div>
        <p className="ep-settings-desc">
          Иштөө убактысынан тышкары кардарларга ишкана жабык экени көрсөтүлөт.
        </p>

        {loading ? (
          <div className="ep-settings-loading">Жүктөлүүдө...</div>
        ) : (
          <div className="ep-hours-area">
            <div className="ep-hours-inputs">
              <label className="ep-hours-label">
                Ачылуу
                <input
                  type="time"
                  className="ep-hours-input"
                  value={openTime}
                  onChange={e => setOpenTime(e.target.value)}
                />
              </label>
              <span className="ep-hours-sep">—</span>
              <label className="ep-hours-label">
                Жабылуу
                <input
                  type="time"
                  className="ep-hours-input"
                  value={closeTime}
                  onChange={e => setCloseTime(e.target.value)}
                />
              </label>
            </div>
            <button
              className="ep-hours-save-btn"
              onClick={handleHoursSave}
              disabled={hoursSaving || !openTime || !closeTime}
            >
              <Check size={15} />
              {hoursSaving ? 'Сакталууда...' : 'Сактоо'}
            </button>
          </div>
        )}
        {hoursMsg && (
          <p className={hoursMsg.startsWith('✓') ? 'ep-settings-success' : 'ep-settings-error'}>
            {hoursMsg}
          </p>
        )}
      </div>

      {/* ── Prep time section ── */}
      <div className="ep-settings-card">
        <div className="ep-settings-section-title">
          <Timer size={18} />
          <span>Болжолдуу даярдоо убактысы</span>
        </div>
        <p className="ep-settings-desc">
          Кардарга заказды даярдоого кетүүчү болжолдуу убакытты көрсөтүңүз.
        </p>

        {loading ? (
          <div className="ep-settings-loading">Жүктөлүүдө...</div>
        ) : (
          <div className="ep-prep-area">
            <div className="ep-prep-input-wrap">
              <input
                type="number"
                min="0"
                max="300"
                className="ep-prep-input"
                placeholder="мис. 30"
                value={prepTime}
                onChange={e => setPrepTime(e.target.value)}
              />
              <span className="ep-prep-unit">мүнөт</span>
            </div>
            <button
              className="ep-hours-save-btn"
              onClick={handlePrepSave}
              disabled={prepSaving}
            >
              <Check size={15} />
              {prepSaving ? 'Сакталууда...' : 'Сактоо'}
            </button>
          </div>
        )}
        {prepMsg && (
          <p className={prepMsg.startsWith('✓') ? 'ep-settings-success' : 'ep-settings-error'}>
            {prepMsg}
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

      {/* ── Change Password section ── */}
      <div className="ep-settings-card">
        <div className="ep-settings-section-title">
          <Lock size={18} />
          <span>Сырсөздү өзгөртүү</span>
        </div>
        <p className="ep-settings-desc">
          Кирүү сырсөзүңүздү өзгөртүңүз. Учурдагы сырсөздү туура киргизишиңиз керек.
        </p>

        <div className="ep-pwd-form">
          <div className="ep-pwd-field">
            <label>Учурдагы сырсөз</label>
            <div className="ep-pwd-input-wrap">
              <input
                type={showCurrentPwd ? 'text' : 'password'}
                value={currentPwd}
                onChange={e => setCurrentPwd(e.target.value)}
                placeholder="Учурдагы сырсөз"
              />
              <button type="button" className="ep-pwd-eye" onClick={() => setShowCurrentPwd(v => !v)}>
                {showCurrentPwd ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          <div className="ep-pwd-field">
            <label>Жаңы сырсөз</label>
            <div className="ep-pwd-input-wrap">
              <input
                type={showNewPwd ? 'text' : 'password'}
                value={newPwd}
                onChange={e => setNewPwd(e.target.value)}
                placeholder="Кеминде 6 символ"
              />
              <button type="button" className="ep-pwd-eye" onClick={() => setShowNewPwd(v => !v)}>
                {showNewPwd ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          <div className="ep-pwd-field">
            <label>Жаңы сырсөздү ырастаңыз</label>
            <input
              type="password"
              value={confirmPwd}
              onChange={e => setConfirmPwd(e.target.value)}
              placeholder="Сырсөздү кайталаңыз"
            />
          </div>

          <button
            className="ep-hours-save-btn"
            onClick={handleChangePassword}
            disabled={pwdSaving}
          >
            <Check size={15} />
            {pwdSaving ? 'Сакталууда...' : 'Сырсөздү өзгөртүү'}
          </button>
        </div>

        {pwdMsg && (
          <p className={pwdMsg.startsWith('✓') ? 'ep-settings-success' : 'ep-settings-error'}>
            {pwdMsg}
          </p>
        )}
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
