import api from './api';
import { TopupRequest, SystemStats, RevenueByDate, PaymentStats } from '@/types';

interface BackendPendingTopup {
  id: number;
  amount?: number;
  requested_amount?: number;
  unique_id?: string;
  screenshot_file_id?: string;
  screenshot_hash?: string;
  status?: string;
  admin_note?: string | null;
  approved_at?: string | null;
  created_at: string;
  user_phone?: string;
  user_name?: string;
  user_id?: number;
}

function mapTopup(item: BackendPendingTopup): TopupRequest {
  return {
    id: item.id,
    user_id: item.user_id ?? 0,
    unique_id: item.unique_id,
    requested_amount: item.requested_amount ?? item.amount ?? 0,
    screenshot_hash: item.screenshot_hash ?? item.screenshot_file_id ?? '',
    screenshot_file_id: item.screenshot_file_id,
    status: ((item.status ?? 'PENDING').toLowerCase() as TopupRequest['status']),
    created_at: item.created_at,
    approved_at: item.approved_at ?? null,
    admin_comment: item.admin_note ?? null,
    user: item.user_phone
      ? {
          id: item.user_id ?? 0,
          phone: item.user_phone,
          name: item.user_name ?? 'Колдонуучу',
          role: 'user',
          is_active: true,
          is_courier: false,
          balance: 0,
          created_at: item.created_at,
        }
      : undefined,
  };
}

export const topupService = {
  async getPendingTopups(): Promise<TopupRequest[]> {
    const response = await api.get<BackendPendingTopup[]>('/admin/topup-requests/pending');
    return response.data.map(mapTopup);
  },

  async getTopupHistory(): Promise<TopupRequest[]> {
    const response = await api.get<BackendPendingTopup[]>('/admin/topup-requests/history');
    return response.data.map(mapTopup);
  },

  async fetchScreenshotUrl(topupId: number): Promise<string> {
    const response = await api.get<{ file_url?: string }>(`/admin/topup-requests/${topupId}/screenshot`);
    if (!response.data?.file_url) {
      throw new Error('Screenshot URL табылган жок');
    }
    return response.data.file_url;
  },

  async approveTopup(topupId: number): Promise<void> {
    await api.post(`/admin/topup-requests/${topupId}/approve`);
  },

  async rejectTopup(topupId: number, comment: string): Promise<void> {
    await api.post(`/admin/topup-requests/${topupId}/reject`, null, {
      params: { admin_note: comment },
    });
  },
};

export const statsService = {
  async getSystemStats(): Promise<SystemStats> {
    const response = await api.get<Partial<SystemStats>>('/admin/stats');
    return {
      total_orders: response.data.total_orders ?? 0,
      waiting_orders: response.data.waiting_orders ?? 0,
      active_orders: response.data.active_orders ?? response.data.waiting_orders ?? 0,
      completed_orders: response.data.completed_orders ?? 0,
      total_revenue: response.data.total_revenue ?? 0,
      total_users: response.data.total_users ?? 0,
      total_couriers: response.data.total_couriers ?? 0,
      online_couriers: response.data.online_couriers ?? 0,
      pending_topups: response.data.pending_topups ?? 0,
      approved_topups_count: response.data.approved_topups_count ?? 0,
      rejected_topups_count: response.data.rejected_topups_count ?? 0,
      approved_topups_amount: response.data.approved_topups_amount ?? 0,
      rejected_topups_amount: response.data.rejected_topups_amount ?? 0,
      pending_topups_amount: response.data.pending_topups_amount ?? 0,
      // Today's metrics
      total_orders_today: response.data.total_orders_today ?? 0,
      canceled_orders_today: response.data.canceled_orders_today ?? 0,
      delivered_orders_today: response.data.delivered_orders_today ?? 0,
      revenue_today: response.data.revenue_today ?? 0,
    };
  },

  async getDateStats(date: string): Promise<SystemStats> {
    const response = await api.get<Partial<SystemStats>>(`/admin/stats/${date}`);
    return {
      total_orders: response.data.total_orders ?? 0,
      waiting_orders: response.data.waiting_orders ?? 0,
      active_orders: response.data.active_orders ?? response.data.waiting_orders ?? 0,
      completed_orders: response.data.completed_orders ?? 0,
      total_revenue: response.data.total_revenue ?? 0,
      total_users: response.data.total_users ?? 0,
      total_couriers: response.data.total_couriers ?? 0,
      online_couriers: response.data.online_couriers ?? 0,
      pending_topups: response.data.pending_topups ?? 0,
      approved_topups_count: response.data.approved_topups_count ?? 0,
      rejected_topups_count: response.data.rejected_topups_count ?? 0,
      approved_topups_amount: response.data.approved_topups_amount ?? 0,
      rejected_topups_amount: response.data.rejected_topups_amount ?? 0,
      pending_topups_amount: response.data.pending_topups_amount ?? 0,
      // Date-specific metrics
      total_orders_today: response.data.total_orders_today ?? 0,
      canceled_orders_today: response.data.canceled_orders_today ?? 0,
      delivered_orders_today: response.data.delivered_orders_today ?? 0,
      revenue_today: response.data.revenue_today ?? 0,
    };
  },

  async getRevenueByDate(days: number = 30): Promise<RevenueByDate[]> {
    const response = await api.get<{ date: string; revenue: number; orders: number }[]>(
      '/admin/revenue-trend',
      { params: { days } }
    );
    return response.data;
  },

  async getPaymentStats(range: string = 'all'): Promise<PaymentStats> {
    const response = await api.get<Partial<PaymentStats>>('/admin/topup-stats', {
      params: { range },
    });
    return {
      approved_topups_count: response.data.approved_topups_count ?? 0,
      rejected_topups_count: response.data.rejected_topups_count ?? 0,
      pending_topups_count: response.data.pending_topups_count ?? 0,
      approved_topups_amount: response.data.approved_topups_amount ?? 0,
      rejected_topups_amount: response.data.rejected_topups_amount ?? 0,
      pending_topups_amount: response.data.pending_topups_amount ?? 0,
    };
  },
};
