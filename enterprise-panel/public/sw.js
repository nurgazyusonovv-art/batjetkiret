// Enterprise Panel Service Worker — Web Push v3
// Payload shape from backend: { title, body, data: { order_id?, type, ... } }

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// ── Push handler ──────────────────────────────────────────────────────────────
self.addEventListener('push', (event) => {
  let title = '🛎 Жаңы заказ!';
  let body  = 'Ишкана панелин ачыңыз';
  let data  = {};

  if (event.data) {
    try {
      const payload = event.data.json();
      title = payload.title || title;
      body  = payload.body  || body;
      data  = payload.data  || {};
    } catch (_) {
      try { body = event.data.text(); } catch (_2) {}
    }
  }

  // Use per-order tag so multiple orders each show their own notification.
  // Same order → replace (renotify) instead of stacking.
  const tag = data.order_id ? `order-${data.order_id}` : 'order-update';

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/logo.png',
      badge: '/favicon.png',
      tag,
      renotify: true,
      data,
    })
  );
});

// ── Notification click → open / focus and navigate to the order ───────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const orderId = event.notification.data && event.notification.data.order_id;
  const url = orderId ? `/orders?order_id=${orderId}` : '/orders';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // If the app is already open, focus it and post a message so the UI can
        // scroll to / highlight the relevant order.
        for (const client of clientList) {
          if ('focus' in client) {
            client.focus();
            if (orderId) client.postMessage({ type: 'OPEN_ORDER', order_id: orderId });
            return;
          }
        }
        // App not open — open a new window at the target URL.
        return self.clients.openWindow(url);
      })
  );
});
