import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import OrdersPage from './pages/OrdersPage';
import UsersPage from './pages/UsersPage';
import TopupPage from './pages/TopupPage';
import StatsPage from './pages/StatsPage';
import NotificationsPage from './pages/NotificationsPage';
import EnterprisesPage from './pages/EnterprisesPage';
import SupportChatsPage from './pages/SupportChatsPage';
import IntercityPage from './pages/IntercityPage';
import UserDetailPage from './pages/UserDetailPage';
import SettingsPage from './pages/SettingsPage';
import CancelRequestsPage from './pages/CancelRequestsPage';
import ProtectedRoute from './components/ProtectedRoute';
import DashboardLayout from './components/DashboardLayout';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />

        <Route
          path="/"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <DashboardPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/orders"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <OrdersPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/users"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <UsersPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/topup"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <TopupPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/stats"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <StatsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/notifications"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <NotificationsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/enterprises"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <EnterprisesPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/support-chats"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <SupportChatsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/intercity"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <IntercityPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/users/:id"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <UserDetailPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/settings"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <SettingsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route
          path="/cancel-requests"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <CancelRequestsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
