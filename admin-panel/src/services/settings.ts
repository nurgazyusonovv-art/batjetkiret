import api from './api';

export interface SettingItem {
  value: string;
  description: string;
}

export const settingsService = {
  async getSettings(): Promise<Record<string, SettingItem>> {
    const res = await api.get('/admin/settings');
    return res.data;
  },

  async updateSetting(key: string, value: string): Promise<void> {
    await api.put(`/admin/settings/${key}`, { value });
  },

  async topupUserBalance(userId: number, amount: number, note: string): Promise<{ balance: number; added: number }> {
    const res = await api.post(`/admin/users/${userId}/topup`, { amount, note });
    return res.data;
  },
};
