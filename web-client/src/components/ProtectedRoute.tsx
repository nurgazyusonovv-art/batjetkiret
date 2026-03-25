import { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { authService } from '../services/auth';

export default function ProtectedRoute({ children }: { children: ReactNode }) {
  if (!authService.isLoggedIn()) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
