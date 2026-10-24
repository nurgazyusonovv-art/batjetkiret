import api from './api';

export type CampaignStatus =
  | 'pending_review'
  | 'scheduled'
  | 'sending'
  | 'sent'
  | 'cancelled'
  | 'failed'
  | 'rejected';

export interface PromoCampaign {
  id: number;
  title: string;
  message: string;
  image_url?: string | null;
  product_id?: number | null;
  product_name?: string | null;
  status: CampaignStatus;
  review_note?: string | null;
  sent_count: number;
  created_at: string | null;
  sent_at?: string | null;
}

export interface PromoCampaignList {
  campaigns: PromoCampaign[];
  /** UTC instant the next submission is allowed, or null when allowed now. */
  next_allowed_at: string | null;
}

export const campaignsService = {
  async list(): Promise<PromoCampaignList> {
    const res = await api.get('/enterprise-portal/campaigns');
    return res.data;
  },
  async submit(data: {
    title: string;
    message: string;
    image_url?: string | null;
    product_id?: number | null;
  }): Promise<PromoCampaign> {
    const res = await api.post('/enterprise-portal/campaigns', data);
    return res.data;
  },
  async cancel(id: number): Promise<void> {
    await api.post(`/enterprise-portal/campaigns/${id}/cancel`);
  },
  /** FCM needs a public HTTPS picture, so it is uploaded before submitting. */
  async uploadImage(file: File): Promise<string> {
    const form = new FormData();
    form.append('file', file);
    const res = await api.post('/enterprise-portal/notifications/image', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return res.data.url;
  },
};
