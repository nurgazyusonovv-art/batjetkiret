import { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { authService } from '@/services/auth';
interface ProtectedRouteProps {
  children: ReactNode;
  allowedRoles?: string[];
}

export default function ProtectedRoute({ children, allowedRoles }: ProtectedRouteProps) {
  const isAuthed = authService.isAuthenticated();
  const user = authService.getStoredUser();

  if (!isAuthed || !user) {
    authService.logout();
    return <Navigate to="/login" replace />;
  }

  if (Array.isArray(allowedRoles) && allowedRoles.length > 0) {
    if (!allowedRoles.includes(user.role)) {
      return <Navigate to="/login" replace />;
    }
  }

  return <>{children}</>;
}
