import api from '../services/api';

/** Convert a base64url string to a Uint8Array (needed for applicationServerKey). */
function urlBase64ToUint8Array(base64String: string): ArrayBuffer {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64);
  const buffer = new ArrayBuffer(raw.length);
  const arr = new Uint8Array(buffer);
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
  return buffer;
}

let _swReg: ServiceWorkerRegistration | null = null;

/** Register the service worker (called once on app start). */
export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  if (!('serviceWorker' in navigator)) return null;
  try {
    const reg = await navigator.serviceWorker.register('/sw.js', { scope: '/' });
    await navigator.serviceWorker.ready;
    _swReg = reg;
    return reg;
  } catch (e) {
    console.warn('SW registration failed:', e);
    return null;
  }
}

/** Request notification permission + subscribe to Web Push, then save to backend. */
export async function subscribeToPush(): Promise<void> {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;

  // Ask permission if not already granted
  let permission = Notification.permission;
  if (permission === 'denied') return; // user explicitly blocked — nothing to do
  if (permission !== 'granted') {
    permission = await Notification.requestPermission();
    if (permission !== 'granted') return;
  }

  try {
    const reg = _swReg ?? (await navigator.serviceWorker.ready);

    // Fetch VAPID public key from backend
    const { data } = await api.get<{ public_key: string }>('/enterprise-portal/vapid-key');
    const applicationServerKey = urlBase64ToUint8Array(data.public_key);

    // Unsubscribe existing subscription first to ensure fresh one with current VAPID key
    const existing = await reg.pushManager.getSubscription();
    if (existing) {
      // Check if already subscribed to the same VAPID key — if so, just re-send to backend
      try {
        await api.post('/enterprise-portal/push-subscribe', {
          subscription: existing.toJSON(),
        });
        return; // already subscribed and backend updated
      } catch {
        // Backend rejected — unsubscribe and re-subscribe
        await existing.unsubscribe();
      }
    }

    // Create new subscription
    const subscription = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey,
    });

    // Save to backend
    await api.post('/enterprise-portal/push-subscribe', {
      subscription: subscription.toJSON(),
    });
  } catch (e) {
    console.warn('Push subscription failed:', e);
  }
}
