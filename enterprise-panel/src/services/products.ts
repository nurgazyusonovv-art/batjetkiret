import api from './api';

export interface Category {
  id: number;
  name: string;
  sort_order: number;
  is_active: boolean;
  created_at: string;
}

export interface Product {
  id: number;
  name: string;
  description?: string | null;
  price: number;
  is_active: boolean;
  sort_order: number;
  category_id?: number | null;
  category_name?: string | null;
  image_url?: string | null;
  created_at: string;
}

export const productsService = {
  async getCategories(): Promise<Category[]> {
    const res = await api.get('/enterprise-portal/categories');
    return res.data;
  },
  async createCategory(name: string, sort_order = 0): Promise<Category> {
    const res = await api.post('/enterprise-portal/categories', { name, sort_order });
    return res.data;
  },
  async updateCategory(id: number, data: Partial<{ name: string; sort_order: number; is_active: boolean }>): Promise<Category> {
    const res = await api.put(`/enterprise-portal/categories/${id}`, data);
    return res.data;
  },
  async deleteCategory(id: number): Promise<void> {
    await api.delete(`/enterprise-portal/categories/${id}`);
  },

  async getProducts(category_id?: number, active_only = false): Promise<Product[]> {
    const res = await api.get('/enterprise-portal/products', { params: { category_id, active_only } });
    return res.data;
  },
  async createProduct(data: { name: string; price: number; description?: string; category_id?: number; sort_order?: number }): Promise<Product> {
    const res = await api.post('/enterprise-portal/products', data);
    return res.data;
  },
  async updateProduct(id: number, data: Partial<{ name: string; price: number; description: string; category_id: number; sort_order: number; is_active: boolean }>): Promise<Product> {
    const res = await api.put(`/enterprise-portal/products/${id}`, data);
    return res.data;
  },
  async deleteProduct(id: number): Promise<void> {
    await api.delete(`/enterprise-portal/products/${id}`);
  },

  async uploadProductImage(id: number, file: File): Promise<{ image_url: string }> {
    const form = new FormData();
    form.append('file', file);
    const res = await api.post(`/enterprise-portal/products/${id}/image`, form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return res.data;
  },
};
