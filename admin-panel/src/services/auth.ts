import api from './api';
import { AuthResponse, LoginCredentials, User } from '@/types';

export const authService = {
  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    const response = await api.post<AuthResponse>('/auth/login', {
      phone: credentials.phone,
      password: credentials.password,
    });

    // Check if user is admin
    if (response.data.user.role !== 'admin') {
      throw new Error('Access denied. Admin privileges required.');
    }

    // Store token and user info
    localStorage.setItem('admin_token', response.data.access_token);
    localStorage.setItem('admin_user', JSON.stringify(response.data.user));

    return response.data;
  },

  async getCurrentUser(): Promise<User> {
    const response = await api.get<User>('/users/me');
    return response.data;
  },

  logout() {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
  },

  isAuthenticated(): boolean {
    const token = localStorage.getItem('admin_token');
    if (!token) return false;

    // If user payload is corrupted, force re-login instead of crashing layout.
    return this.getStoredUser() !== null;
  },

  getStoredUser(): User | null {
    const userStr = localStorage.getItem('admin_user');
    if (!userStr) return null;

    try {
      return JSON.parse(userStr) as User;
    } catch {
      localStorage.removeItem('admin_user');
      localStorage.removeItem('admin_token');
      return null;
    }
  },
};
