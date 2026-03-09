import { useEffect, useMemo, useState } from 'react';
import { Search, Ban, CheckCircle, XCircle, Trash2, UserCog, Pencil, Lock } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';
import { userService } from '@/services/users';
import { User } from '@/types';
import './UsersPage.css';

const ITEMS_PER_PAGE = 10;

export default function UsersPage() {
  const [searchParams] = useSearchParams();
  const [users, setUsers] = useState<User[]>([]);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState<'all' | 'user' | 'courier' | 'admin'>('all');
  const [onlineOnly, setOnlineOnly] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<User | null>(null);
  const [editName, setEditName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editRole, setEditRole] = useState<'user' | 'courier' | 'admin'>('user');
  const [passwordModalOpen, setPasswordModalOpen] = useState(false);
  const [passwordTarget, setPasswordTarget] = useState<User | null>(null);
  const [newPassword, setNewPassword] = useState('');
  const [passwordConfirm, setPasswordConfirm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);

  useEffect(() => {
    const role = searchParams.get('role');
    if (role === 'user' || role === 'courier' || role === 'admin' || role === 'all') {
      setRoleFilter(role);
    }

    setOnlineOnly(searchParams.get('online') === 'true');

    loadUsers();
  }, [searchParams]);

  const loadUsers = async () => {
    try {
      setLoading(true);
      const data = await userService.getUsers({ limit: 200 });
      setUsers(data);
    } catch (err) {
      console.error('Failed to load users:', err);
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = useMemo(() => {
    let filtered = users;

    if (searchQuery) {
      filtered = filtered.filter(
        (user) =>
          user.phone.includes(searchQuery) ||
          user.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          user.id.toString().includes(searchQuery)
      );
    }

    if (roleFilter !== 'all') {
      filtered = filtered.filter((user) => user.role === roleFilter);
    }

    if (onlineOnly) {
      filtered = filtered.filter((user) => user.role === 'courier' && user.is_online === true);
    }

    return filtered;
  }, [users, searchQuery, roleFilter, onlineOnly]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / ITEMS_PER_PAGE));

  const paginatedUsers = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredUsers.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredUsers, currentPage]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, roleFilter, onlineOnly, users]);

  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  const handleBlockUser = async (userId: number) => {
    if (!confirm('Бул колдонуучуну блоктогонго ишенесизби?')) return;
    
    setActionLoading(true);
    try {
      await userService.blockUser(userId);
      await loadUsers();
    } catch (err) {
      console.error('Failed to block user:', err);
      alert('Блоктоо жаңылыштыкка учурады');
    } finally {
      setActionLoading(false);
    }
  };

  const handleUnblockUser = async (userId: number) => {
    setActionLoading(true);
    try {
      await userService.unblockUser(userId);
      await loadUsers();
    } catch (err) {
      console.error('Failed to unblock user:', err);
      alert('Анблоктоо жаңылыштыкка учурады');
    } finally {
      setActionLoading(false);
    }
  };

  const openUserDetails = async (user: User) => {
    setDetailLoading(true);
    try {
      const details = await userService.getUserById(user.id);
      setSelectedUser(details);
    } catch (err) {
      console.error('Failed to load user details:', err);
      alert('Колдонуучу маалыматын жүктөө мүмкүн болгон жок');
    } finally {
      setDetailLoading(false);
    }
  };

  const openEditModal = (user: User) => {
    setEditTarget(user);
    setEditName(user.name || '');
    setEditPhone(user.phone || '');
    setEditRole(user.role);
    setEditModalOpen(true);
  };

  const closeEditModal = () => {
    if (actionLoading) return;
    setEditModalOpen(false);
    setEditTarget(null);
  };

  const submitEditUser = async () => {
    if (!editTarget) return;
    if (!editName.trim() || !editPhone.trim()) {
      alert('Аты жана телефон толтурулушу керек');
      return;
    }

    setActionLoading(true);
    try {
      await userService.updateUser(editTarget.id, {
        name: editName.trim(),
        phone: editPhone.trim(),
        role: editRole,
      });
      await loadUsers();
      if (selectedUser?.id === editTarget.id) {
        const details = await userService.getUserById(editTarget.id);
        setSelectedUser(details);
      }
      closeEditModal();
    } catch (err) {
      console.error('Failed to update user:', err);
      alert('Колдонуучуну жаңылоо мүмкүн болгон жок');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteUser = async (user: User) => {
    if (!confirm(`${user.phone} колдонуучусун базадан өчүрөсүзбү?`)) return;

    setActionLoading(true);
    try {
      await userService.deleteUser(user.id);
      if (selectedUser?.id === user.id) {
        setSelectedUser(null);
      }
      await loadUsers();
    } catch (err) {
      console.error('Failed to delete user:', err);
      alert('Колдонуучуну өчүрүү мүмкүн болгон жок');
    } finally {
      setActionLoading(false);
    }
  };

  const openPasswordModal = (user: User) => {
    setPasswordTarget(user);
    setNewPassword('');
    setPasswordConfirm('');
    setPasswordModalOpen(true);
  };

  const closePasswordModal = () => {
    if (actionLoading) return;
    setPasswordModalOpen(false);
    setPasswordTarget(null);
    setNewPassword('');
    setPasswordConfirm('');
  };

  const submitPasswordChange = async () => {
    if (!passwordTarget) return;
    
    if (!newPassword.trim()) {
      alert('Жаңы пароль толтурулушу керек');
      return;
    }

    if (newPassword !== passwordConfirm) {
      alert('Парольдар өзөрө дал келбейт');
      return;
    }

    if (newPassword.length < 6) {
      alert('Пароль жок дегенде 6 символ болушу керек');
      return;
    }

    setActionLoading(true);
    try {
      await userService.changeUserPassword(passwordTarget.id, newPassword);
      alert('Пароль табышталды');
      closePasswordModal();
    } catch (err) {
      console.error('Failed to change password:', err);
      alert('Парольни өзгөртүү мүмкүн болгон жок');
    } finally {
      setActionLoading(false);
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

  return (
    <div className="users-page">
      <div className="page-header">
        <h1>Колдонуучулар</h1>
        <p className="subtitle">Колдонуучуларды башкаруу жана модерация</p>
      </div>

      <div className="filters-bar">
        <div className="search-box">
          <Search size={20} />
          <input
            type="text"
            placeholder="Телефон, аты же ID боюнча издөө..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>

        <div className="role-filters">
          <button
            className={`role-filter ${roleFilter === 'all' ? 'active' : ''}`}
            onClick={() => setRoleFilter('all')}
          >
            Баары ({users.length})
          </button>
          <button
            className={`role-filter ${roleFilter === 'user' ? 'active' : ''}`}
            onClick={() => setRoleFilter('user')}
          >
            Колдонуучулар ({users.filter(u => u.role === 'user').length})
          </button>
          <button
            className={`role-filter ${roleFilter === 'courier' ? 'active' : ''}`}
            onClick={() => setRoleFilter('courier')}
          >
            Курьерлер ({users.filter(u => u.role === 'courier').length})
          </button>
          <button
            className={`role-filter ${roleFilter === 'admin' ? 'active' : ''}`}
            onClick={() => setRoleFilter('admin')}
          >
            Админдер ({users.filter(u => u.role === 'admin').length})
          </button>
          <button
            className={`role-filter ${onlineOnly ? 'active' : ''}`}
            onClick={() => setOnlineOnly((v) => !v)}
          >
            Онлайн гана ({users.filter(u => u.role === 'courier' && u.is_online).length})
          </button>
        </div>
      </div>

      <div className="users-table-container">
        <table className="users-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Жеке номер</th>
              <th>Телефон</th>
              <th>Аты</th>
              <th>Роль</th>
              <th>Баланс</th>
              <th>Рейтинг</th>
              <th>Заказдар</th>
              <th>Статус</th>
              <th>Аракеттер</th>
            </tr>
          </thead>
          <tbody>
            {paginatedUsers.map((user) => (
              <tr
                key={user.id}
                onClick={() => openUserDetails(user)}
                style={{ cursor: 'pointer' }}
                title="Кеңири маалымат үчүн басыңыз"
              >
                <td className="user-id">#{user.id}</td>
                <td>{user.unique_id || '-'}</td>
                <td>{user.phone}</td>
                <td>{user.name || '-'}</td>
                <td>
                  <span className={`role-badge role-${user.role}`}>
                    {user.role === 'admin' ? 'Админ' : user.role === 'courier' ? 'Курьер' : 'Колдонуучу'}
                  </span>
                </td>
                <td className="balance-cell">{user.balance} сом</td>
                <td>
                  {typeof user.average_rating === 'number' ? (
                    <span className="rating">⭐ {user.average_rating.toFixed(1)}</span>
                  ) : (
                    '-'
                  )}
                </td>
                <td>{user.total_orders ?? 0}</td>
                <td>
                  {user.is_active ? (
                    <span className="status-active">
                      <CheckCircle size={16} /> Активдүү
                    </span>
                  ) : (
                    <span className="status-inactive">
                      <XCircle size={16} /> Блоктолгон
                    </span>
                  )}
                </td>
                <td>
                  <div className="action-buttons">
                    {user.is_active ? (
                      <button
                        className="action-button block-button"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleBlockUser(user.id);
                        }}
                        disabled={actionLoading || user.role === 'admin'}
                        title="Блоктоо"
                      >
                        <Ban size={16} />
                      </button>
                    ) : (
                      <button
                        className="action-button unblock-button"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleUnblockUser(user.id);
                        }}
                        disabled={actionLoading}
                        title="Анблоктоо"
                      >
                        <CheckCircle size={16} />
                      </button>
                    )}

                    <button
                      className="action-button edit-button"
                      onClick={(e) => {
                        e.stopPropagation();
                        openEditModal(user);
                      }}
                      disabled={actionLoading}
                      title="Маалыматын өзгөртүү"
                    >
                      <Pencil size={16} />
                    </button>

                    <button
                      className="action-button role-button"
                      onClick={(e) => {
                        e.stopPropagation();
                        openEditModal(user);
                      }}
                      disabled={actionLoading}
                      title="Ролун өзгөртүү"
                    >
                      <UserCog size={16} />
                    </button>

                    <button
                      className="action-button password-button"
                      onClick={(e) => {
                        e.stopPropagation();
                        openPasswordModal(user);
                      }}
                      disabled={actionLoading}
                      title="Парольду өзгөртүү"
                    >
                      <Lock size={16} />
                    </button>

                    <button
                      className="action-button delete-button"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDeleteUser(user);
                      }}
                      disabled={actionLoading || user.role === 'admin'}
                      title="Базадан өчүрүү"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {filteredUsers.length === 0 && (
          <div className="empty-state">
            <p>Колдонуучулар табылган жок</p>
          </div>
        )}
      </div>

      {filteredUsers.length > 0 && (
        <div className="table-pagination-wrap">
          <p className="table-pagination-label">Навигация</p>
          <div className="table-pagination">
            <button
              className="page-btn"
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={currentPage === 1}
            >
              Артка
            </button>
            <span className="page-indicator">
              Бет {currentPage} / {totalPages}
            </span>
            <button
              className="page-btn"
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              disabled={currentPage === totalPages}
            >
              Алга
            </button>
          </div>
        </div>
      )}

      {(detailLoading || selectedUser) && (
        <div className="user-detail-overlay" onClick={() => setSelectedUser(null)}>
          <div className="user-detail-drawer" onClick={(e) => e.stopPropagation()}>
            <div className="user-detail-header">
              <h3>{detailLoading ? 'Жүктөлүүдө...' : `Курьер: ${selectedUser?.name || selectedUser?.phone}`}</h3>
              <button className="close-detail" onClick={() => setSelectedUser(null)}>×</button>
            </div>

            {!detailLoading && selectedUser && (
              <div className="user-detail-content">
                <p><strong>Жеке номер:</strong> {selectedUser.unique_id || '-'}</p>
                <p><strong>Телефон:</strong> {selectedUser.phone}</p>
                <p><strong>Статус:</strong> {selectedUser.is_online ? 'Онлайн' : 'Офлайн'}</p>
                <p><strong>Рейтинг:</strong> {selectedUser.average_rating ? selectedUser.average_rating.toFixed(2) : '-'}</p>
                <p><strong>Жалпы заказ:</strong> {selectedUser.total_orders ?? 0}</p>
                <p><strong>Аяктаган заказ:</strong> {selectedUser.completed_orders ?? 0}</p>
                <p><strong>Баланс:</strong> {selectedUser.balance} сом</p>

                <div className="detail-section">
                  <h4>Акыркы заказдар</h4>
                  {selectedUser.recent_orders && selectedUser.recent_orders.length > 0 ? (
                    <div className="mini-list">
                      {selectedUser.recent_orders.map((order) => (
                        <div key={order.id} className="mini-item">
                          <div>#{order.id} • {order.status}</div>
                          <div>{order.price} сом</div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="muted">Заказ жок</p>
                  )}
                </div>

                <div className="detail-section">
                  <h4>Акыркы рейтингдер</h4>
                  {selectedUser.recent_ratings && selectedUser.recent_ratings.length > 0 ? (
                    <div className="mini-list">
                      {selectedUser.recent_ratings.map((rating, idx) => (
                        <div key={`${rating.order_id}-${idx}`} className="mini-item">
                          <div>Order #{rating.order_id} • ⭐ {rating.rating}</div>
                          <div className="muted">{rating.comment || 'Комментарий жок'}</div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="muted">Рейтинг жок</p>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {editModalOpen && editTarget && (
        <div className="edit-user-modal-overlay" onClick={closeEditModal}>
          <div className="edit-user-modal" onClick={(e) => e.stopPropagation()}>
            <div className="edit-user-header">
              <h3>Колдонуучуну өзгөртүү #{editTarget.id}</h3>
              <button className="close-detail" onClick={closeEditModal}>×</button>
            </div>

            <div className="edit-user-form">
              <label>
                <span>Аты</span>
                <input
                  type="text"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  placeholder="Атын киргизиңиз"
                />
              </label>

              <label>
                <span>Телефон</span>
                <input
                  type="text"
                  value={editPhone}
                  onChange={(e) => setEditPhone(e.target.value)}
                  placeholder="+996..."
                />
              </label>

              <label>
                <span>Роль</span>
                <select
                  value={editRole}
                  onChange={(e) => setEditRole(e.target.value as 'user' | 'courier' | 'admin')}
                >
                  <option value="user">Колдонуучу</option>
                  <option value="courier">Курьер</option>
                  <option value="admin">Админ</option>
                </select>
              </label>
            </div>

            <div className="edit-user-actions">
              <button className="cancel-edit-btn" onClick={closeEditModal} disabled={actionLoading}>
                Жабуу
              </button>
              <button className="save-edit-btn" onClick={submitEditUser} disabled={actionLoading}>
                {actionLoading ? 'Сакталууда...' : 'Сактоо'}
              </button>
            </div>
          </div>
        </div>
      )}

      {passwordModalOpen && passwordTarget && (
        <div className="password-modal-overlay" onClick={closePasswordModal}>
          <div className="password-modal" onClick={(e) => e.stopPropagation()}>
            <div className="password-modal-header">
              <h3>Парольду өзгөртүү: {passwordTarget.phone}</h3>
              <button className="close-modal" onClick={closePasswordModal}>×</button>
            </div>

            <div className="password-modal-form">
              <label>
                <span>Жаңы пароль</span>
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Жаңы парольду киргизиңиз"
                />
              </label>

              <label>
                <span>Парольду баталоо</span>
                <input
                  type="password"
                  value={passwordConfirm}
                  onChange={(e) => setPasswordConfirm(e.target.value)}
                  placeholder="Парольду кайта киргизиңиз"
                />
              </label>
            </div>

            <div className="password-modal-actions">
              <button className="cancel-btn" onClick={closePasswordModal} disabled={actionLoading}>
                Жабуу
              </button>
              <button className="confirm-btn" onClick={submitPasswordChange} disabled={actionLoading}>
                {actionLoading ? 'Өзгөртүүдө...' : 'Парольду өзгөртүү'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
