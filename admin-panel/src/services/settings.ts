import api from './api';

export interface SettingItem {
  value: string;
  description: string;
}

export const SETTING_KEYS = {
  COURIER_FEE: 'courier_service_fee',
  USER_FEE: 'user_service_fee',
  COURIER_CANCEL_PENALTY: 'courier_cancel_penalty',
  DELIVERY_BASE: 'delivery_base_price',
  DELIVERY_PER_KM: 'delivery_price_per_km',
  DELIVERY_EXTRA_AFTER_KM: 'delivery_extra_after_km',
  DELIVERY_EXTRA_PER_KM: 'delivery_extra_price_per_km',
  TAXI_BASE: 'taxi_base_price',
  TAXI_PER_KM: 'taxi_price_per_km',
  TAXI_EXTRA_AFTER_KM: 'taxi_extra_after_km',
  TAXI_EXTRA_PER_KM: 'taxi_extra_price_per_km',
  ANDROID_LATEST_VERSION_CODE: 'android_latest_version_code',
  ANDROID_UPDATE_REQUIRED: 'android_update_required',
  PLAY_MARKET_URL: 'play_market_url',
  RATING_DIALOG_ENABLED: 'rating_dialog_enabled',
  RATING_PROMPT_MIN_LAUNCHES: 'rating_prompt_min_launches',
  RATING_PROMPT_COOLDOWN_DAYS: 'rating_prompt_cooldown_days',
  ADVERTISEMENT_PRICE: 'advertisement_price',
  ADVERTISEMENT_DEFAULT_DURATION_DAYS: 'advertisement_default_duration_days',
  CONTACT_TELEGRAM: 'contact_telegram',
  CONTACT_WHATSAPP: 'contact_whatsapp',
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
