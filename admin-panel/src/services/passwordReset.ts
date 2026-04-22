import api from '@/services/api';
import { PasswordResetRequest } from '@/types';

export interface GeneratedCode {
  code: string;
  user: { id: number; unique_id: string | null; phone: string; name: string };
}

export const passwordResetService = {
  async generate(phoneOrId: string): Promise<GeneratedCode> {
    const isId = phoneOrId.toUpperCase().startsWith('BJ');
    const params = isId ? { unique_id: phoneOrId } : { phone: phoneOrId };
    const res = await api.post<GeneratedCode>('/admin/password-reset-requests/generate', null, { params });
    return res.data;
  },

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
