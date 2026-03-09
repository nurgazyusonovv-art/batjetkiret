import { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { authService } from '@/services/auth';

interface ProtectedRouteProps {
  children: ReactNode;
}

export default function ProtectedRoute({ children }: ProtectedRouteProps) {
  const isAuthed = authService.isAuthenticated();
  const user = authService.getStoredUser();

  if (!isAuthed || !user) {
    authService.logout();
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}
