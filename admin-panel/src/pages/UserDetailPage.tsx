import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { userService, UserOrder } from '@/services/users';
import { User } from '@/types';
import {
  ArrowLeft, User as UserIcon, Phone, Shield, Truck,
  Star, Package, CheckCircle, XCircle, RefreshCw,
  Wallet, Calendar, ChevronLeft, ChevronRight,
} from 'lucide-react';
import './UserDetailPage.css';

const ORDERS_PER_PAGE = 20;

const STATUS_LABELS: Record<string, string> = {
  WAITING_COURIER: 'Курьер күтүүдө',
  ACCEPTED: 'Кабыл алынды',
  PREPARING: 'Даярдалып жатат',
  READY: 'Даяр',
  ON_THE_WAY: 'Жолдо',
  DELIVERED: 'Жеткирилди',
  COMPLETED: 'Аяктады',
  CANCELLED: 'Жокко чыгарылды',
};

const STATUS_CLASS: Record<string, string> = {
  WAITING_COURIER: 'status-waiting',
  ACCEPTED: 'status-accepted',
  PREPARING: 'status-preparing',
  READY: 'status-ready',
  ON_THE_WAY: 'status-onway',
  DELIVERED: 'status-delivered',
  COMPLETED: 'status-completed',
  CANCELLED: 'status-cancelled',
};

