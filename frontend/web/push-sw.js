// Баткен Экспресс — Customer Web Push Service Worker v3
// Registered at scope '/push/' — does NOT control the main app, only receives push events.
// Payload shape from backend: { title, body, data: { order_id?, status, type } }

self.addEventListener('install', () => self.skipWaiting());
// No clients.claim() — Flutter's service_worker.js stays in control of the page.
self.addEventListener('activate', (e) => e.waitUntil(Promise.resolve()));

self.addEventListener('push', (event) => {
  let title = '🛎 Баткен Экспресс';
  let body  = 'Заказыңыз боюнча жаңылык бар';
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

  // Unique tag per order → each order shows its own notification,
  // same order status updates replace each other (no stacking).
  const tag = data.order_id ? `order-${data.order_id}` : 'order-update';

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/icons/Icon-192.png',
      badge: '/favicon.png',
      tag,
      renotify: true,
      data,
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((list) => {
        for (const client of list) {
          if ('focus' in client) return client.focus();
        }
        return self.clients.openWindow('/');
      })
  );
});
