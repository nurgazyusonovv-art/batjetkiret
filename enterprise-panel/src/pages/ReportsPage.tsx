import { useEffect, useState } from 'react';
import { BarChart2, TrendingUp, Package, CheckCircle, XCircle, Smartphone, Store, UtensilsCrossed, Loader } from 'lucide-react';
import { ordersService, ReportData } from '../services/orders';
import './ReportsPage.css';

type Period = 1 | 7 | 30;

const PERIOD_LABELS: Record<Period, string> = {
  1: 'Бүгүн',
  7: '7 күн',
  30: '30 күн',
};

function Skeleton() {
  return <div className="ep-skeleton" />;
}

export default function ReportsPage() {
  const [period, setPeriod] = useState<Period>(7);
  const [data, setData] = useState<ReportData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setData(null);     // эски маалыматты дароо тазала
    setLoading(true);
    ordersService.getReports(period)
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [period]);

  const maxRevenue = data ? Math.max(...data.daily.map(d => d.revenue), 1) : 1;
  const maxOrders = data ? Math.max(...data.daily.map(d => d.orders), 1) : 1;

  return (
    <div className="ep-reports">
      <div className="ep-reports-header">
        <div className="ep-reports-title">
          <BarChart2 size={22} />
          <h1>Отчет</h1>
          {loading && <Loader size={16} className="spin-icon" style={{ color: '#9ca3af' }} />}
        </div>
        <div className="ep-period-tabs">
          {([1, 7, 30] as Period[]).map(p => (
            <button
              key={p}
              className={`ep-period-tab ${period === p ? 'active' : ''}`}
              onClick={() => setPeriod(p)}
            >
              {PERIOD_LABELS[p]}
            </button>
          ))}
        </div>
      </div>

      {/* Summary cards — skeleton же маалымат */}
      <div className="ep-report-cards">
        {loading ? (
          <>
            <div className="ep-report-card revenue"><div className="erc-icon" /><div style={{ flex: 1 }}><Skeleton /><Skeleton /></div></div>
            <div className="ep-report-card total"><div className="erc-icon" /><div style={{ flex: 1 }}><Skeleton /><Skeleton /></div></div>
            <div className="ep-report-card completed"><div className="erc-icon" /><div style={{ flex: 1 }}><Skeleton /><Skeleton /></div></div>
            <div className="ep-report-card cancelled"><div className="erc-icon" /><div style={{ flex: 1 }}><Skeleton /><Skeleton /></div></div>
          </>
        ) : data ? (
          <>
            <div className="ep-report-card revenue">
              <div className="erc-icon"><TrendingUp size={20} /></div>
              <div>
                <div className="erc-value">{data.total_revenue.toFixed(0)} сом</div>
                <div className="erc-label">Жалпы киреше · {PERIOD_LABELS[period]}</div>
              </div>
            </div>
            <div className="ep-report-card total">
              <div className="erc-icon"><Package size={20} /></div>
              <div>
                <div className="erc-value">{data.total_orders}</div>
                <div className="erc-label">Бардык заказдар · {PERIOD_LABELS[period]}</div>
              </div>
            </div>
            <div className="ep-report-card completed">
              <div className="erc-icon"><CheckCircle size={20} /></div>
              <div>
                <div className="erc-value">{data.completed_orders}</div>
                <div className="erc-label">Аяктаган · {PERIOD_LABELS[period]}</div>
              </div>
            </div>
            <div className="ep-report-card cancelled">
              <div className="erc-icon"><XCircle size={20} /></div>
              <div>
                <div className="erc-value">{data.cancelled_orders}</div>
                <div className="erc-label">Жокко чыгарылган · {PERIOD_LABELS[period]}</div>
              </div>
            </div>
          </>
        ) : null}
      </div>

      {/* Каналдар */}
      {!loading && data && (
        <>
          <div className="ep-report-section-label">Каналдар боюнча · {PERIOD_LABELS[period]}</div>
          <div className="ep-source-cards">
            <div className="ep-source-card">
              <Smartphone size={18} color="#4f46e5" />
              <div>
                <div className="esc-value">{data.online_orders}</div>
                <div className="esc-label">Онлайн заказ</div>
              </div>
              <div className="esc-revenue">{data.online_revenue.toFixed(0)} сом</div>
            </div>
            <div className="ep-source-card">
              <Store size={18} color="#059669" />
              <div>
                <div className="esc-value">{data.local_orders}</div>
                <div className="esc-label">Жергиликтүү</div>
              </div>
              <div className="esc-revenue">{data.local_revenue.toFixed(0)} сом</div>
            </div>
            <div className="ep-source-card">
              <UtensilsCrossed size={18} color="#b45309" />
              <div>
                <div className="esc-value">{data.dine_in_orders}</div>
                <div className="esc-label">Столдо</div>
              </div>
              <div className="esc-revenue" title="Жергиликтүү кирешеге кирет">
                {data.dine_in_orders > 0 ? '↑ кирет' : '—'}
              </div>
            </div>
          </div>

          {/* Диаграмма */}
          {period > 1 && data.daily.length > 0 && (
            <>
              <div className="ep-report-section-label">Киреше боюнча ({PERIOD_LABELS[period]})</div>
              <div className="ep-chart-wrap">
                <div className="ep-bar-chart">
                  {data.daily.map(day => {
                    const heightPct = maxRevenue > 0 ? (day.revenue / maxRevenue) * 100 : 0;
                    const dateLabel = new Date(day.date).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
                    return (
                      <div key={day.date} className="ep-bar-col">
                        <div className="ep-bar-value">{day.revenue > 0 ? day.revenue.toFixed(0) : ''}</div>
                        <div className="ep-bar-wrap">
                          <div className="ep-bar-fill" style={{ height: `${heightPct}%` }} />
                        </div>
                        <div className="ep-bar-label">{dateLabel}</div>
                        <div className="ep-bar-orders">{day.orders > 0 ? `${day.orders} з` : ''}</div>
                      </div>
                    );
                  })}
                </div>
              </div>

              <div className="ep-report-section-label">Заказдар боюнча ({PERIOD_LABELS[period]})</div>
              <div className="ep-chart-wrap">
                <div className="ep-bar-chart orders-chart">
                  {data.daily.map(day => {
                    const heightPct = maxOrders > 0 ? (day.orders / maxOrders) * 100 : 0;
                    const dateLabel = new Date(day.date).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
                    return (
                      <div key={day.date} className="ep-bar-col">
                        <div className="ep-bar-value">{day.orders > 0 ? day.orders : ''}</div>
                        <div className="ep-bar-wrap">
                          <div className="ep-bar-fill orders" style={{ height: `${heightPct}%` }} />
                        </div>
                        <div className="ep-bar-label">{dateLabel}</div>
                        {day.cancelled > 0 && <div className="ep-bar-cancelled">−{day.cancelled}</div>}
                      </div>
                    );
                  })}
                </div>
              </div>
            </>
          )}

          {period === 1 && (
            <div className="ep-today-summary">
              <div className="ep-report-section-label">Бүгүнкү жыйынтык</div>
              <div className="ep-today-grid">
                <div className="ep-today-card">
                  <span>Жалпы заказ</span>
                  <strong>{data.total_orders}</strong>
                </div>
                <div className="ep-today-card">
                  <span>Аяктаган</span>
                  <strong style={{ color: '#059669' }}>{data.completed_orders}</strong>
                </div>
                <div className="ep-today-card">
                  <span>Жокко чыгарылган</span>
                  <strong style={{ color: '#dc2626' }}>{data.cancelled_orders}</strong>
                </div>
                <div className="ep-today-card">
                  <span>Активдүү</span>
                  <strong style={{ color: '#d97706' }}>{data.active_orders}</strong>
                </div>
                <div className="ep-today-card wide">
                  <span>Киреше</span>
                  <strong style={{ color: '#4f46e5' }}>{data.total_revenue.toFixed(0)} сом</strong>
                </div>
              </div>
            </div>
          )}
        </>
      )}

      {!loading && data && data.total_orders === 0 && (
        <div className="ep-empty" style={{ marginTop: 24 }}>
          <Package size={48} opacity={0.2} />
          <p>{PERIOD_LABELS[period]} ичинде заказ жок</p>
        </div>
      )}
    </div>
  );
}
