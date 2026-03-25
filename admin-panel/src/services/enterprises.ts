import api from './api';
import { Enterprise, EnterpriseCreate, EnterpriseUpdate } from '@/types';

export interface EnterpriseCredentials {
  has_credentials: boolean;
  user_id?: number;
  phone?: string;
  name?: string;
  is_active?: boolean;
}

export const enterprisesService = {
  async list(params?: { is_active?: boolean; category?: string; skip?: number; limit?: number }): Promise<Enterprise[]> {
    const response = await api.get<Enterprise[]>('/enterprises/admin/list', { params });
    return response.data;
  },

  async create(data: EnterpriseCreate): Promise<Enterprise> {
    const response = await api.post<Enterprise>('/enterprises/register', {
      name: data.name,
      category: data.category,
      phone: data.phone,
      address: data.address,
      description: data.description,
      lat: data.lat,
      lon: data.lon,
    });
    return response.data;
  },

  async update(id: number, data: EnterpriseUpdate): Promise<Enterprise> {
    const response = await api.put<Enterprise>(`/enterprises/admin/${id}`, { ...data });
    return response.data;
  },

  async activate(id: number): Promise<void> {
    await api.post(`/enterprises/admin/${id}/activate`);
  },

  async deactivate(id: number): Promise<void> {
    await api.post(`/enterprises/admin/${id}/deactivate`);
  },

  async delete(id: number): Promise<void> {
    await api.delete(`/enterprises/admin/${id}`);
  },

  async getCredentials(id: number): Promise<EnterpriseCredentials> {
    const response = await api.get<EnterpriseCredentials>(`/enterprises/admin/${id}/credentials`);
    return response.data;
  },

  async setCredentials(id: number, phone: string, password: string, name?: string): Promise<void> {
    await api.post(`/enterprises/admin/${id}/set-credentials`, { phone, password, name });
  },
};
