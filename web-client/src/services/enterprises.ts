import api from './api';

export interface Enterprise {
  id: number;
  name: string;
  category: string;
  address?: string;
  phone?: string;
  description?: string;
  lat?: number;
  lon?: number;
}

export interface EnterpriseProduct {
  id: number;
  name: string;
  price: number;
  description?: string;
}

export interface EnterpriseMenuCategory {
  id: number;
  name: string;
  products: EnterpriseProduct[];
}

export interface EnterpriseMenu {
  enterprise: Enterprise;
  menu: EnterpriseMenuCategory[];
}

export const enterprisesService = {
  async getActive(): Promise<Enterprise[]> {
    const res = await api.get('/enterprises/active');
    return res.data;
  },

  async getMenu(enterpriseId: number): Promise<EnterpriseMenu> {
    const res = await api.get(`/enterprises/${enterpriseId}/menu`);
    return res.data;
  },
};
