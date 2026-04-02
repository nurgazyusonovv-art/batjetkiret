import { useCallback, useEffect, useMemo, useState } from 'react';
import { Search, Filter, Eye, Trash2, CalendarDays, X, MapPin, User, Truck, Package } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';
import { orderService } from '@/services/orders';
import { Order, OrderStatus } from '@/types';
import { fmtDate, fmtDateTime } from '@/utils/date';
import './OrdersPage.css';

const ITEMS_PER_PAGE = 12;

const STATUS_LABELS: Record<OrderStatus, string> = {
  WAITING_COURIER: 'Жаңы',
  ACCEPTED: 'Кабыл алынды — ишкана',
  PREPARING: 'Даярдалып жатат',
  READY: 'Даяр — Курьер күтүүдө',
  PICKED_UP: 'Кабыл алынды — Курьер',
  ON_THE_WAY: 'Жеткирүүнү баштады',
  IN_TRANSIT: 'Жеткирүүнү баштады',
  DELIVERED: 'Жеткирилди',
  COMPLETED: 'Аяктады',
  CANCELLED: 'Жокко чыгарылды',
};

const STATUS_COLORS: Record<OrderStatus, string> = {
  WAITING_COURIER: '#f59e0b',
  ACCEPTED: '#3b82f6',
  PREPARING: '#9333ea',
  READY: '#16a34a',
  PICKED_UP: '#0891b2',
  ON_THE_WAY: '#8b5cf6',
  IN_TRANSIT: '#8b5cf6',
  DELIVERED: '#10b981',
  COMPLETED: '#059669',
  CANCELLED: '#ef4444',
};

const STATUS_BG: Record<OrderStatus, string> = {
  WAITING_COURIER: '#fffbeb',
  ACCEPTED: '#eff6ff',
  PREPARING: '#faf5ff',
  READY: '#f0fdf4',
  PICKED_UP: '#ecfeff',
  ON_THE_WAY: '#f5f3ff',
  IN_TRANSIT: '#f5f3ff',
  DELIVERED: '#ecfdf5',
  COMPLETED: '#dcfce7',
  CANCELLED: '#fef2f2',
};

