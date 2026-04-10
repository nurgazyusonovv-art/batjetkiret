import api from '../services/api';

/** Convert a base64url string to an ArrayBuffer (required by applicationServerKey). */
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

/** Request notification permission + subscribe to Web Push, then save to backend.
 *  Safe to call multiple times — idempotent when already subscribed. */
export async function subscribeToPush(): Promise<void> {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;

  // User explicitly blocked notifications — nothing we can do
  if (Notification.permission === 'denied') return;

  // Request permission if not yet granted
  if (Notification.permission !== 'granted') {
    const result = await Notification.requestPermission();
    if (result !== 'granted') return;
  }

  try {
    const reg = _swReg ?? (await navigator.serviceWorker.ready);

    // Fetch VAPID public key from backend
    const { data } = await api.get<{ public_key: string }>('/enterprise-portal/vapid-key');
    const applicationServerKey = urlBase64ToUint8Array(data.public_key);

    // Check if a subscription already exists in the browser
    const existing = await reg.pushManager.getSubscription();
    if (existing) {
      // Always re-send to backend (handles new device / backend DB wipe / re-login)
      try {
        await api.post('/enterprise-portal/push-subscribe', { subscription: existing.toJSON() });
        return; // already subscribed, backend is up to date
      } catch (err: unknown) {
        const status = (err as { response?: { status?: number } })?.response?.status;
        // Only unsubscribe + retry if the backend explicitly rejects the subscription (4xx).
        // Ignore transient network/5xx errors.
        if (!status || status >= 500) return;
        await existing.unsubscribe();
      }
    }

    // Create a fresh subscription
    const subscription = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey,
    });

    await api.post('/enterprise-portal/push-subscribe', { subscription: subscription.toJSON() });
  } catch (e) {
    console.warn('Push subscription failed:', e);
  }
}
