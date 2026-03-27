import { useCallback, useEffect, useState } from 'react';
import { Package, Users, Wallet, TrendingUp, AlertCircle } from 'lucide-react';
import { statsService, topupService } from '@/services/admin';
import { RevenueByDate, SystemStats, TopupRequest } from '@/types';
import { getErrorMessage } from '@/utils/error';
import { useNavigate } from 'react-router-dom';
import './DashboardPage.css';

export default function DashboardPage() {
  const navigate = useNavigate();
  const [stats, setStats] = useState<SystemStats | null>(null);
  const [pendingTopups, setPendingTopups] = useState<TopupRequest[]>([]);
  const [revenueTrend, setRevenueTrend] = useState<RevenueByDate[]>([]);
  const [rangeDays, setRangeDays] = useState<7 | 14 | 30>(7);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      const [statsData, topupsData, trendData] = await Promise.all([
        statsService.getSystemStats(),
        topupService.getPendingTopups(),
        statsService.getRevenueByDate(rangeDays),
      ]);
      setStats(statsData);
      setPendingTopups(topupsData);
      setRevenueTrend(trendData);
    } catch (error: unknown) {
      setError(getErrorMessage(error, 'Failed to load data'));
    } finally {
      setLoading(false);
    }
  }, [rangeDays]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const loadRevenueTrend = async (days: 7 | 14 | 30) => {
    try {
      const trendData = await statsService.getRevenueByDate(days);
      setRevenueTrend(trendData);
    } catch (error) {
      console.error('Failed to load revenue trend:', error);
    }
  };

  const handleBarClick = async (date: string) => {
    try {
      const dateStats = await statsService.getDateStats(date);
      setStats(dateStats);
      setSelectedDate(date);
    } catch (error) {
      console.error('Failed to load date stats:', error);
    }
  };

  const handleResetToToday = async () => {
    try {
      const todayStats = await statsService.getSystemStats();
      setStats(todayStats);
      setSelectedDate(null);
    } catch (error) {
      console.error('Failed to load today stats:', error);
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
        <p>Жүктөлүүдө...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="error-container">
        <AlertCircle size={48} />
        <p>{error}</p>
        <button onClick={loadData}>Кайра аракет</button>
      </div>
    );
  }

  const statCards = [
    {
      icon: Package,
      title: 'Күтүүдөгү заказдар',
      value: stats?.waiting_orders || 0,
      color: '#667eea',
      subtitle: `Жалпы: ${stats?.total_orders || 0}`,
      onClick: () => navigate('/orders?status=WAITING_COURIER'),
    },
    {
      icon: Users,
      title: 'Курьерлер',
      value: stats?.total_couriers || 0,
      color: '#10b981',
      subtitle: `Онлайн: ${stats?.online_couriers || 0}`,
      onClick: () => navigate('/users?role=courier&online=true'),
    },
    {
      icon: Wallet,
      title: 'Топап өтүнүчтөр',
      value: stats?.pending_topups || 0,
      color: '#f59e0b',
      subtitle: 'Күтүүдө',
    },
    {
      icon: TrendingUp,
      title: 'Киреше',
      value: `${stats?.total_revenue || 0} сом`,
      color: '#8b5cf6',
      subtitle: `${stats?.completed_orders || 0} аяктаган`,
    },
  ];

  const maxRevenue = Math.max(...revenueTrend.map((r) => r.revenue), 1);

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <div>
          <h1>Dashboard</h1>
          <p className="subtitle">Системанын жалпы көрүнүшү</p>
        </div>
        <button className="refresh-btn" onClick={loadData}>Жаңылоо</button>
      </div>

      <div className="stats-grid">
        {statCards.map((card, index) => {
          const Icon = card.icon;
          return (
            <div
              key={index}
              className="stat-card"
              onClick={card.onClick}
              role={card.onClick ? 'button' : undefined}
              tabIndex={card.onClick ? 0 : undefined}
              onKeyDown={(e) => {
                if (card.onClick && (e.key === 'Enter' || e.key === ' ')) {
                  e.preventDefault();
                  card.onClick();
                }
              }}
              style={{ cursor: card.onClick ? 'pointer' : 'default' }}
            >
              <div className="stat-icon" style={{ background: card.color }}>
                <Icon size={24} color="white" />
              </div>
              <div className="stat-content">
                <p className="stat-title">{card.title}</p>
                <h2 className="stat-value">{card.value}</h2>
                <p className="stat-subtitle">{card.subtitle}</p>
              </div>
            </div>
          );
        })}
      </div>

      <div className="recent-section revenue-chart-section">
        <div className="revenue-chart-header">
          <div>
            <h2>Киреше графиги</h2>
            <p>Аяктаган заказдардын кирешеси</p>
          </div>
          <div className="range-switcher">
            {[7, 14, 30].map((days) => (
              <button
                key={days}
                className={`range-btn ${rangeDays === days ? 'active' : ''}`}
                onClick={async () => {
                  const selected = days as 7 | 14 | 30;
                  setRangeDays(selected);
                  await loadRevenueTrend(selected);
                }}
              >
                {days} күн
              </button>
            ))}
          </div>
        </div>

        <div className="revenue-bars">
          {revenueTrend.map((point) => {
            const ratio = point.revenue / maxRevenue;
            const height = Math.max(12, Math.round(ratio * 160));
            const day = new Date(point.date).toLocaleDateString('ru-RU', {
              day: '2-digit',
              month: '2-digit',
            });
            const isSelected = selectedDate === point.date;

            return (
              <div 
                className={`revenue-bar-col ${isSelected ? 'selected' : ''}`} 
                key={point.date}
                onClick={() => handleBarClick(point.date)}
              >
                <div className="revenue-bar-value">{point.revenue} сом</div>
                <div className="revenue-bar-wrap">
                  <div className="revenue-bar" style={{ height }} />
                </div>
                <div className="revenue-bar-day">{day}</div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Today's Statistics Section */}
      <div className="recent-section today-section">
        <div className="today-section-header">
          <h2>
            {selectedDate ? (
              <>
                {new Date(selectedDate).toLocaleDateString('ru-RU', {
                  day: 'numeric',
                  month: 'long',
                  year: 'numeric',
                })} статистика
              </>
            ) : (
              'Бүгүнкү статистика'
            )}
          </h2>
          {selectedDate && (
            <button className="reset-date-btn" onClick={handleResetToToday}>
              Бүгүнгүнө қайра</button>
          )}
        </div>
        <div className="today-stats-grid">
          <div className="today-stat-card">
            <div className="today-stat-header">
              <Package size={20} color="#667eea" />
              <span>Жалпы заказдар</span>
            </div>
            <div className="today-stat-value">{stats?.total_orders_today || 0}</div>
          </div>
          
          <div className="today-stat-card">
            <div className="today-stat-header">
              <TrendingUp size={20} color="#10b981" />
              <span>Жеткирилген</span>
            </div>
            <div className="today-stat-value success">{stats?.delivered_orders_today || 0}</div>
          </div>
          
          <div className="today-stat-card">
            <div className="today-stat-header">
              <AlertCircle size={20} color="#ef4444" />
              <span>Отмена</span>
            </div>
            <div className="today-stat-value danger">{stats?.canceled_orders_today || 0}</div>
          </div>
          
          <div className="today-stat-card">
            <div className="today-stat-header">
              <Wallet size={20} color="#8b5cf6" />
              <span>Киреше</span>
            </div>
            <div className="today-stat-value primary">{stats?.revenue_today || 0} сом</div>
          </div>
        </div>
      </div>

      {pendingTopups.length > 0 && (
        <div className="recent-section">
          <h2>Акыркы топап өтүнүчтөр</h2>
          <div className="topup-list">
            {pendingTopups.slice(0, 5).map((topup) => (
              <div key={topup.id} className="topup-item">
                <div className="topup-info">
                  <p className="topup-user">{topup.user?.phone}</p>
                  <p className="topup-date">
                    {new Date(topup.created_at).toLocaleString('ru-RU')}
                  </p>
                </div>
                <div className="topup-amount">
                  {topup.amount} сом
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