function formatDate(iso: string) {
  const d = new Date(iso);
  return d.toLocaleDateString('ky-KG', { day: '2-digit', month: '2-digit', year: 'numeric' })
    + ' ' + d.toLocaleTimeString('ky-KG', { hour: '2-digit', minute: '2-digit' });
}

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const userId = Number(id);

  const [user, setUser] = useState<User | null>(null);
  const [userLoading, setUserLoading] = useState(true);

  const [orders, setOrders] = useState<UserOrder[]>([]);
  const [ordersTotal, setOrdersTotal] = useState(0);
  const [ordersLoading, setOrdersLoading] = useState(true);
  const [page, setPage] = useState(1);

  useEffect(() => {
    loadUser();
  }, [userId]);

  useEffect(() => {
    loadOrders(page);
  }, [userId, page]);

  const loadUser = async () => {
    setUserLoading(true);
    try {
      const data = await userService.getUserById(userId);
      setUser(data);
    } catch {
      alert('Колдонуучу маалыматын жүктөө мүмкүн болгон жок');
    } finally {
      setUserLoading(false);
    }
  };

  const loadOrders = async (p: number) => {
    setOrdersLoading(true);
    try {
      const skip = (p - 1) * ORDERS_PER_PAGE;
      const data = await userService.getUserOrders(userId, skip, ORDERS_PER_PAGE);
      setOrders(data.orders);
      setOrdersTotal(data.total);
    } catch {
      /* silent */
    } finally {
      setOrdersLoading(false);
    }
  };

  const totalPages = Math.max(1, Math.ceil(ordersTotal / ORDERS_PER_PAGE));

  if (userLoading) {
    return (
      <div className="ud-loading">
        <div className="spinner" />
        <p>Жүктөлүүдө...</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="ud-loading">
        <p>Колдонуучу табылган жок</p>
        <button onClick={() => navigate('/users')}>← Артка</button>
      </div>
    );
  }

  const isCourier = user.role === 'courier';
  const isAdmin = user.role === 'admin';

  return (
    <div className="ud-page">
      {/* Back */}
      <button className="ud-back" onClick={() => navigate('/users')}>
        <ArrowLeft size={16} /> Колдонуучулар
      </button>

      {/* Header card */}
      <div className="ud-header-card">
        <div className="ud-avatar">
          {isAdmin ? <Shield size={32} /> : isCourier ? <Truck size={32} /> : <UserIcon size={32} />}
        </div>
        <div className="ud-header-info">
          <h1>{user.name || user.phone}</h1>
          <div className="ud-badges">
            <span className={`ud-role-badge ud-role-${user.role}`}>
              {isAdmin ? 'Админ' : isCourier ? 'Курьер' : 'Колдонуучу'}
            </span>
            {user.is_active ? (
              <span className="ud-status-badge ud-active"><CheckCircle size={13} /> Активдүү</span>
            ) : (
              <span className="ud-status-badge ud-blocked"><XCircle size={13} /> Блоктолгон</span>
            )}
            {isCourier && (
              <span className={`ud-status-badge ${user.is_online ? 'ud-online' : 'ud-offline'}`}>
                {user.is_online ? 'Онлайн' : 'Офлайн'}
              </span>
            )}
          </div>
        </div>
        <button className="ud-refresh-btn" onClick={loadUser} title="Жаңылоо">
          <RefreshCw size={16} />
        </button>
      </div>

      {/* Info grid */}
      <div className="ud-info-grid">
        <div className="ud-info-card">
          <div className="ud-info-icon"><Phone size={18} /></div>
          <div>
            <div className="ud-info-label">Телефон</div>
            <div className="ud-info-value">{user.phone}</div>
          </div>
        </div>

        <div className="ud-info-card">
          <div className="ud-info-icon"><UserIcon size={18} /></div>
          <div>
            <div className="ud-info-label">Жеке номер</div>
            <div className="ud-info-value">{user.unique_id || '—'}</div>
          </div>
        </div>

        <div className="ud-info-card">
          <div className="ud-info-icon"><Wallet size={18} /></div>
          <div>
            <div className="ud-info-label">Баланс</div>
            <div className="ud-info-value ud-balance">{user.balance} сом</div>
          </div>
        </div>

        {isCourier && (
          <div className="ud-info-card">
            <div className="ud-info-icon"><Star size={18} /></div>
            <div>
              <div className="ud-info-label">Рейтинг</div>
              <div className="ud-info-value">
                {typeof user.average_rating === 'number'
                  ? `⭐ ${user.average_rating.toFixed(2)}`
                  : '—'}
              </div>
            </div>
          </div>
        )}

        <div className="ud-info-card">
          <div className="ud-info-icon"><Package size={18} /></div>
          <div>
            <div className="ud-info-label">{isCourier ? 'Алган заказдар' : 'Жалпы заказдар'}</div>
            <div className="ud-info-value">{user.total_orders ?? 0}</div>
          </div>
        </div>

        <div className="ud-info-card">
          <div className="ud-info-icon"><CheckCircle size={18} /></div>
          <div>
            <div className="ud-info-label">Аяктаган заказдар</div>
            <div className="ud-info-value">{user.completed_orders ?? 0}</div>
          </div>
        </div>

        {user.created_at && (
          <div className="ud-info-card">
            <div className="ud-info-icon"><Calendar size={18} /></div>
            <div>
              <div className="ud-info-label">Катталган күн</div>
              <div className="ud-info-value">{formatDate(user.created_at)}</div>
            </div>
          </div>
        )}
      </div>

      {/* Ratings section (couriers only) */}
      {isCourier && user.recent_ratings && user.recent_ratings.length > 0 && (
        <div className="ud-section">
          <h2 className="ud-section-title">Акыркы рейтингдер</h2>
          <div className="ud-ratings-list">
            {user.recent_ratings.map((r, i) => (
              <div key={i} className="ud-rating-item">
                <div className="ud-rating-stars">{'⭐'.repeat(r.rating)}</div>
                <div className="ud-rating-comment">{r.comment || <span className="ud-muted">Комментарий жок</span>}</div>
                <div className="ud-rating-order">Заказ #{r.order_id}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Orders history */}
      <div className="ud-section">
        <div className="ud-section-header">
          <h2 className="ud-section-title">
            {isCourier ? 'Алган заказдар тарыхы' : 'Заказдар тарыхы'}
            <span className="ud-orders-count">{ordersTotal}</span>
          </h2>
        </div>

        {ordersLoading ? (
          <div className="ud-orders-loading"><div className="spinner" /></div>
        ) : orders.length === 0 ? (
          <div className="ud-empty">Заказдар жок</div>
        ) : (
          <>
            <div className="ud-orders-table-wrap">
              <table className="ud-orders-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Статус</th>
                    <th>{isCourier ? 'Кардар' : 'Курьер'}</th>
                    <th>Кайдан</th>
                    <th>Кайда</th>
                    <th>Баасы</th>
                    <th>Убакыт</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((o) => (
                    <tr key={o.id}>
                      <td className="ud-order-id">#{o.id}</td>
                      <td>
                        <span className={`ud-order-status ${STATUS_CLASS[o.status] ?? ''}`}>
                          {STATUS_LABELS[o.status] ?? o.status}
                        </span>
                      </td>
                      <td className="ud-muted-cell">
                        {isCourier
                          ? (o.user_name || o.user_phone || '—')
                          : (o.courier_name || '—')}
                      </td>
                      <td className="ud-addr-cell">{o.from_address}</td>
                      <td className="ud-addr-cell">{o.to_address}</td>
                      <td className="ud-price-cell">{o.price} сом</td>
                      <td className="ud-date-cell">{o.created_at ? formatDate(o.created_at) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {totalPages > 1 && (
              <div className="ud-pagination">
                <button
                  className="ud-page-btn"
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page === 1}
                >
                  <ChevronLeft size={16} />
                </button>
                <span className="ud-page-info">
                  {page} / {totalPages}
                </span>
                <button
                  className="ud-page-btn"
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages}
                >
                  <ChevronRight size={16} />
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
