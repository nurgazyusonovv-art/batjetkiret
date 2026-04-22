import { useEffect, useRef, useState } from 'react';
import { KeyRound, MessageCircle, Copy, CheckCircle, RefreshCw, Search, Plus, X } from 'lucide-react';
import { passwordResetService, GeneratedCode } from '@/services/passwordReset';
import { PasswordResetRequest } from '@/types';
import { fmtDateTime } from '@/utils/date';
import './PasswordResetRequestsPage.css';

function buildWhatsAppUrl(phone: string, name: string, code: string): string {
  const digits = phone.replace(/\D/g, '');
  const normalized = digits.startsWith('996') ? digits : `996${digits.replace(/^0/, '')}`;
  const msg = encodeURIComponent(
    `Саламатсызбы, ${name}!\n\nСиздин сырсөздү баштан коюу коду:\n\n*${code}*\n\nКодду колдонмого киргизиңиз. Код 24 саат ичинде жарактуу.`
  );
  return `https://wa.me/${normalized}?text=${msg}`;
}

function hoursLeft(expiresAt: string): string {
  const ms = new Date(expiresAt).getTime() - Date.now();
  if (ms <= 0) return 'Мөөнөтү өткөн';
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  if (h > 0) return `${h} саат ${m} мин калды`;
  return `${m} мин калды`;
}

