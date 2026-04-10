import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import './mobile.css'
import { registerServiceWorker, subscribeToPush } from './utils/pushNotifications'
import { authService } from './services/auth'

// Register service worker for background push notifications
registerServiceWorker().then(() => {
  // If already logged in, re-subscribe to push (handles page refresh / new device)
  if (authService.isLoggedIn()) {
    subscribeToPush().catch(() => {});
  }
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
