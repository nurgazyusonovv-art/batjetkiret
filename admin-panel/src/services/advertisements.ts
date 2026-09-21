import api from './api';
import { Advertisement } from '@/types';

export const advertisementsService = {
  async list(status?: string): Promise<Advertisement[]> {
    const res = await api.get('/admin/advertisements', {
      params: status ? { status } : undefined,
    });
    return res.data;
  },

  async approve(id: number): Promise<Advertisement> {
    const res = await api.post(`/admin/advertisements/${id}/approve`);
    return res.data;
  },

  async reject(id: number, reason: string): Promise<Advertisement> {
    const res = await api.post(`/admin/advertisements/${id}/reject`, { reason });
    return res.data;
  },
};
