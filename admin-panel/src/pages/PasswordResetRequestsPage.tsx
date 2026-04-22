import { useRef, useState } from 'react';
import { KeyRound, MessageCircle, Copy, CheckCircle, Search, RefreshCw } from 'lucide-react';
import { passwordResetService, GeneratedCode } from '@/services/passwordReset';
import './PasswordResetRequestsPage.css';

function buildWhatsAppUrl(phone: string, name: string, code: string): string {
  const digits = phone.replace(/\D/g, '');
  const normalized = digits.startsWith('996') ? digits : `996${digits.replace(/^0/, '')}`;
  const msg = encodeURIComponent(
    `Саламатсызбы, ${name}!\n\nСиздин сырсөздү баштан коюу коду:\n\n*${code}*\n\nКодду колдонмого киргизиңиз. Код 24 саат ичинде жарактуу.`
  );
  return `https://wa.me/${normalized}?text=${msg}`;
}

export default function PasswordResetRequestsPage() {
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState('');
  const [generating, setGenerating] = useState(false);
  const [genError, setGenError] = useState<string | null>(null);
  const [result, setResult] = useState<GeneratedCode | null>(null);
  const [copied, setCopied] = useState(false);

  const generate = async () => {
    const val = query.trim();
    if (!val) return;
    setGenerating(true);
    setGenError(null);
    setResult(null);
    setCopied(false);
    try {
      const data = await passwordResetService.generate(val);
      setResult(data);
    } catch (e: any) {
      setGenError(e?.response?.data?.detail || e?.message || 'Ката кетти');
    } finally {
      setGenerating(false);
    }
  };

  const copyCode = () => {
    if (!result) return;
    navigator.clipboard.writeText(result.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  const reset = () => {
    setResult(null);
    setGenError(null);
    setQuery('');
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') generate();
  };

  return (
    <div className="prr-page">
      <div className="page-header">
        <div className="prr-title-row">
          <KeyRound size={22} color="#8b5cf6" />
          <h1>Сырсөз баштан коюу</h1>
        </div>
        <p className="subtitle">
          Колдонуучу WhatsApp аркылуу сыр сөзүн унутканын билдирсе — телефон же BJ ID киргизип код жасаңыз, анан WhatsApp аркылуу жөнөтүңүз
        </p>
      </div>

      {/* ── Generator form ── */}
      {!result ? (
        <div className="prr-generator">
          <div className="prr-gen-label">Колдонуучунун телефону же BJ ID</div>
          <div className="prr-gen-row">
            <div className="prr-gen-input-wrap">
              <Search size={16} className="prr-gen-icon" />
              <input
                ref={inputRef}
                className="prr-gen-input"
                placeholder="+996 700 55 22 11  же  BJ000123"
                value={query}
                onChange={e => { setQuery(e.target.value); setGenError(null); }}
                onKeyDown={handleKeyDown}
                disabled={generating}
                autoFocus
              />
            </div>
            <button
              className="prr-gen-btn"
              onClick={generate}
              disabled={generating || !query.trim()}
            >
              {generating
                ? <RefreshCw size={15} className="prr-spin" />
                : <KeyRound size={15} />}
              {generating ? 'Жасалууда...' : 'Код жасоо'}
            </button>
          </div>

          {genError && (
            <div className="prr-gen-error">{genError}</div>
          )}
        </div>
      ) : (
        /* ── Result card ── */
        <div className="prr-result-card">
          <div className="prr-result-user">
            <div className="prr-result-name">{result.user.name}</div>
            <div className="prr-result-phone">{result.user.phone}</div>
            {result.user.unique_id && (
              <div className="prr-result-id">{result.user.unique_id}</div>
            )}
          </div>

          <div className="prr-result-code-block">
            <div className="prr-result-code-label">Жаңы жашыруун код</div>
            <div className="prr-result-code">{result.code}</div>
            <div className="prr-result-hint">Код 24 саат жарактуу</div>
          </div>

          <div className="prr-result-actions">
            <a
              className="prr-btn prr-btn-whatsapp"
              href={buildWhatsAppUrl(result.user.phone, result.user.name, result.code)}
              target="_blank"
              rel="noreferrer"
            >
              <MessageCircle size={16} />
              WhatsApp аркылуу жөнөт
            </a>

            <button
              className={`prr-btn prr-btn-copy ${copied ? 'copied' : ''}`}
              onClick={copyCode}
            >
              {copied ? <CheckCircle size={15} /> : <Copy size={15} />}
              {copied ? 'Көчүрүлдү!' : 'Кодду көчүр'}
            </button>

            <button className="prr-btn prr-btn-new" onClick={reset}>
              <KeyRound size={15} />
              Башка колдонуучу
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
