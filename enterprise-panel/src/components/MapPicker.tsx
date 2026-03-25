import { useState, useEffect, useRef } from 'react';
import L from 'leaflet';
import { MapPin, X, Check, Loader } from 'lucide-react';
import 'leaflet/dist/leaflet.css';
import './MapPicker.css';

const markerIcon = L.icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

interface Props {
  onConfirm: (address: string, lat: number | null, lng: number | null) => void;
  onClose: () => void;
  initialAddress?: string;
  initialLat?: number;
  initialLng?: number;
}

const DEFAULT_CENTER: [number, number] = [40.0628, 70.8193]; // Баткен шаары
const DEFAULT_ZOOM = 13;

async function reverseGeocode(lat: number, lng: number): Promise<string> {
  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`,
      { headers: { 'Accept-Language': 'ru' } }
    );
    const data = await res.json();
    if (data.address) {
      const a = data.address;
      const parts = [a.road, a.house_number, a.suburb ?? a.neighbourhood ?? a.quarter, a.city ?? a.town ?? a.village].filter(Boolean);
      return parts.length ? parts.join(', ') : (data.display_name ?? '').split(',').slice(0, 3).join(',').trim();
    }
  } catch { /* ignore */ }
  return `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
}

export default function MapPicker({ onConfirm, onClose, initialAddress, initialLat, initialLng }: Props) {
  const mapDivRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);

  const [pin, setPin] = useState<[number, number] | null>(null);
  const [address, setAddress] = useState(initialAddress ?? '');
  const [geocoding, setGeocoding] = useState(false);

  const placePin = (map: L.Map, lat: number, lng: number) => {
    if (markerRef.current) {
      markerRef.current.setLatLng([lat, lng]);
    } else {
      markerRef.current = L.marker([lat, lng], { icon: markerIcon }).addTo(map);
    }
    map.setView([lat, lng], map.getZoom());
    setPin([lat, lng]);
  };

  useEffect(() => {
    if (!mapDivRef.current || mapRef.current) return;

    const map = L.map(mapDivRef.current, {
      center: DEFAULT_CENTER,
      zoom: DEFAULT_ZOOM,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(map);

    map.on('click', async (e: L.LeafletMouseEvent) => {
      const { lat, lng } = e.latlng;
      placePin(map, lat, lng);
      setGeocoding(true);
      const addr = await reverseGeocode(lat, lng);
      setAddress(addr);
      setGeocoding(false);
    });

    mapRef.current = map;

    // 1) Координаталар берилген болсо — түздөн-түз колдон
    if (initialLat !== undefined && initialLng !== undefined) {
      map.setView([initialLat, initialLng], DEFAULT_ZOOM);
      markerRef.current = L.marker([initialLat, initialLng], { icon: markerIcon }).addTo(map);
      setPin([initialLat, initialLng]);
      // Адрес берилбеген болсо — reverse geocode кылып толтур
      if (!initialAddress?.trim()) {
        setGeocoding(true);
        reverseGeocode(initialLat, initialLng).then(addr => setAddress(addr)).finally(() => setGeocoding(false));
      }
    }
    // 2) Болбосо адрести geocode кылып таап center'ле
    else if (initialAddress?.trim()) {
      setGeocoding(true);
      fetch(`https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(initialAddress)}&format=json&limit=1`)
        .then(r => r.json())
        .then(data => {
          if (data[0] && mapRef.current) {
            const lat = parseFloat(data[0].lat);
            const lng = parseFloat(data[0].lon);
            mapRef.current.setView([lat, lng], DEFAULT_ZOOM);
            markerRef.current = L.marker([lat, lng], { icon: markerIcon }).addTo(mapRef.current);
            setPin([lat, lng]);
          }
        })
        .catch(() => {})
        .finally(() => setGeocoding(false));
    }

    return () => {
      map.remove();
      mapRef.current = null;
      markerRef.current = null;
    };
  }, []);

  return (
    <div className="map-picker-overlay" onClick={onClose}>
      <div className="map-picker-modal" onClick={e => e.stopPropagation()}>

        <div className="mp-header">
          <div className="mp-title">
            <MapPin size={18} color="#4f46e5" />
            <span>Картадан дарек тандоо</span>
          </div>
          <button className="mp-close" onClick={onClose}><X size={18} /></button>
        </div>

        <div className="mp-map-wrap">
          <div ref={mapDivRef} className="mp-map" />
          {!pin && !geocoding && (
            <div className="mp-hint">
              <MapPin size={14} />
              Картага басуу менен дарек тандаңыз
            </div>
          )}
          {geocoding && !pin && (
            <div className="mp-hint">
              <Loader size={14} className="spin-icon" />
              Дарек изделүүдө...
            </div>
          )}
        </div>

        <div className="mp-footer">
          <div className="mp-address-row">
            <div className="mp-address-input-wrap">
              <MapPin size={14} className="mp-addr-icon" />
              {geocoding && pin ? (
                <span className="mp-geocoding"><Loader size={13} className="spin-icon" /> Дарек аныкталууда...</span>
              ) : (
                <input
                  className="mp-address-input"
                  value={address}
                  onChange={e => setAddress(e.target.value)}
                  placeholder="Картага басыңыз же дарек жазыңыз"
                />
              )}
            </div>
          </div>
          <div className="mp-actions">
            <button className="mp-btn-cancel" onClick={onClose}>Жокко чыгаруу</button>
            <button
              className="mp-btn-confirm"
              onClick={() => onConfirm(address, pin?.[0] ?? null, pin?.[1] ?? null)}
              disabled={!address.trim()}
            >
              <Check size={15} />
              Даректи тандоо
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