export default function OrdersPage() {
  const [searchParams] = useSearchParams();
  const [orders, setOrders] = useState<Order[]>([]);
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [deletingOrderIds, setDeletingOrderIds] = useState<Set<number>>(new Set());
  const [statusDraft, setStatusDraft] = useState<OrderStatus>('WAITING_COURIER');
  const [statusNote, setStatusNote] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<OrderStatus | ''>('');
  const [todayOnly, setTodayOnly] = useState(false);
  const [selectedDate, setSelectedDate] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [notifyTitle, setNotifyTitle] = useState('');
  const [notifyMessage, setNotifyMessage] = useState('');
  const [notifySending, setNotifySending] = useState(false);

  const formatDateLabel = (value: string) => {
    if (!value) return 'Күндү тандаңыз';
    return fmtDate(value);
  };

  const clearDateFilters = () => {
    setSelectedDate(''); setDateFrom(''); setDateTo(''); setTodayOnly(false);
    loadOrders(false, '', '', '');
  };

  const clearSelectedDate = () => { setSelectedDate(''); setTodayOnly(false); loadOrders(false, '', '', ''); };
  const clearDateFrom = () => { setDateFrom(''); setTodayOnly(false); setSelectedDate(''); loadOrders(false, '', '', dateTo); };
  const clearDateTo  = () => { setDateTo('');   setTodayOnly(false); setSelectedDate(''); loadOrders(false, '', dateFrom, ''); };

  const loadOrders = useCallback(async (
    onlyToday: boolean, date = '', from = '', to = '',
  ) => {
    try {
      setLoading(true); setLoadError('');
      const data = await orderService.getOrders({
        limit: 200,
        today_only: date || from || to ? false : onlyToday,
        order_date: date || undefined,
        date_from: from || undefined,
        date_to: to || undefined,
      });
      setOrders(data);
    } catch {
      setLoadError('Заказдарды жүктөө мүмкүн болгон жок.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      loadOrders(todayOnly, selectedDate, dateFrom, dateTo);
    }, 30000);
    return () => clearInterval(interval);
  }, [loadOrders, todayOnly, selectedDate, dateFrom, dateTo]);

  useEffect(() => {
    const s = searchParams.get('status');
    const todayQ = searchParams.get('today');
    const dateQ = searchParams.get('date');
    const fromQ = searchParams.get('from');
    const toQ = searchParams.get('to');

    if (s && Object.prototype.hasOwnProperty.call(STATUS_LABELS, s))
      setStatusFilter(s as OrderStatus);

    if (todayQ === 'true') { setTodayOnly(true); loadOrders(true); return; }
    if (dateQ)            { setSelectedDate(dateQ); loadOrders(false, dateQ); return; }
    if (fromQ || toQ)     { setDateFrom(fromQ || ''); setDateTo(toQ || ''); loadOrders(false, '', fromQ || '', toQ || ''); return; }

    loadOrders(false);
  }, [searchParams, loadOrders]);

  const openOrderDetails = async (orderId: number) => {
    setDetailLoading(true);
    try {
      const order = await orderService.getOrderById(orderId);
      setSelectedOrder(order);
      setStatusDraft(order.status);
      setStatusNote(order.admin_note ?? '');
      setNotifyTitle(`Заказ №${order.id} жөнүндө`);
      setNotifyMessage('');
    } catch {
      alert('Заказ деталын жүктөө мүмкүн болгон жок');
    } finally {
      setDetailLoading(false);
    }
  };

  const applyStatusChange = async () => {
    if (!selectedOrder) return;
    setActionLoading(true);
    try {
      const updated = await orderService.forceStatus(selectedOrder.id, statusDraft, statusNote);
      setSelectedOrder(updated);
      await loadOrders(todayOnly, selectedDate, dateFrom, dateTo);
    } catch {
      alert('Статусту өзгөртүү мүмкүн болгон жок');
    } finally {
      setActionLoading(false);
    }
  };

  const sendNotifyToUser = async () => {
    if (!selectedOrder) return;
    if (!notifyMessage.trim()) { alert('Билдирүү текстин жазыңыз'); return; }
    setNotifySending(true);
    try {
      const { default: api } = await import('@/services/api');
      await api.post(`/admin/users/${selectedOrder.user_id}/notify`, {
        title: notifyTitle || `Заказ №${selectedOrder.id} жөнүндө`,
        message: notifyMessage,
      });
      setNotifyTitle('');
      setNotifyMessage('');
      alert('Билдирүү жөнөтүлдү');
    } catch {
      alert('Билдирүүнү жөнөтүүдө ката чыкты');
    } finally {
      setNotifySending(false);
    }
  };

  const deleteSelectedOrder = async () => {
    if (!selectedOrder) return;
    if (!confirm(`Заказ #${selectedOrder.id} өчүрүлсүнбү?`)) return;
    setActionLoading(true);
    try {
      await orderService.deleteOrder(selectedOrder.id);
      setSelectedOrder(null);
      await loadOrders(todayOnly, selectedDate, dateFrom, dateTo);
    } catch {
      alert('Заказды өчүрүү мүмкүн болгон жок');
    } finally {
      setActionLoading(false);
    }
  };

  const quickDeleteOrder = async (orderId: number) => {
    if (deletingOrderIds.has(orderId)) return;
    if (!confirm(`Заказ #${orderId} базадан толук өчүрүлсүнбү?`)) return;
    setDeletingOrderIds(prev => new Set(prev).add(orderId));
    try {
      await orderService.deleteOrder(orderId);
      if (selectedOrder?.id === orderId) setSelectedOrder(null);
      await loadOrders(todayOnly, selectedDate, dateFrom, dateTo);
    } catch {
      alert('Заказды өчүрүү мүмкүн болгон жок');
    } finally {
      setDeletingOrderIds(prev => { const n = new Set(prev); n.delete(orderId); return n; });
    }
  };

  const filteredOrders = useMemo(() => {
    let f = orders;
    if (searchQuery) f = f.filter(o =>
      o.id.toString().includes(searchQuery) ||
      o.user_phone?.includes(searchQuery) ||
      o.courier_phone?.includes(searchQuery)
    );
    if (statusFilter) f = f.filter(o => o.status === statusFilter);
    return f;
  }, [orders, searchQuery, statusFilter]);

  const hasDateFilter = Boolean(selectedDate || dateFrom || dateTo);

  const selectedDateText = useMemo(() => {
    if (selectedDate) return `Тандалган күн: ${formatDateLabel(selectedDate)}`;
    if (dateFrom || dateTo) {
      const fL = dateFrom ? formatDateLabel(dateFrom) : '...';
      const tL = dateTo ? formatDateLabel(dateTo) : '...';
      return `Диапазон: ${fL} — ${tL}`;
    }
    return '';
  }, [selectedDate, dateFrom, dateTo]);

  const totalPages = Math.max(1, Math.ceil(filteredOrders.length / ITEMS_PER_PAGE));
  const paginatedOrders = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredOrders.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredOrders, currentPage]);

  useEffect(() => { setCurrentPage(1); }, [searchQuery, statusFilter, orders]);
  useEffect(() => { if (currentPage > totalPages) setCurrentPage(totalPages); }, [currentPage, totalPages]);

  if (loading) return (
    <div className="loading-container"><div className="spinner" /><p>Жүктөлүүдө...</p></div>
  );

  return (
    <div className="orders-page">
      {loadError && <div className="error-banner">{loadError}</div>}

      <div className="page-header">
        <h1>Заказдар</h1>
        <p className="subtitle">Бардык заказдарды башкаруу — {filteredOrders.length} заказ</p>
      </div>

      {/* ── Filters ── */}
      <div className="filters-bar">
        <div className="search-box">
          <Search size={20} />
          <input
            type="text"
            placeholder="ID, телефон номер боюнча издөө..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
          />
        </div>

        <div className="filter-group">
          <Filter size={20} />
          <select value={statusFilter} onChange={e => setStatusFilter(e.target.value as OrderStatus | '')}>
            <option value="">Бардык статустар</option>
            {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
        </div>

        <div className="date-filter-toggle">
          <button className={`toggle-btn ${!todayOnly ? 'active' : ''}`}
            onClick={() => { setTodayOnly(false); clearDateFilters(); }}>Баары</button>
          <button className={`toggle-btn ${todayOnly ? 'active' : ''}`}
            onClick={() => { setTodayOnly(true); setSelectedDate(''); setDateFrom(''); setDateTo(''); loadOrders(true); }}>
            Бүгүнкү
          </button>
        </div>

        <div className="filter-group date-picker-group">
          <CalendarDays size={20} />
          <div className="date-field-inline">
            <span className="date-picker-trigger">{formatDateLabel(selectedDate)}</span>
            {selectedDate && <button type="button" className="date-clear-inline" onClick={clearSelectedDate}><X size={12} /></button>}
            <input className="native-date-input overlay-input" type="date" value={selectedDate}
              onChange={e => { setSelectedDate(e.target.value); setTodayOnly(false); setDateFrom(''); setDateTo(''); loadOrders(false, e.target.value); }} />
          </div>
        </div>

        <div className="filter-group date-range-group">
          <CalendarDays size={20} />
          <div className="range-inputs">
            <div className="date-field-inline">
              <span className="date-picker-trigger range">{dateFrom ? formatDateLabel(dateFrom) : 'Башталышы'}</span>
              {dateFrom && <button type="button" className="date-clear-inline" onClick={clearDateFrom}><X size={12} /></button>}
              <input className="native-date-input overlay-input" type="date" value={dateFrom}
                onChange={e => { setDateFrom(e.target.value); setSelectedDate(''); setTodayOnly(false); loadOrders(false, '', e.target.value, dateTo); }} />
            </div>
            <span>—</span>
            <div className="date-field-inline">
              <span className="date-picker-trigger range">{dateTo ? formatDateLabel(dateTo) : 'Аягы'}</span>
              {dateTo && <button type="button" className="date-clear-inline" onClick={clearDateTo}><X size={12} /></button>}
              <input className="native-date-input overlay-input" type="date" value={dateTo}
                onChange={e => { setDateTo(e.target.value); setSelectedDate(''); setTodayOnly(false); loadOrders(false, '', dateFrom, e.target.value); }} />
            </div>
          </div>
        </div>
      </div>

      {hasDateFilter && (
        <div className="selected-date-strip">
          <span>{selectedDateText}</span>
          <button type="button" className="clear-date-btn" onClick={clearDateFilters}>Тазалоо</button>
        </div>
      )}

      {/* ── Cards grid ── */}
      {filteredOrders.length === 0 ? (
        <div className="op-empty">
          <Package size={48} opacity={0.2} />
          <p>Заказдар табылган жок</p>
        </div>
      ) : (
        <div className="op-cards-grid">
          {paginatedOrders.map(order => {
            const isIntercity = order.category === 'intercity';
            const noCode = !order.verification_code && order.status === 'DELIVERED';
            const color = STATUS_COLORS[order.status] ?? '#6b7280';
            const bg    = STATUS_BG[order.status]    ?? '#f9fafb';
            return (
              <div
                key={order.id}
                className={`op-card ${isIntercity ? 'op-card--intercity' : ''} ${noCode ? 'op-card--nocode' : ''}`}
                onClick={() => openOrderDetails(order.id)}
              >
                {/* Header */}
                <div className="op-card-header">
                  <div className="op-card-id">
                    #{order.id}
                    {isIntercity && <span className="op-badge op-badge--intercity">🚌 Шаарлар аралык</span>}
                    {noCode && <span className="op-badge op-badge--nocode">Код жок</span>}
                  </div>
                  <span className="op-status-badge" style={{ background: color, boxShadow: `0 2px 8px ${color}55` }}>
                    {STATUS_LABELS[order.status]}
                  </span>
                </div>

                {/* Status color line */}
                <div className="op-card-colorline" style={{ background: color }} />

                {/* People row */}
                <div className="op-card-people">
                  <div className="op-person">
                    <User size={13} />
                    <span>{order.user_phone || '—'}</span>
                  </div>
                  <div className="op-person op-person--courier">
                    <Truck size={13} />
                    <span>{order.courier_phone || 'Курьер жок'}</span>
                  </div>
                </div>

                {/* Route */}
                <div className="op-card-route" style={{ background: bg }}>
                  <div className="op-route-point op-route-from">
                    <MapPin size={12} color="#6366f1" />
                    <span>{(order.pickup_location || '—').substring(0, 40)}</span>
                  </div>
                  <div className="op-route-divider" />
                  <div className="op-route-point op-route-to">
                    <MapPin size={12} color="#ef4444" />
                    <span>{(order.delivery_location || '—').substring(0, 40)}</span>
                  </div>
                </div>

                {/* Footer */}
                <div className="op-card-footer">
                  <div className="op-card-meta">
                    <span className="op-card-price">{order.estimated_price} сом</span>
                    {!isIntercity && <span className="op-card-km">{order.distance_km.toFixed(1)} км</span>}
                    <span className="op-card-date">{fmtDate(order.created_at)}</span>
                  </div>
                  <div className="op-card-actions" onClick={e => e.stopPropagation()}>
                    <button className="op-btn op-btn-view" title="Карап чыгуу"
                      onClick={() => openOrderDetails(order.id)}>
                      <Eye size={15} />
                    </button>
                    <button className="op-btn op-btn-delete" title="Өчүрүү"
                      onClick={() => quickDeleteOrder(order.id)}
                      disabled={deletingOrderIds.has(order.id)}>
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ── Pagination ── */}
      {filteredOrders.length > ITEMS_PER_PAGE && (
        <div className="table-pagination-wrap">
          <div className="table-pagination">
            <button className="page-btn" onClick={() => setCurrentPage(p => Math.max(1, p - 1))} disabled={currentPage === 1}>Артка</button>
            <span className="page-indicator">Бет {currentPage} / {totalPages}</span>
            <button className="page-btn" onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))} disabled={currentPage === totalPages}>Алга</button>
          </div>
        </div>
      )}

      {/* ── Detail drawer ── */}
      {(detailLoading || selectedOrder) && (
        <div className="order-detail-overlay" onClick={() => setSelectedOrder(null)}>
          <div className="order-detail-drawer" onClick={e => e.stopPropagation()}>
            <div className="order-detail-header">
              <h3>{detailLoading ? 'Жүктөлүүдө...' : `Заказ #${selectedOrder?.id}`}</h3>
              <button className="close-detail" onClick={() => setSelectedOrder(null)}>×</button>
            </div>

            {!detailLoading && selectedOrder && (
              <div className="order-detail-content">
                <p><strong>Статус:</strong> {STATUS_LABELS[selectedOrder.status]}</p>
                <p><strong>Колдонуучу:</strong> {selectedOrder.user_phone || '-'}</p>
                <p><strong>Курьер:</strong> {selectedOrder.courier_phone || 'Жок'}</p>
                <p><strong>Категория:</strong> {selectedOrder.category || '-'}</p>
                <p><strong>Маршрут:</strong> {selectedOrder.pickup_location} → {selectedOrder.delivery_location}</p>
                <p><strong>Дистанция:</strong> {selectedOrder.distance_km.toFixed(2)} км</p>
                {selectedOrder.status === 'DELIVERED' && (
                  <p>
                    <strong>Тастыктоо коду:</strong>{' '}
                    {selectedOrder.verification_code
                      ? <span className="verify-code-value">{selectedOrder.verification_code}</span>
                      : <span className="verify-code-missing">— Код жазыла элек</span>}
                  </p>
                )}

                {selectedOrder.description && (
                  <div className="detail-section">
                    <h4>Товарлар</h4>
                    <div className="order-items-list">
                      {selectedOrder.description.split('\n').map((line, i) => (
                        <div key={i} className="order-item-line">{line}</div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="detail-section">
                  <h4>Сумма</h4>
                  <div className="order-price-breakdown">
                    <div className="price-row">
                      <span>Товарлардын суммасы</span>
                      <span>{selectedOrder.estimated_price} сом</span>
                    </div>
                    {(selectedOrder.user_commission ?? 0) > 0 && (
                      <div className="price-row">
                        <span>Кызмат акысы</span>
                        <span>{selectedOrder.user_commission} сом</span>
                      </div>
                    )}
                    <div className="price-row price-total">
                      <span>Жалпы сумма</span>
                      <span>{(selectedOrder.estimated_price + (selectedOrder.user_commission ?? 0)).toFixed(0)} сом</span>
                    </div>
                  </div>
                </div>

                <p><strong>Түзүлгөн убакыт:</strong> {fmtDateTime(selectedOrder.created_at)}</p>
                <p><strong>Админ эскертмеси:</strong> {selectedOrder.admin_note || '-'}</p>

                <div className="detail-section">
                  <h4>Статус өзгөртүү</h4>
                  <div className="status-actions">
                    <select value={statusDraft} onChange={e => setStatusDraft(e.target.value as OrderStatus)}>
                      {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                    </select>
                    <input placeholder="Комментарий (optional)" value={statusNote} onChange={e => setStatusNote(e.target.value)} />
                    <button onClick={applyStatusChange} disabled={actionLoading} className="apply-btn">Сактоо</button>
                  </div>
                </div>

                <div className="detail-section">
                  <h4>Админ аракеттери</h4>
                  <button onClick={deleteSelectedOrder} disabled={actionLoading} className="delete-btn">Заказды өчүрүү</button>
                </div>

                <div className="detail-section">
                  <h4>Статус тарыхы</h4>
                  {selectedOrder.status_audit && selectedOrder.status_audit.length > 0 ? (
                    <div className="mini-list">
                      {selectedOrder.status_audit.map((log, idx) => (
                        <div key={idx} className="mini-item">
                          <div>{log.from_status || '-'} → {log.to_status}</div>
                          <div className="muted">{fmtDateTime(log.at)}</div>
                        </div>
                      ))}
                    </div>
                  ) : <p className="muted">Тарых жок</p>}
                </div>

                {(selectedOrder.pickup_lat !== 0 || selectedOrder.from_latitude) && (
                  <div className="detail-section">
                    <h4>Карта</h4>
                    {(() => {
                      const pLat = selectedOrder.from_latitude ?? selectedOrder.pickup_lat;
                      const pLon = selectedOrder.from_longitude ?? selectedOrder.pickup_lon;
                      const dLat = selectedOrder.to_latitude ?? selectedOrder.delivery_lat;
                      const dLon = selectedOrder.to_longitude ?? selectedOrder.delivery_lon;
                      if (!pLat && !dLat) return <p className="muted">Координаттар жок</p>;
                      const hasPickup = pLat && pLon;
                      const hasDelivery = dLat && dLon;
                      return (
                        <div className="order-map-links">
                          {hasPickup && (
                            <a
                              className="map-link map-link--pickup"
                              href={`https://www.openstreetmap.org/?mlat=${pLat}&mlon=${pLon}&zoom=15`}
                              target="_blank"
                              rel="noreferrer"
                            >
                              Алуу орду (OSM)
                            </a>
                          )}
                          {hasDelivery && (
                            <a
                              className="map-link map-link--delivery"
                              href={`https://www.openstreetmap.org/?mlat=${dLat}&mlon=${dLon}&zoom=15`}
                              target="_blank"
                              rel="noreferrer"
                            >
                              Жеткирүү орду (OSM)
                            </a>
                          )}
                          {hasPickup && (
                            <iframe
                              className="order-map-iframe"
                              title="Алуу орду"
                              src={`https://www.openstreetmap.org/export/embed.html?bbox=${pLon - 0.01},${pLat - 0.01},${pLon + 0.01},${pLat + 0.01}&layer=mapnik&marker=${pLat},${pLon}`}
                            />
                          )}
                        </div>
                      );
                    })()}
                  </div>
                )}

                <div className="detail-section">
                  <h4>Колдонуучуга билдирүү жөнөтүү</h4>
                  <div className="notify-form">
                    <input
                      className="notify-input"
                      placeholder="Аталышы (же бош калтырыңыз)"
                      value={notifyTitle}
                      onChange={e => setNotifyTitle(e.target.value)}
                    />
                    <textarea
                      className="notify-textarea"
                      placeholder="Билдирүүнүн тексти..."
                      rows={3}
                      value={notifyMessage}
                      onChange={e => setNotifyMessage(e.target.value)}
                    />
                    <button
                      className="apply-btn"
                      onClick={sendNotifyToUser}
                      disabled={notifySending}
                    >
                      {notifySending ? 'Жөнөтүлүүдө...' : 'Жөнөтүү'}
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
