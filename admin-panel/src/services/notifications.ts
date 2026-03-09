import api from './api';
import { Notification } from '@/types';

export const notificationsService = {
  async getNotifications(skip: number = 0, limit: number = 50): Promise<Notification[]> {
    const response = await api.get<Notification[]>('/admin/notifications', {
      params: { skip, limit },
    });
    return response.data;
  },

  async markAsRead(notificationId: number): Promise<void> {
    await api.post(`/admin/notifications/${notificationId}/read`);
  },

  async deleteNotification(notificationId: number): Promise<void> {
    await api.delete(`/admin/notifications/${notificationId}`);
  },

  async getUnreadCount(): Promise<number> {
    const response = await api.get<{ unread: number }>('/admin/notifications/unread-count');
    return response.data.unread;
  },
};
