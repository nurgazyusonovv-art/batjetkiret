/** All API timestamps are UTC but come without 'Z' suffix.
 *  These helpers append 'Z', parse as UTC, then display in Asia/Bishkek (UTC+6).
 */
const TZ = 'Asia/Bishkek';

export function parseUtc(raw: string | null | undefined): Date | null {
  if (!raw) return null;
  const utc = raw.endsWith('Z') ? raw : raw + 'Z';
  const d = new Date(utc);
  return isNaN(d.getTime()) ? null : d;
}

export function fmtDate(raw: string | null | undefined): string {
  const d = parseUtc(raw);
  if (!d) return '—';
  return d.toLocaleDateString('ru-RU', {
    timeZone: TZ,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

export function fmtTime(raw: string | null | undefined): string {
  const d = parseUtc(raw);
  if (!d) return '';
  return d.toLocaleTimeString('ru-RU', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function fmtDateTime(raw: string | null | undefined): string {
  const d = parseUtc(raw);
  if (!d) return '—';
  return d.toLocaleString('ru-RU', {
    timeZone: TZ,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
