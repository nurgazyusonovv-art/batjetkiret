// User & Auth Types
export interface User {
  id: number;
  unique_id?: string;
  phone: string;
  name: string;
  role: 'user' | 'courier' | 'admin';
  is_active: boolean;
  is_online?: boolean;
  is_courier: boolean;
  balance: number;
  average_rating?: number | null;
  total_orders?: number;
  completed_orders?: number;
  recent_orders?: CourierRecentOrder[];
  recent_ratings?: CourierRecentRating[];
  created_at: string;
}

export interface CourierRecentOrder {
  id: number;
  status: OrderStatus;
  price: number;
  created_at: string;
  from_address: string;
  to_address: string;
}

export interface CourierRecentRating {
  order_id: number;
  rating: number;
  comment?: string | null;
  created_at: string;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
  user: User;
}

export interface LoginCredentials {
  phone: string;
  password: string;
}

// Order Types
export type OrderStatus = 
  | 'WAITING_COURIER' 
  | 'ACCEPTED' 
  | 'ON_THE_WAY' 
  | 'DELIVERED' 
  | 'COMPLETED' 
  | 'CANCELLED';

export interface OrderStatusAudit {
  actor_user_id: number | null;
  from_status: string | null;
  to_status: string;
  at: string;
}

export interface Order {
  id: number;
  pickup_location: string;
  delivery_location: string;
  pickup_lat: number;
  pickup_lon: number;
  delivery_lat: number;
  delivery_lon: number;
  distance_km: number;
  estimated_price: number;
  status: OrderStatus;
  user_id: number;
  user_phone?: string | null;
  courier_id: number | null;
  courier_phone?: string | null;
  created_at: string;
  updated_at: string;
  user?: User;
  courier?: User;
  category?: string;
  description?: string;
  verification_code?: string | null;
  hidden_for_user?: boolean;
  hidden_for_courier?: boolean;
  admin_note?: string | null;
  status_audit?: OrderStatusAudit[];
}

// Topup Types
export interface TopupRequest {
  id: number;
  user_id: number;
  unique_id?: string;
  requested_amount: number;
  screenshot_hash: string;
  screenshot_file_id?: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
  approved_at?: string | null;
  admin_comment: string | null;
  user?: User;
}

// Notification Types
export interface Notification {
  id: number;
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
}

// Statistics Types
export interface SystemStats {
  total_orders: number;
  waiting_orders: number;
  active_orders: number;
  completed_orders: number;
  total_revenue: number;
  total_users: number;
  total_couriers: number;
  online_couriers: number;
  pending_topups: number;
  approved_topups_count: number;
  rejected_topups_count: number;
  approved_topups_amount: number;
  rejected_topups_amount: number;
  pending_topups_amount: number;
  // Today's metrics
  total_orders_today: number;
  canceled_orders_today: number;
  delivered_orders_today: number;
  revenue_today: number;
}

export interface PaymentStats {
  approved_topups_count: number;
  rejected_topups_count: number;
  pending_topups_count: number;
  approved_topups_amount: number;
  rejected_topups_amount: number;
  pending_topups_amount: number;
}

export interface RevenueByDate {
  date: string;
  revenue: number;
  orders: number;
}

// Pagination
export interface PaginationParams {
  skip?: number;
  limit?: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  skip: number;
  limit: number;
}

// Filter & Search
export interface OrderFilters {
  status?: OrderStatus;
  user_id?: number;
  courier_id?: number;
  date_from?: string;
  date_to?: string;
  today_only?: boolean;
  order_date?: string;
}

export interface UserFilters {
  role?: 'user' | 'courier' | 'admin';
  is_active?: boolean;
  search?: string;
}
