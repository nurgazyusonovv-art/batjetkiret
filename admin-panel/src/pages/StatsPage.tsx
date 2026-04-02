import { useEffect, useState } from 'react';
import { statsService } from '@/services/admin';
import { RevenueByDate, SystemStats, PaymentStats } from '@/types';
import { fmtDate } from '@/utils/date';
import './StatsPage.css';

export default function StatsPage() {
  const [stats, setStats] = useState<SystemStats | null>(null);
  const [paymentStats, setPaymentStats] = useState<PaymentStats | null>(null);
  const [revenue, setRevenue] = useState<RevenueByDate[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [paymentRange, setPaymentRange] = useState<'all' | 'today' | '7days' | '30days'>('all');
  const [commissionPercent, setCommissionPercent] = useState<number>(10);
  const [commissionData, setCommissionData] = useState<{ percent: number; total_completed_amount: number; commission_amount: number } | null>(null);

  const load = async () => {
    try {
      setLoading(true);
      const [statsData, revenueData] = await Promise.all([
        statsService.getSystemStats(),
        statsService.getRevenueByDate(7),
      ]);
      setStats(statsData);
      setRevenue(revenueData);
      setError('');
    } catch (e) {
      setError('Статистиканы жүктөө мүмкүн болгон жок');
    } finally {
      setLoading(false);
    }
  };

  const loadPaymentStats = async (range: string) => {
    try {
      const data = await statsService.getPaymentStats(range);
      setPaymentStats(data);
    } catch (e) {
      console.error('Payment stats loading error:', e);
    }
  };

  useEffect(() => {
    load();
    // Auto-refresh every 30 seconds
    const interval = setInterval(load, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    loadPaymentStats(paymentRange);
  }, [paymentRange]);

  useEffect(() => {
    statsService.getCommission(commissionPercent)
      .then(data => setCommissionData(data))
      .catch(() => {});
  }, [commissionPercent]);

  if (loading) {
    return <div className="loading-container"><p>Жүктөлүүдө...</p></div>;
  }

  if (error) {
    return <div className="error-container"><p>{error}</p><button onClick={load}>Кайра аракет</button></div>;
  }

  const maxRevenue = Math.max(...revenue.map((r) => r.revenue), 1);

  return (
    <div className="stats-page">
      <div className="stats-header">
        <div>
        <h1>Статистика</h1>
          <p className="stats-subtitle">Системанын негизги көрсөткүчтөрү</p>
        </div>
        <button className="stats-refresh-btn" onClick={load}>Жаңылоо</button>
      </div>

      <div className="revenue-chart-card">
        <div className="revenue-chart-header">
          <h3>Акыркы 7 күндөгү киреше графиги</h3>
          <p>Күн сайын аяктаган заказдардын негизинде (10 сом/заказ)</p>
        </div>

        <div className="revenue-bars">
          {revenue.map((point) => {
            const ratio = point.revenue / maxRevenue;
            const height = Math.max(12, Math.round(ratio * 180));
            const day = fmtDate(point.date).slice(0, 5); // DD.MM
            return (
              <div className="revenue-bar-col" key={point.date}>
                <div className="revenue-bar-value">{point.revenue} сом</div>
                <div className="revenue-bar-wrap">
                  <div className="revenue-bar" style={{ height }} title={`${point.date}: ${point.revenue} сом`} />
                </div>
                <div className="revenue-bar-day">{day}</div>
                <div className="revenue-bar-orders">{point.orders} заказ</div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="stats-details">
        <div className="stats-details-grid">
          <div className="stats-detail-item">
            <p className="stats-detail-label">Бүгүн жалпы заказ</p>
            <p className="stats-detail-value">{stats?.total_orders_today ?? 0}</p>
          </div>
          <div className="stats-detail-item">
            <p className="stats-detail-label">Бүгүн жеткирилген</p>
            <p className="stats-detail-value">{stats?.delivered_orders_today ?? 0}</p>
          </div>
          <div className="stats-detail-item">
            <p className="stats-detail-label">Бүгүн отмена</p>
            <p className="stats-detail-value">{stats?.canceled_orders_today ?? 0}</p>
          </div>
          <div className="stats-detail-item">
            <p className="stats-detail-label">Бүгүн киреше</p>
            <p className="stats-detail-value">{stats?.revenue_today ?? 0} сом</p>
          </div>
          <div className="stats-detail-item">
            <p className="stats-detail-label">Жалпы колдонуучулар</p>
            <p className="stats-detail-value">{stats?.total_users ?? 0}</p>
          </div>
          <div className="stats-detail-item">
            <p className="stats-detail-label">Активдүү заказдар</p>
            <p className="stats-detail-value">{stats?.active_orders ?? 0}</p>
          </div>
        </div>
      </div>

      <div className="stats-details payment-stats">
        <div className="payment-stats-header">
          <div>
            <h3>Төлөмдөр статистикасы</h3>
            <p>Топап өтүнүчтөрүнүн жалпы абалы</p>
          </div>
          <div className="payment-stats-filters">
            <button 
              className={`filter-btn ${paymentRange === 'all' ? 'active' : ''}`}
              onClick={() => setPaymentRange('all')}
            >
              Бүгүндө
            </button>
            <button 
              className={`filter-btn ${paymentRange === 'today' ? 'active' : ''}`}
              onClick={() => setPaymentRange('today')}
            >
              Бүгүн
            </button>
            <button 
              className={`filter-btn ${paymentRange === '7days' ? 'active' : ''}`}
              onClick={() => setPaymentRange('7days')}
            >
              7 күн
            </button>
            <button 
              className={`filter-btn ${paymentRange === '30days' ? 'active' : ''}`}
              onClick={() => setPaymentRange('30days')}
            >
              30 күн
            </button>
          </div>
        </div>
        <div className="stats-details-grid">
          <div className="stats-detail-item stats-detail-approved">
            <p className="stats-detail-label">Тастыкталган төлөмдөр</p>
            <p className="stats-detail-value">{paymentStats?.approved_topups_count ?? 0} даана</p>
            <p className="stats-detail-sub">{paymentStats?.approved_topups_amount ?? 0} сом</p>
          </div>
          <div className="stats-detail-item stats-detail-rejected">
            <p className="stats-detail-label">Четке кагылган төлөмдөр</p>
            <p className="stats-detail-value">{paymentStats?.rejected_topups_count ?? 0} даана</p>
            <p className="stats-detail-sub">{paymentStats?.rejected_topups_amount ?? 0} сом</p>
          </div>
          <div className="stats-detail-item stats-detail-pending">
            <p className="stats-detail-label">Күтүүдөгү төлөмдөр</p>
            <p className="stats-detail-value">{paymentStats?.pending_topups_count ?? 0} даана</p>
            <p className="stats-detail-sub">{paymentStats?.pending_topups_amount ?? 0} сом</p>
          </div>
        </div>
      </div>
      <div className="stats-details commission-section">
        <div className="payment-stats-header">
          <div>
            <h3>Комиссия эсеби</h3>
            <p>Аяктаган заказдардын жалпы суммасынан комиссия</p>
          </div>
          <div className="payment-stats-filters">
            {[5, 10, 15, 20].map(p => (
              <button
                key={p}
                className={`filter-btn ${commissionPercent === p ? 'active' : ''}`}
                onClick={() => setCommissionPercent(p)}
              >
                {p}%
              </button>
            ))}
          </div>
        </div>
        {commissionData && (
          <div className="stats-details-grid">
            <div className="stats-detail-item">
              <p className="stats-detail-label">Аяктаган заказдардын суммасы</p>
              <p className="stats-detail-value">{commissionData.total_completed_amount.toFixed(0)} сом</p>
            </div>
            <div className="stats-detail-item stats-detail-approved">
              <p className="stats-detail-label">Комиссия суммасы ({commissionData.percent}%)</p>
              <p className="stats-detail-value">{commissionData.commission_amount.toFixed(0)} сом</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
