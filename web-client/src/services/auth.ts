import api from './api';

export interface User {
  id: number;
  name: string;
  phone: string;
  balance: number;
  unique_id: string;
  is_courier: boolean;
  is_admin: boolean;
  is_online?: boolean;
  address?: string;
}

export const authService = {
  async login(phone: string, password: string): Promise<{ token: string; user: User }> {
    const res = await api.post('/auth/login', { phone, password });
    const { access_token } = res.data;
    localStorage.setItem('token', access_token);
    const user = await authService.getMe();
    localStorage.setItem('user', JSON.stringify(user));
    return { token: access_token, user };
  },

  async register(phone: string, password: string, name: string): Promise<{ token: string; user: User }> {
    const res = await api.post('/auth/register', { phone, password, name });
    const { access_token } = res.data;
    localStorage.setItem('token', access_token);
    const user = await authService.getMe();
    localStorage.setItem('user', JSON.stringify(user));
    return { token: access_token, user };
  },

  async getMe(): Promise<User> {
    const res = await api.get('/users/me');
    return res.data;
  },

  logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  },

  getToken(): string | null {
    return localStorage.getItem('token');
  },

  getCachedUser(): User | null {
    const raw = localStorage.getItem('user');
    if (!raw) return null;
    try { return JSON.parse(raw); } catch { return null; }
  },

  isLoggedIn(): boolean {
    return !!localStorage.getItem('token');
  },
};
