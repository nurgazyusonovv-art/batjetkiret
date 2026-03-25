import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Fix default marker icons
delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// Batken city center
const BATKEN_CENTER: [number, number] = [40.060518, 70.819638];

interface Props {
  value?: [number, number] | null;
  onChange: (latlng: [number, number], address: string) => void;
  height?: string;
  markerColor?: 'green' | 'red' | 'blue';
}

export default function MapPicker({ value, onChange, height = '300px', markerColor = 'blue' }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);

  const iconUrl = markerColor === 'green'
    ? 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png'
    : markerColor === 'red'
    ? 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png'
    : 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png';

  const customIcon = L.icon({
    iconUrl,
    shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
    shadowSize: [41, 41],
  });

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = L.map(containerRef.current).setView(value ?? BATKEN_CENTER, 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap',
    }).addTo(map);

    mapRef.current = map;

    if (value) {
      markerRef.current = L.marker(value, { icon: customIcon }).addTo(map);
    }

    map.on('click', async (e) => {
      const { lat, lng } = e.latlng;
      if (markerRef.current) {
        markerRef.current.setLatLng([lat, lng]);
      } else {
        markerRef.current = L.marker([lat, lng], { icon: customIcon }).addTo(map);
      }
      const address = await reverseGeocode(lat, lng);
      onChange([lat, lng], address);
    });

    return () => { map.remove(); mapRef.current = null; };
  }, []);

  useEffect(() => {
    if (!mapRef.current || !value) return;
    if (markerRef.current) {
      markerRef.current.setLatLng(value);
    } else {
      markerRef.current = L.marker(value, { icon: customIcon }).addTo(mapRef.current);
    }
    mapRef.current.setView(value, mapRef.current.getZoom());
  }, [value]);

  return <div ref={containerRef} style={{ height, borderRadius: 10, overflow: 'hidden' }} />;
}

async function reverseGeocode(lat: number, lng: number): Promise<string> {
  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json&accept-language=ru`
    );
    const data = await res.json();
    const addr = data.address;
    const parts = [addr.road, addr.suburb, addr.city || addr.town || addr.village].filter(Boolean);
    return parts.join(', ') || data.display_name?.split(',').slice(0, 2).join(', ') || `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
  } catch {
    return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
  }
}
