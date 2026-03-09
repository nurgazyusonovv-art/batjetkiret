import api from './api';
import { User, UserFilters, PaginationParams } from '@/types';

interface BackendAdminUser {
  id: number;
  unique_id?: string;
  phone: string;
  is_courier: boolean;
  is_admin: boolean;
  is_active?: boolean;
  is_online?: boolean;
  balance: number;
  name?: string;
  total_orders?: number;
  completed_orders?: number;
  average_rating?: number | null;
  recent_orders?: User['recent_orders'];
  recent_ratings?: User['recent_ratings'];
  created_at?: string;
}

interface AdminUserUpdatePayload {
  name?: string;
  phone?: string;
  role?: 'user' | 'courier' | 'admin';
  is_active?: boolean;
}

function mapUser(item: BackendAdminUser): User {
  return {
    id: item.id,
    unique_id: item.unique_id,
    phone: item.phone,
    name: item.name ?? item.phone,
    role: item.is_admin ? 'admin' : item.is_courier ? 'courier' : 'user',
    is_active: item.is_active ?? true,
    is_online: item.is_online ?? false,
    is_courier: item.is_courier,
    balance: item.balance,
    total_orders: item.total_orders,
    completed_orders: item.completed_orders,
    average_rating: item.average_rating,
    recent_orders: item.recent_orders,
    recent_ratings: item.recent_ratings,
    created_at: item.created_at ?? new Date().toISOString(),
  };
}

export const userService = {
  async getUsers(params?: UserFilters & PaginationParams): Promise<User[]> {
    const response = await api.get<BackendAdminUser[]>('/admin/users', { params });
    return response.data.map(mapUser);
  },

  async getUserById(userId: number): Promise<User> {
    const response = await api.get<BackendAdminUser>(`/admin/users/${userId}`);
    return mapUser(response.data);
  },

  async blockUser(userId: number): Promise<void> {
    await api.post(`/admin/users/${userId}/block`);
  },

  async unblockUser(userId: number): Promise<void> {
    await api.post(`/admin/users/${userId}/unblock`);
  },

  async disableCourier(userId: number): Promise<void> {
    await api.post(`/admin/users/${userId}/disable-courier`);
  },

  async promoteToAdmin(userId: number): Promise<void> {
    await api.post(`/admin/users/${userId}/make-admin`);
  },

  async adjustBalance(userId: number, amount: number, reason: string): Promise<void> {
    await api.post(`/admin/users/${userId}/balance`, null, {
      params: {
        amount,
        reason,
      },
    });
  },

  async updateUser(userId: number, payload: AdminUserUpdatePayload): Promise<User> {
    const response = await api.put<BackendAdminUser>(`/admin/users/${userId}`, payload);
    return mapUser(response.data);
  },

  async deleteUser(userId: number): Promise<void> {
    await api.delete(`/admin/users/${userId}`);
  },

  async changeUserPassword(userId: number, newPassword: string): Promise<void> {
    await api.post(`/admin/users/${userId}/change-password`, null, {
      params: { new_password: newPassword },
    });
  },
};
