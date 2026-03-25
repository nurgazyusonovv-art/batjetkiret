import api, { BASE_URL } from './api';

export interface TopupRequest {
  id: number;
  amount: number;
  approved_amount?: number;
  status: string;
  screenshot_url?: string;
  created_at: string;
  admin_note?: string;
}

export const topupService = {
  async uploadScreenshot(file: File): Promise<string> {
    const token = localStorage.getItem('token');
    const formData = new FormData();
    formData.append('file', file);
    const res = await fetch(`${BASE_URL}/topup/upload-screenshot`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: formData,
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.detail || 'Жүктөө катасы');
    }
    const data = await res.json();
    return data.url as string;
  },

  async requestTopup(amount: number, screenshotUrl: string): Promise<TopupRequest> {
    const res = await api.post('/topup/request', { amount, screenshot_url: screenshotUrl });
    return res.data;
  },

  async getMyRequests(): Promise<TopupRequest[]> {
    const res = await api.get('/topup/my');
    return res.data;
  },
};
