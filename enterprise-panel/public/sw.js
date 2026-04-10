// Service Worker — Enterprise Panel Push Notifications v2
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// ── Push handler ─────────────────────────────────────────────────────────────
self.addEventListener('push', (event) => {
  let title = '🛎 Жаңы заказ!';
  let body  = 'Ишкана панелин ачыңыз';
  let data  = {};

  if (event.data) {
    try {
      const payload = event.data.json();
      title = payload.title || title;
      body  = payload.body  || body;
      data  = payload;
    } catch (_) {
      try { body = event.data.text(); } catch (_2) {}
    }
  }

  const options = {
    body,
    icon: '/logo.png',
    badge: '/favicon.png',
    tag: 'new-order',   // same tag → replaces old notification instead of stacking
    renotify: true,     // still plays sound even if same tag
    data,
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// ── Notification click → open / focus the app ─────────────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow('/orders');
    })
  );
});
