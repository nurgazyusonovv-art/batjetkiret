import api from './api';

export interface EnterpriseOrder {
  id: number;
  user_phone: string;
  user_name: string;
  from_address: string;
  to_address: string;
  table_number: string | null;
  category: string;
  description: string;
  price: number;
  status: string;
  source: string;
  order_type: 'delivery' | 'dine_in';
  created_at: string;
}

export interface EnterpriseStats {
  total_orders: number;
  pending_orders: number;
  active_orders: number;
  completed_orders: number;
  cancelled_orders: number;
  total_revenue: number;
  online_orders: number;
  local_orders: number;
  online_revenue: number;
  local_revenue: number;
  products_count: number;
  categories_count: number;
  active_orders_list: EnterpriseOrder[];
}

export interface OrderItem {
  product_id: number;
  quantity: number;
}

export const ordersService = {
  async getOrders(params?: { status?: string; source?: string; skip?: number; limit?: number }): Promise<EnterpriseOrder[]> {
    const res = await api.get('/enterprise-portal/orders', { params });
    return res.data;
  },

  async getStats(): Promise<EnterpriseStats> {
    const res = await api.get('/enterprise-portal/stats');
    return res.data;
  },

  async createLocalOrder(data: {
    order_type: 'delivery' | 'dine_in';
    customer_phone?: string;
    table_number?: string;
    to_address?: string;
    to_lat?: number;
    to_lng?: number;
    items: OrderItem[];
    note?: string;
  }): Promise<EnterpriseOrder> {
    const res = await api.post('/enterprise-portal/orders/create-local', data);
    return res.data;
  },

  async updateStatus(orderId: number, status: string, note?: string): Promise<void> {
    await api.post(`/enterprise-portal/orders/${orderId}/update-status`, null, {
      params: { status, note },
    });
  },

  async getHistory(params?: { skip?: number; limit?: number }): Promise<EnterpriseOrder[]> {
    const res = await api.get('/enterprise-portal/history', { params });
    return res.data;
  },

  async deleteHistoryOrder(orderId: number): Promise<void> {
    await api.delete(`/enterprise-portal/history/${orderId}`);
  },

  async clearHistory(): Promise<{ message: string }> {
    const res = await api.delete('/enterprise-portal/history');
    return res.data;
  },

  async getReports(days: 1 | 7 | 30): Promise<ReportData> {
    const res = await api.get('/enterprise-portal/reports', { params: { days } });
    return res.data;
  },
};

export interface DailyEntry {
  date: string;
  orders: number;
  revenue: number;
  cancelled: number;
}

export interface ReportData {
  period_days: number;
  total_orders: number;
  completed_orders: number;
  cancelled_orders: number;
  active_orders: number;
  total_revenue: number;
  online_orders: number;
  local_orders: number;
  dine_in_orders: number;
  online_revenue: number;
  local_revenue: number;
  daily: DailyEntry[];
}
