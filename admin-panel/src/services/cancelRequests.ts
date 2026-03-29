import api from './api';

export interface CancelRequest {
  id: number;
  status: string;
  cancel_request_reason: string | null;
  user_phone: string | null;
  user_name: string | null;
  courier_phone: string | null;
  courier_name: string | null;
  from_address: string;
  to_address: string;
  price: number;
  created_at: string;
}

export const cancelRequestsService = {
  async list(): Promise<CancelRequest[]> {
    const res = await api.get('/admin/cancel-requests');
    return res.data;
  },

  async count(): Promise<number> {
    const res = await api.get('/admin/cancel-requests/count');
    return res.data.count;
  },

  async approve(orderId: number, adminNote = ''): Promise<void> {
    await api.post(`/admin/cancel-requests/${orderId}/approve`, { admin_note: adminNote });
  },

  async reject(orderId: number, adminNote = ''): Promise<void> {
    await api.post(`/admin/cancel-requests/${orderId}/reject`, { admin_note: adminNote });
  },
};
