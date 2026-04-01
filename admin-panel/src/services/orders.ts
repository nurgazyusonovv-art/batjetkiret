import api from './api';
import { Order, OrderFilters, PaginationParams } from '@/types';

interface BackendOrderStatusAudit {
  actor_user_id: number | null;
  from_status: string | null;
  to_status: string;
  at: string;
}

interface BackendAdminOrder {
  id: number;
  user_id: number;
  user_phone?: string | null;
  courier_id: number | null;
  courier_phone?: string | null;
  category?: string;
  description?: string;
  from_address?: string;
  to_address?: string;
  distance_km?: number;
  price: number;
  status: Order['status'];
  verification_code?: string | null;
  hidden_for_user?: boolean;
  hidden_for_courier?: boolean;
  admin_note?: string | null;
  created_at: string;
  status_audit?: BackendOrderStatusAudit[];
}

function mapOrder(item: BackendAdminOrder): Order {
  return {
    id: item.id,
    pickup_location: item.from_address ?? '-',
    delivery_location: item.to_address ?? '-',
    pickup_lat: 0,
    pickup_lon: 0,
    delivery_lat: 0,
    delivery_lon: 0,
    distance_km: item.distance_km ?? 0,
    estimated_price: item.price,
    status: item.status,
    user_id: item.user_id,
    user_phone: item.user_phone,
    courier_id: item.courier_id,
    courier_phone: item.courier_phone,
    created_at: item.created_at,
    updated_at: item.created_at,
    category: item.category,
    description: item.description,
    verification_code: item.verification_code,
    hidden_for_user: item.hidden_for_user,
    hidden_for_courier: item.hidden_for_courier,
    admin_note: item.admin_note,
    status_audit: item.status_audit,
  };
}

export const orderService = {
  async getOrders(params?: OrderFilters & PaginationParams): Promise<Order[]> {
    const response = await api.get<BackendAdminOrder[]>('/admin/orders', { params });
    return response.data.map(mapOrder);
  },

  async getOrderById(orderId: number): Promise<Order> {
    const response = await api.get<BackendAdminOrder>(`/admin/orders/${orderId}`);
    return mapOrder(response.data);
  },

  async cancelOrder(orderId: number, reason: string): Promise<Order> {
    await api.post(`/admin/orders/${orderId}/force-cancel`, null, {
      params: {
        note: reason,
      },
    });
    return this.getOrderById(orderId);
  },

  async reassignCourier(orderId: number, courierId: number): Promise<Order> {
    await api.post(
      `/admin/orders/${orderId}/reassign-courier`,
      null,
      {
        params: {
          new_courier_id: courierId,
        },
      }
    );
    return this.getOrderById(orderId);
  },

  async forceStatus(orderId: number, status: string, note?: string): Promise<Order> {
    await api.post(
      `/admin/orders/${orderId}/force-status`,
      null,
      {
        params: {
          new_status: status,
          note,
        },
      }
    );
    return this.getOrderById(orderId);
  },

  async deleteOrder(orderId: number): Promise<{ message: string; order_id: number }> {
    const response = await api.delete<{ message: string; order_id: number }>(`/admin/orders/${orderId}`);
    return response.data;
  },

  async clearAllOrders(): Promise<{ message: string }> {
    const response = await api.delete<{ message: string }>('/admin/orders/clear-all');
    return response.data;
  },
};
