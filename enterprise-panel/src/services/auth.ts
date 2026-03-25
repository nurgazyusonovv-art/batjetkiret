import api from './api';

export interface EnterpriseInfo {
  enterprise_id: number;
  enterprise_name: string;
  category: string;
  user_id: number;
  phone: string;
}

export const authService = {
  async login(phone: string, password: string): Promise<EnterpriseInfo> {
    const res = await api.post('/enterprise-portal/login', { phone, password });
    const { access_token, enterprise } = res.data;
    localStorage.setItem('enterprise_token', access_token);
    localStorage.setItem('enterprise_info', JSON.stringify(enterprise));
    return enterprise;
  },

  logout() {
    localStorage.removeItem('enterprise_token');
    localStorage.removeItem('enterprise_info');
  },

  getInfo(): EnterpriseInfo | null {
    const raw = localStorage.getItem('enterprise_info');
    if (!raw) return null;
    try { return JSON.parse(raw); } catch { return null; }
  },

  isLoggedIn(): boolean {
    return !!localStorage.getItem('enterprise_token');
  },
};
