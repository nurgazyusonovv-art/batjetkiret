import api from '@/services/api';
import { PasswordResetRequest } from '@/types';

export const passwordResetService = {
  async list(): Promise<PasswordResetRequest[]> {
    const res = await api.get<PasswordResetRequest[]>('/admin/password-reset-requests');
    return res.data;
  },

  async count(): Promise<number> {
    const res = await api.get<{ count: number }>('/admin/password-reset-requests/count');
    return res.data.count;
  },

  async dismiss(resetId: number): Promise<void> {
    await api.post(`/admin/password-reset-requests/${resetId}/dismiss`);
  },
};
