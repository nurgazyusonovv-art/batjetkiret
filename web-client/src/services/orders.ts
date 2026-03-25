import api from './api';

export interface Order {
  id: number;
  category: string;
  description: string;
  from_address: string;
  to_address: string;
  from_latitude?: number;
  from_longitude?: number;
  to_latitude?: number;
  to_longitude?: number;
  distance_km: number;
  price: number;
  status: string;
  created_at: string;
  enterprise_id?: number;
  enterprise_name?: string;
  courier_name?: string;
  courier_phone?: string;
  verification_code?: string;
}

export interface CreateOrderData {
  category: string;
  description: string;
  from_address: string;
  to_address: string;
  from_latitude?: number;
  from_longitude?: number;
  to_latitude?: number;
  to_longitude?: number;
  distance_km: number;
  enterprise_id?: number;
}

export const STATUS_LABELS: Record<string, string> = {
  WAITING_COURIER: 'Курьер күтүүдө',
  COURIER_ASSIGNED: 'Курьер дайындалды',
  COURIER_ARRIVED: 'Курьер жетти',
  IN_PROGRESS: 'Жолдо',
  DELIVERED: 'Жеткирилди',
  COMPLETED: 'Аяктады',
  CANCELLED: 'Жокко чыгарылды',
  READY_FOR_PICKUP: 'Даяр, алып кетүү керек',
};

export const STATUS_COLORS: Record<string, string> = {
  WAITING_COURIER: '#f59e0b',
  COURIER_ASSIGNED: '#3b82f6',
  COURIER_ARRIVED: '#8b5cf6',
  IN_PROGRESS: '#f97316',
  DELIVERED: '#10b981',
  COMPLETED: '#22c55e',
  CANCELLED: '#ef4444',
  READY_FOR_PICKUP: '#06b6d4',
};

export const ordersService = {
  async createOrder(data: CreateOrderData): Promise<Order> {
    const res = await api.post('/orders/', data);
    return res.data;
  },

  async getMyOrders(): Promise<Order[]> {
    const res = await api.get('/orders/my');
    return res.data;
  },

  async getOrder(id: number): Promise<Order> {
    const res = await api.get(`/orders/${id}`);
    return res.data;
  },

  async cancelOrder(id: number): Promise<void> {
    await api.post(`/orders/${id}/cancel`);
  },

  async updateOrder(id: number, data: Partial<Pick<Order,
    'description' | 'from_address' | 'to_address' |
    'from_latitude' | 'from_longitude' | 'to_latitude' | 'to_longitude' | 'distance_km'
  >>): Promise<{ price?: number }> {
    const res = await api.patch(`/orders/${id}`, data);
    return res.data;
  },

  async deleteOrder(id: number): Promise<void> {
    await api.delete(`/orders/${id}`);
  },

  async deleteAllMyOrders(): Promise<void> {
    await api.delete('/orders/my/all');
  },
};
