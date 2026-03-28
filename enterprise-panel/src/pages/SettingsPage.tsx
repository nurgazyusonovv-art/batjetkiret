import { useEffect, useRef, useState } from 'react';
import { Settings, QrCode, Trash2, Upload } from 'lucide-react';
import { ordersService } from '../services/orders';
import './SettingsPage.css';

export default function SettingsPage() {
  const [qrUrl, setQrUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    ordersService.getMe()
      .then((data) => setQrUrl(data.payment_qr_url))
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

  return (
    <div className="ep-settings">
      <div className="ep-settings-header">
        <Settings size={22} />
        <h1>Жөндөөлөр</h1>
      </div>

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
    </div>
  );
}