export default function PasswordResetRequestsPage() {
  // ── Pending list ──
  const [requests, setRequests] = useState<PasswordResetRequest[]>([]);
  const [loadingList, setLoadingList] = useState(true);
  const [listError, setListError] = useState<string | null>(null);
  const [dismissingId, setDismissingId] = useState<number | null>(null);
  const [copiedId, setCopiedId] = useState<number | null>(null);

  // ── Manual generate ──
  const [showGen, setShowGen] = useState(false);
  const [query, setQuery] = useState('');
  const [generating, setGenerating] = useState(false);
  const [genError, setGenError] = useState<string | null>(null);
  const [genResult, setGenResult] = useState<GeneratedCode | null>(null);
  const [genCopied, setGenCopied] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const loadList = async (silent = false) => {
    if (!silent) setLoadingList(true);
    setListError(null);
    try {
      const data = await passwordResetService.list();
      setRequests(data);
    } catch (e: any) {
      setListError(e?.response?.data?.detail || e?.message || 'Маалымат жүктөлгөн жок');
    } finally {
      setLoadingList(false);
    }
  };

  useEffect(() => {
    loadList();
    const interval = setInterval(() => loadList(true), 30000);
    return () => clearInterval(interval);
  }, []);

  const copyCode = (id: number, code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2500);
  };

  const dismiss = async (id: number) => {
    setDismissingId(id);
    try {
      await passwordResetService.dismiss(id);
      setRequests(prev => prev.filter(r => r.id !== id));
    } catch {
      alert('Ката кетти');
    } finally {
      setDismissingId(null);
    }
  };

  // ── Manual generate handlers ──
  const openGen = () => {
    setShowGen(true);
    setGenResult(null);
    setGenError(null);
    setQuery('');
    setTimeout(() => inputRef.current?.focus(), 80);
  };

  const closeGen = () => {
    setShowGen(false);
    setGenResult(null);
    setGenError(null);
    setQuery('');
  };

  const generate = async () => {
    const val = query.trim();
    if (!val) return;
    setGenerating(true);
    setGenError(null);
    setGenResult(null);
    setGenCopied(false);
    try {
      const data = await passwordResetService.generate(val);
      setGenResult(data);
      await loadList(true);
    } catch (e: any) {
      setGenError(e?.response?.data?.detail || e?.message || 'Ката кетти');
    } finally {
      setGenerating(false);
    }
  };

  const copyGenCode = () => {
    if (!genResult) return;
    navigator.clipboard.writeText(genResult.code);
    setGenCopied(true);
    setTimeout(() => setGenCopied(false), 2500);
  };

  return (
    <div className="prr-page">
      <div className="page-header">
        <div className="prr-title-row">
          <KeyRound size={22} color="#8b5cf6" />
          <h1>Сырсөз баштан коюу</h1>
          {requests.length > 0 && (
            <span className="prr-count-badge">{requests.length}</span>
          )}
        </div>
        <p className="subtitle">
          Колдонуучу "Сырсөздү унуттум" баскычын баскандан соң код бул жерге автоматтык келет — WhatsApp аркылуу жиберсеңиз болот
        </p>
      </div>

      {/* ── Toolbar ── */}
      <div className="prr-toolbar">
        <button className="prr-refresh-btn" onClick={() => loadList()} disabled={loadingList}>
          <RefreshCw size={14} className={loadingList ? 'prr-spin' : ''} />
          Жаңылоо
        </button>
        <button className="prr-manual-btn" onClick={openGen}>
          <Plus size={14} />
          Кол менен жасоо
        </button>
      </div>

      {/* ── Manual generate panel ── */}
      {showGen && (
        <div className="prr-gen-panel">
          <div className="prr-gen-panel-header">
            <span className="prr-gen-panel-title">
              <KeyRound size={14} />
              Кол менен код жасоо
            </span>
            <button className="prr-gen-close" onClick={closeGen}><X size={16} /></button>
          </div>

          {!genResult ? (
            <>
              <div className="prr-gen-row">
                <div className="prr-gen-input-wrap">
                  <Search size={15} className="prr-gen-icon" />
                  <input
                    ref={inputRef}
                    className="prr-gen-input"
                    placeholder="Телефон же BJ ID (BJ000123)"
                    value={query}
                    onChange={e => { setQuery(e.target.value); setGenError(null); }}
                    onKeyDown={e => e.key === 'Enter' && generate()}
                    disabled={generating}
                  />
                </div>
                <button
                  className="prr-gen-btn"
                  onClick={generate}
                  disabled={generating || !query.trim()}
                >
                  {generating
                    ? <RefreshCw size={14} className="prr-spin" />
                    : <KeyRound size={14} />}
                  {generating ? '...' : 'Жасоо'}
                </button>
              </div>
              {genError && <div className="prr-gen-error">{genError}</div>}
            </>
          ) : (
            <div className="prr-gen-result">
              <div className="prr-gen-result-user">
                <span className="prr-gen-result-name">{genResult.user.name}</span>
                <span className="prr-gen-result-phone">{genResult.user.phone}</span>
              </div>
              <div className="prr-gen-result-code">{genResult.code}</div>
              <div className="prr-gen-result-actions">
                <a
                  className="prr-btn prr-btn-whatsapp"
                  href={buildWhatsAppUrl(genResult.user.phone, genResult.user.name, genResult.code)}
                  target="_blank"
                  rel="noreferrer"
                  onClick={closeGen}
                >
                  <MessageCircle size={14} />
                  WhatsApp жөнөт
                </a>
                <button
                  className={`prr-btn prr-btn-copy ${genCopied ? 'copied' : ''}`}
                  onClick={copyGenCode}
                >
                  {genCopied ? <CheckCircle size={14} /> : <Copy size={14} />}
                  {genCopied ? 'Көчүрүлдү' : 'Кодду көчүр'}
                </button>
                <button className="prr-btn prr-btn-ghost" onClick={() => { setGenResult(null); setQuery(''); }}>
                  Башка колдонуучу
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── Pending list ── */}
      {loadingList ? (
        <div className="loading-container">
          <div className="spinner" />
          <p>Жүктөлүүдө...</p>
        </div>
      ) : listError ? (
        <div className="prr-empty prr-error">
          <p>Ката: {listError}</p>
          <button className="prr-refresh-btn" onClick={() => loadList()}>Кайра аракет</button>
        </div>
      ) : requests.length === 0 ? (
        <div className="prr-empty">
          <CheckCircle size={48} color="#10b981" opacity={0.4} />
          <p>Күтүүдөгү суроолор жок</p>
          <span className="prr-empty-hint">Колдонуучу "Сырсөздү унуттум" баскычын баскандан соң бул жерде пайда болот</span>
        </div>
      ) : (
        <div className="prr-list">
          {requests.map(req => {
            const isBusy = dismissingId === req.id;
            const isCopied = copiedId === req.id;
            const timeStr = hoursLeft(req.expires_at);
            const isUrgent = new Date(req.expires_at).getTime() - Date.now() < 3600000;

            return (
              <div key={req.id} className="prr-card">
                <div className="prr-card-top">
                  <div className="prr-card-user">
                    <div className="prr-card-name">{req.user?.name ?? '—'}</div>
                    <div className="prr-card-phone">{req.user?.phone}</div>
                    {req.user?.unique_id && (
                      <div className="prr-card-uid">{req.user.unique_id}</div>
                    )}
                  </div>
                  <div className="prr-card-meta">
                    <span className={`prr-time ${isUrgent ? 'urgent' : ''}`}>{timeStr}</span>
                    <span className="prr-date">{fmtDateTime(req.last_sent_at)}</span>
                  </div>
                </div>

                <div className="prr-card-code-row">
                  <div className="prr-card-code">{req.code}</div>
                  <button
                    className={`prr-copy-btn ${isCopied ? 'copied' : ''}`}
                    onClick={() => copyCode(req.id, req.code)}
                  >
                    {isCopied ? <CheckCircle size={13} /> : <Copy size={13} />}
                    {isCopied ? 'Көчүрүлдү' : 'Көчүр'}
                  </button>
                </div>

                <div className="prr-card-actions">
                  <a
                    className="prr-btn prr-btn-whatsapp"
                    href={buildWhatsAppUrl(req.user?.phone ?? '', req.user?.name ?? 'колдонуучу', req.code)}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <MessageCircle size={15} />
                    WhatsApp аркылуу жөнөт
                  </a>
                  <button
                    className="prr-btn prr-btn-ghost"
                    onClick={() => dismiss(req.id)}
                    disabled={isBusy}
                  >
                    <CheckCircle size={15} />
                    {isBusy ? '...' : 'Жиберилди'}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
