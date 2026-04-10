import axios from 'axios';

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: BASE_URL,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('enterprise_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

let redirecting = false;

api.interceptors.response.use(
  (res) => res,
  (err) => {
    const status = err.response?.status;
    const url: string = err.config?.url ?? '';

    // Only clear session on 401 from authenticated endpoints (not from /login itself).
    // This prevents transient network errors or wrong-endpoint calls from logging the user out.
    if (status === 401 && !url.includes('/login') && !redirecting) {
      // Double-check: only logout if we actually have a token stored.
      // If there's no token, this is just an anonymous request that failed.
      if (localStorage.getItem('enterprise_token')) {
        redirecting = true;
        localStorage.removeItem('enterprise_token');
        localStorage.removeItem('enterprise_info');
        window.location.href = '/login';
      }
    }
    return Promise.reject(err);
  }
);

export default api;
