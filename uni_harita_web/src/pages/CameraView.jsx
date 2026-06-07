import { useEffect, useRef, useState } from 'react';
import { campusLocations } from '../data/campusLocations';
import './CameraView.css';

/**
 * İki koordinat arasındaki mesafeyi metre cinsinden hesaplayan Haversine formülü.
 */
function getDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Dünya'nın yarıçapı (metre)
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) *
      Math.cos(phi2) *
      Math.sin(deltaLambda / 2) *
      Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Mesafe (metre)
}

function formatDistance(meters) {
  if (meters < 1000) return `${Math.round(meters)}m`;
  return `${(meters / 1000).toFixed(1)}km`;
}

export default function CameraView({ onClose, userPosition }) {
  const videoRef = useRef(null);
  const [locationsWithDistance, setLocationsWithDistance] = useState([]);

  // Kamera erişimi başlat
  useEffect(() => {
    let stream = null;

    async function startCamera() {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment' }, // Tercihen arka kamera
        });
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }
      } catch (err) {
        console.error('Kamera erişim hatası:', err);
        alert('Kamera erişimine izin verilmedi veya cihazda kamera bulunamadı.');
      }
    }

    startCamera();

    // Temizlik (Component unmount olunca kamerayı kapat)
    return () => {
      if (stream) {
        stream.getTracks().forEach((track) => track.stop());
      }
    };
  }, []);

  // Mesafeleri hesapla
  useEffect(() => {
    if (!userPosition) return;

    const locations = campusLocations.map((loc) => {
      const distance = getDistance(
        userPosition.lat,
        userPosition.lng,
        loc.latitude,
        loc.longitude
      );
      return { ...loc, distance };
    });

    // Mesafeye göre sırala (yakından uzağa)
    locations.sort((a, b) => a.distance - b.distance);
    setLocationsWithDistance(locations);
  }, [userPosition]);

  return (
    <div className="camera-view-container">
      {/* Kapatma Butonu */}
      <button className="camera-close-btn" onClick={onClose} title="Haritaya Dön">
        ✖
      </button>

      {/* Canlı Kamera Yayını */}
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        className="camera-video"
      />

      {/* Mesafe Göstergesi (Yatay Kaydırılabilir Slider) */}
      <div className="camera-overlay-bottom">
        <div className="locations-slider">
          {locationsWithDistance.map((loc, idx) => (
            <div
              key={idx}
              className="location-card"
              style={{ borderColor: `${loc.color}66` }}
            >
              <div className="loc-icon" style={{ color: loc.color }}>
                {loc.icon}
              </div>
              <div className="loc-info">
                <div className="loc-name">{loc.name}</div>
                <div className="loc-distance">
                  {formatDistance(loc.distance)} uzaklıkta
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
