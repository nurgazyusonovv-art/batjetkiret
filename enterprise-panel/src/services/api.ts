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
    if (err.response?.status === 401 && !redirecting) {
      redirecting = true;
      localStorage.removeItem('enterprise_token');
      localStorage.removeItem('enterprise_info');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export default api;
