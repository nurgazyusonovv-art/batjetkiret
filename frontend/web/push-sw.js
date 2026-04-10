// Баткен Экспресс — Customer Web Push Service Worker v2
// Payload shape from backend: { title, body, data: { order_id?, status, type } }

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

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
  // same order status updates replace each other (no spam stacking).
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
        // Focus any existing tab
        for (const client of list) {
          if ('focus' in client) return client.focus();
        }
        // No tab open — open the app at root
        return self.clients.openWindow('/');
      })
  );
});
