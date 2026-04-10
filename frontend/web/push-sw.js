// Баткен Экспресс — Web Push Service Worker v1
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
      data  = payload;
    } catch (_) {
      try { body = event.data.text(); } catch (_2) {}
    }
  }

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/icons/Icon-192.png',
      badge: '/favicon.png',
      tag: 'order-status',
      renotify: true,
      data,
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow('/');
    })
  );
});
