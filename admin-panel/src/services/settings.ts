import api from './api';

export interface SettingItem {
  value: string;
  description: string;
}

export const SETTING_KEYS = {
  COURIER_FEE: 'courier_service_fee',
  USER_FEE: 'user_service_fee',
  DELIVERY_BASE: 'delivery_base_price',
  DELIVERY_PER_KM: 'delivery_price_per_km',
} as const;

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
