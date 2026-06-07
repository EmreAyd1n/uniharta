import { useEffect, useState, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import mapboxgl from 'mapbox-gl';
import { campusLocations, filterByGeminiCategory } from '../data/campusLocations';
import {
  subscribeToActiveEvents,
  getCategoryMeta,
  joinEvent,
  leaveEvent,
  subscribeToParticipants,
} from '../services/eventService';
import { analyzeIntent } from '../services/geminiService';
import { getWalkingRoute } from '../services/mapboxRouteService';
import CameraView from './CameraView';
import './MapScreen.css';

mapboxgl.accessToken = import.meta.env.VITE_MAPBOX_ACCESS_TOKEN || '';

const CAMPUS_CENTER = [39.1995, 38.6795]; // [lng, lat]
const INITIAL_ZOOM = 16.5;

const FILTER_CATEGORIES = [
  { key: 'Tümü', label: 'Bugün Ne Var?', icon: '🎉' },
  { key: 'Seminer', label: 'Seminer', icon: '📖' },
  { key: 'Spor', label: 'Spor', icon: '⚽' },
  { key: 'Yemek', label: 'Yemek', icon: '🍽️' },
  { key: 'Eğlence', label: 'Eğlence', icon: '🎵' },
];

export default function Home() {
  const navigate = useNavigate();
  const mapContainerRef = useRef(null);
  const mapRef = useRef(null);
  const markersRef = useRef([]);
  const routeSourceAdded = useRef(false);

  // Auth & Profile
  const [isOrganizer, setIsOrganizer] = useState(false);
  const [currentUserId, setCurrentUserId] = useState(null);

  // Events
  const [events, setEvents] = useState([]);
  const [activeFilter, setActiveFilter] = useState('Tümü');

  // Search
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [searchResultText, setSearchResultText] = useState(null);

  // Selection
  const [selectedEvent, setSelectedEvent] = useState(null);
  const [selectedDestination, setSelectedDestination] = useState(null);
  const [routeDistance, setRouteDistance] = useState(null);
  const [routeDuration, setRouteDuration] = useState(null);

  // User location
  const [userPosition, setUserPosition] = useState(null);
  const userMarkerRef = useRef(null);

  // Camera portal
  const [showCamera, setShowCamera] = useState(false);

  // Participants for selected event
  const [participants, setParticipants] = useState([]);
  const participantsUnsubRef = useRef(null);

  // Create event modal
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newEvent, setNewEvent] = useState({
    title: '',
    description: '',
    category: 'seminer',
    latitude: '',
    longitude: '',
    start_time: '',
  });
  const [creatingEvent, setCreatingEvent] = useState(false);

  // ──────────────────────────────────────────
  // Auth check
  // ──────────────────────────────────────────
  useEffect(() => {
    (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        navigate('/login');
        return;
      }
      setCurrentUserId(user.id);

      try {
        const { data } = await supabase
          .from('profiles')
          .select('user_type')
          .eq('id', user.id)
          .single();
        setIsOrganizer(data?.user_type === 'organizator');
      } catch {
        setIsOrganizer(user.user_metadata?.user_type === 'organizator');
      }
    })();
  }, [navigate]);

  // ──────────────────────────────────────────
  // Events subscription
  // ──────────────────────────────────────────
  useEffect(() => {
    const unsub = subscribeToActiveEvents((evts) => {
      setEvents(evts);
    });
    return unsub;
  }, []);

  // ──────────────────────────────────────────
  // Participants subscription for selected event
  // ──────────────────────────────────────────
  useEffect(() => {
    if (participantsUnsubRef.current) {
      participantsUnsubRef.current();
      participantsUnsubRef.current = null;
    }
    if (selectedEvent) {
      participantsUnsubRef.current = subscribeToParticipants(
        selectedEvent.id,
        (p) => setParticipants(p)
      );
    } else {
      setParticipants([]);
    }
    return () => {
      if (participantsUnsubRef.current) participantsUnsubRef.current();
    };
  }, [selectedEvent?.id]);

  // ──────────────────────────────────────────
  // User geolocation
  // ──────────────────────────────────────────
  useEffect(() => {
    if (!navigator.geolocation) return;

    navigator.geolocation.getCurrentPosition(
      (pos) =>
        setUserPosition({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => {},
      { enableHighAccuracy: true }
    );

    const watchId = navigator.geolocation.watchPosition(
      (pos) =>
        setUserPosition({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => {},
      { enableHighAccuracy: true }
    );

    return () => navigator.geolocation.clearWatch(watchId);
  }, []);

  // ──────────────────────────────────────────
  // Initialize Mapbox GL map
  // ──────────────────────────────────────────
  useEffect(() => {
    if (mapRef.current || !mapContainerRef.current) return;

    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/mapbox/dark-v11',
      center: CAMPUS_CENTER,
      zoom: INITIAL_ZOOM,
    });

    map.addControl(new mapboxgl.NavigationControl(), 'bottom-left');
    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // ──────────────────────────────────────────
  // Update user location marker
  // ──────────────────────────────────────────
  useEffect(() => {
    if (!mapRef.current || !userPosition) return;

    if (userMarkerRef.current) {
      userMarkerRef.current.setLngLat([userPosition.lng, userPosition.lat]);
    } else {
      const el = document.createElement('div');
      el.className = 'user-location-marker';
      userMarkerRef.current = new mapboxgl.Marker({ element: el })
        .setLngLat([userPosition.lng, userPosition.lat])
        .addTo(mapRef.current);
    }
  }, [userPosition]);

  // ──────────────────────────────────────────
  // Render markers (campus + events)
  // ──────────────────────────────────────────
  const renderMarkers = useCallback(() => {
    if (!mapRef.current) return;

    // Clear old markers
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    // Campus location markers
    campusLocations.forEach((loc) => {
      const el = document.createElement('div');
      el.className = 'campus-marker';
      el.innerHTML = `
        <span class="marker-label" style="background:${loc.color}cc; border:1px solid ${loc.color}">${loc.name}</span>
        <span class="marker-icon">${loc.icon}</span>
      `;
      el.addEventListener('click', () => handleDrawRouteToLocation(loc));

      const marker = new mapboxgl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([loc.longitude, loc.latitude])
        .addTo(mapRef.current);

      markersRef.current.push(marker);
    });

    // Event markers (filtered)
    const filteredEvents = events.filter((e) => {
      if (e.latitude == null || e.longitude == null) return false;
      if (activeFilter !== 'Tümü') {
        const meta = getCategoryMeta(e.category);
        if (meta.displayName !== activeFilter) return false;
      }
      return true;
    });

    filteredEvents.forEach((event) => {
      const meta = getCategoryMeta(event.category);
      const el = document.createElement('div');
      el.className = 'campus-marker event-marker';
      el.innerHTML = `
        <span class="marker-label">${event.title}</span>
        <span class="marker-icon">${meta.icon}</span>
      `;
      el.addEventListener('click', () => {
        setSelectedEvent(event);
        setSelectedDestination(null);
        setRouteDistance(null);
        setRouteDuration(null);
      });

      const marker = new mapboxgl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([event.longitude, event.latitude])
        .addTo(mapRef.current);

      markersRef.current.push(marker);
    });
  }, [events, activeFilter]);

  useEffect(() => {
    // Wait for map to load before rendering markers
    if (!mapRef.current) return;
    const map = mapRef.current;

    if (map.loaded()) {
      renderMarkers();
    } else {
      map.on('load', renderMarkers);
      return () => map.off('load', renderMarkers);
    }
  }, [renderMarkers]);

  // ──────────────────────────────────────────
  // Draw route on map
  // ──────────────────────────────────────────
  async function drawRoute(startLng, startLat, endLng, endLat) {
    const map = mapRef.current;
    if (!map) return null;

    const routeData = await getWalkingRoute(startLng, startLat, endLng, endLat);
    if (!routeData) return null;

    // Wait for map style to be loaded
    if (!map.isStyleLoaded()) {
      await new Promise((resolve) => map.on('style.load', resolve));
    }

    // Remove existing route
    if (routeSourceAdded.current) {
      try {
        if (map.getLayer('route-layer')) map.removeLayer('route-layer');
        if (map.getSource('route-source')) map.removeSource('route-source');
      } catch {}
    }

    map.addSource('route-source', {
      type: 'geojson',
      data: {
        type: 'Feature',
        properties: {},
        geometry: routeData.geometry,
      },
    });

    map.addLayer({
      id: 'route-layer',
      type: 'line',
      source: 'route-source',
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: { 'line-color': '#800000', 'line-width': 6 },
    });

    routeSourceAdded.current = true;

    // Fit bounds
    const coords = routeData.geometry.coordinates;
    const bounds = coords.reduce(
      (b, c) => b.extend(c),
      new mapboxgl.LngLatBounds(coords[0], coords[0])
    );
    map.fitBounds(bounds, { padding: { top: 150, bottom: 300, left: 80, right: 80 }, duration: 1200 });

    return routeData;
  }

  function clearRoute() {
    const map = mapRef.current;
    if (!map || !routeSourceAdded.current) return;
    try {
      if (map.getLayer('route-layer')) map.removeLayer('route-layer');
      if (map.getSource('route-source')) map.removeSource('route-source');
      routeSourceAdded.current = false;
    } catch {}
  }

  // ──────────────────────────────────────────
  // Handle route to campus location
  // ──────────────────────────────────────────
  async function handleDrawRouteToLocation(loc) {
    const startLng = userPosition?.lng ?? CAMPUS_CENTER[0];
    const startLat = userPosition?.lat ?? CAMPUS_CENTER[1];

    setSelectedEvent(null);
    setSelectedDestination(loc);
    setRouteDistance(null);
    setRouteDuration(null);

    const result = await drawRoute(startLng, startLat, loc.longitude, loc.latitude);
    if (result) {
      setRouteDistance(result.distance);
      setRouteDuration(result.duration);
    }
  }

  // ──────────────────────────────────────────
  // Handle route to event
  // ──────────────────────────────────────────
  async function handleDrawRouteToEvent(event) {
    if (event.latitude == null || event.longitude == null) return;
    const meta = getCategoryMeta(event.category);

    const startLng = userPosition?.lng ?? CAMPUS_CENTER[0];
    const startLat = userPosition?.lat ?? CAMPUS_CENTER[1];

    setSelectedEvent(null);
    setSelectedDestination({
      name: event.title,
      color: meta.color,
      latitude: event.latitude,
      longitude: event.longitude,
    });
    setRouteDistance(null);
    setRouteDuration(null);

    const result = await drawRoute(startLng, startLat, event.longitude, event.latitude);
    if (result) {
      setRouteDistance(result.distance);
      setRouteDuration(result.duration);
    }
  }

  // ──────────────────────────────────────────
  // Gemini semantic search
  // ──────────────────────────────────────────
  async function handleSearch(query) {
    if (!query.trim()) return;
    setIsSearching(true);
    setSearchResultText(null);

    const result = await analyzeIntent(query);
    setIsSearching(false);

    if (!result) {
      setSearchResultText('Arama sonucu bulunamadı');
      return;
    }

    setSearchResultText(result.intent);

    // Find matching locations
    const matchingLocations = filterByGeminiCategory(result.category);
    const matchingEvents = events.filter((e) => e.category === result.category);

    if (matchingLocations.length > 0 && matchingLocations !== campusLocations) {
      const target = matchingLocations[0];
      mapRef.current?.flyTo({
        center: [target.longitude, target.latitude],
        zoom: 17.5,
        duration: 1200,
      });
    } else if (matchingEvents.length > 0 && matchingEvents[0].latitude != null) {
      const e = matchingEvents[0];
      mapRef.current?.flyTo({
        center: [e.longitude, e.latitude],
        zoom: 17.5,
        duration: 1200,
      });
      setSelectedEvent(e);
      setSelectedDestination(null);
    }
  }

  // ──────────────────────────────────────────
  // Logout
  // ──────────────────────────────────────────
  async function handleLogout() {
    await supabase.auth.signOut();
    navigate('/login');
  }

  // ──────────────────────────────────────────
  // Focus on user location
  // ──────────────────────────────────────────
  function focusUserLocation() {
    if (!mapRef.current || !userPosition) return;
    mapRef.current.flyTo({
      center: [userPosition.lng, userPosition.lat],
      zoom: INITIAL_ZOOM,
      duration: 1000,
    });
  }

  // ──────────────────────────────────────────
  // Create event handler
  // ──────────────────────────────────────────
  async function handleCreateEvent(e) {
    e.preventDefault();
    setCreatingEvent(true);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      const { error } = await supabase.from('events').insert({
        title: newEvent.title,
        description: newEvent.description,
        category: newEvent.category,
        latitude: parseFloat(newEvent.latitude) || null,
        longitude: parseFloat(newEvent.longitude) || null,
        start_time: new Date(newEvent.start_time).toISOString(),
        is_active: true,
        organizer_id: user?.id,
      });

      if (!error) {
        setShowCreateModal(false);
        setNewEvent({
          title: '',
          description: '',
          category: 'seminer',
          latitude: '',
          longitude: '',
          start_time: '',
        });
      }
    } catch (err) {
      console.error('Create event error:', err);
    } finally {
      setCreatingEvent(false);
    }
  }

  // ──────────────────────────────────────────
  // Derived state
  // ──────────────────────────────────────────
  const showEventCard = selectedEvent != null;
  const showRouteCard =
    selectedDestination != null && routeDistance != null && routeDuration != null;

  const filteredEvents = events.filter((e) => {
    if (e.latitude == null || e.longitude == null) return false;
    if (activeFilter !== 'Tümü') {
      const meta = getCategoryMeta(e.category);
      if (meta.displayName !== activeFilter) return false;
    }
    return true;
  });
  const showEmptyState =
    activeFilter !== 'Tümü' &&
    filteredEvents.length === 0 &&
    !showEventCard &&
    !showRouteCard;

  const isAnyCardVisible = showEventCard || showRouteCard || showEmptyState;

  const isGoing = participants.some((p) => p.user_id === currentUserId);

  // ──────────────────────────────────────────
  // Format helpers
  // ──────────────────────────────────────────
  function formatDistance(d) {
    return d < 1000 ? `${Math.round(d)} Metre` : `${(d / 1000).toFixed(1)} KM`;
  }
  function formatDuration(d) {
    return `${Math.ceil(d / 60)} Dakika`;
  }

  // ──────────────────────────────────────────
  // Render
  // ──────────────────────────────────────────
  return (
    <div className="map-screen">
      {/* Mapbox map container */}
      <div ref={mapContainerRef} style={{ width: '100%', height: '100%' }} />

      {/* Search bar */}
      <div className="search-bar">
        <span className="search-icon">✨</span>
        <input
          type="text"
          placeholder="Ne arıyorsun? (Örn: Karnım acıktı)"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') handleSearch(searchQuery);
          }}
        />
        {isSearching ? (
          <div className="search-spinner" />
        ) : (
          <button
            className="search-btn"
            onClick={() => handleSearch(searchQuery)}
          >
            🔍
          </button>
        )}
      </div>

      {/* Logout */}
      <button className="map-logout-btn" onClick={handleLogout} title="Çıkış Yap">
        🚪
      </button>

      {/* Filter chips */}
      <div className="filter-chips">
        {FILTER_CATEGORIES.map((cat) => (
          <button
            key={cat.key}
            className={`filter-chip ${activeFilter === cat.key ? 'active' : ''}`}
            onClick={() => setActiveFilter(cat.key)}
          >
            <span className="chip-icon">{cat.icon}</span>
            {cat.label}
          </button>
        ))}
      </div>

      {/* Search result banner */}
      {searchResultText && !showCamera && (
        <div className="search-result-banner">
          <span className="banner-icon">✨</span>
          <span className="banner-text">{searchResultText}</span>
          <button
            className="banner-close"
            onClick={() => setSearchResultText(null)}
          >
            ✕
          </button>
        </div>
      )}

      {/* FABs */}
      {!showCamera && (
        <div className={`fab-group ${isAnyCardVisible ? 'shifted' : ''}`}>
          <button
            className="fab-btn camera"
            title="AR Kamera"
            onClick={() => setShowCamera(true)}
          >
            📷
          </button>
          {isOrganizer && (
            <button
              className="fab-btn create-event"
              title="Etkinlik Oluştur"
              onClick={() => setShowCreateModal(true)}
            >
              ➕
            </button>
          )}
          <button
            className="fab-btn gps"
            title="Konumuma Git"
            onClick={focusUserLocation}
          >
            📍
          </button>
        </div>
      )}

      {/* ── Event Detail Card ── */}
      <div className={`bottom-card ${showEventCard ? 'visible' : ''}`}>
        {selectedEvent && (() => {
          const meta = getCategoryMeta(selectedEvent.category);
          return (
            <>
              <div className="event-card-header">
                <div
                  className="event-cat-icon"
                  style={{ background: `${meta.color}22` }}
                >
                  {meta.icon}
                </div>
                <div className="event-info">
                  <div className="event-title">{selectedEvent.title}</div>
                  <div className="event-category" style={{ color: meta.color }}>
                    {meta.displayName}
                  </div>
                </div>
                <button
                  className="card-close-btn"
                  onClick={() => setSelectedEvent(null)}
                >
                  ✕
                </button>
              </div>

              {selectedEvent.description && (
                <div className="event-description">
                  {selectedEvent.description}
                </div>
              )}

              <div className="event-participants">
                <span className="participant-count">
                  👥 {participants.length} kişi gidiyor
                </span>
                <button
                  className={`join-btn ${isGoing ? 'leave' : 'join'}`}
                  onClick={async () => {
                    if (isGoing) {
                      await leaveEvent(selectedEvent.id);
                    } else {
                      await joinEvent(selectedEvent.id);
                    }
                  }}
                >
                  {isGoing ? 'Vazgeç' : 'Gidiyorum'}
                </button>
              </div>

              <button
                className="navigate-btn"
                onClick={() => handleDrawRouteToEvent(selectedEvent)}
              >
                🧭 Oraya Git
              </button>
            </>
          );
        })()}
      </div>

      {/* ── Route Info Card ── */}
      <div
        className={`bottom-card ${showRouteCard ? 'visible' : ''}`}
        style={{ zIndex: showRouteCard ? 21 : 20 }}
      >
        {selectedDestination && routeDistance != null && (
          <>
            <div className="route-card-header">
              <div
                className="route-icon-circle"
                style={{
                  background: `${selectedDestination.color || '#7c6cf0'}22`,
                }}
              >
                🚩
              </div>
              <div className="route-info">
                <div className="route-label">Varış Noktası</div>
                <div className="route-name">{selectedDestination.name}</div>
              </div>
              <button
                className="card-close-btn"
                onClick={() => {
                  setSelectedDestination(null);
                  setRouteDistance(null);
                  setRouteDuration(null);
                  clearRoute();
                }}
              >
                ✕
              </button>
            </div>
            <div className="route-stats">
              <div className="route-stat">
                <span className="stat-icon" style={{ color: '#4ade80' }}>
                  🚶
                </span>
                <span className="stat-value">{formatDistance(routeDistance)}</span>
              </div>
              <div className="stat-divider" />
              <div className="route-stat">
                <span className="stat-icon" style={{ color: '#fb923c' }}>
                  ⏱️
                </span>
                <span className="stat-value">
                  {formatDuration(routeDuration)}
                </span>
              </div>
            </div>
          </>
        )}
      </div>

      {/* ── Empty State Card ── */}
      <div className={`bottom-card ${showEmptyState ? 'visible' : ''}`}>
        <div className="empty-state-content">
          <span className="empty-icon">☕</span>
          <div className="empty-info">
            <div className="empty-title">Bugün kampüste sakin bir gün var</div>
            <div className="empty-subtitle">
              {activeFilter} kategorisinde aktif etkinlik bulunamadı.
            </div>
          </div>
          <button
            className="card-close-btn"
            onClick={() => setActiveFilter('Tümü')}
          >
            ✕
          </button>
        </div>
      </div>

      {/* ── Create Event Modal ── */}
      {showCreateModal && (
        <div
          className="create-event-overlay"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowCreateModal(false);
          }}
        >
          <form className="create-event-modal" onSubmit={handleCreateEvent}>
            <h2>🎯 Yeni Etkinlik Oluştur</h2>

            <div className="form-group">
              <label>Etkinlik Adı</label>
              <input
                type="text"
                placeholder="Etkinlik başlığı"
                value={newEvent.title}
                onChange={(e) =>
                  setNewEvent({ ...newEvent, title: e.target.value })
                }
                required
              />
            </div>

            <div className="form-group">
              <label>Açıklama</label>
              <textarea
                placeholder="Etkinlik hakkında kısa bir açıklama..."
                value={newEvent.description}
                onChange={(e) =>
                  setNewEvent({ ...newEvent, description: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label>Kategori</label>
              <select
                value={newEvent.category}
                onChange={(e) =>
                  setNewEvent({ ...newEvent, category: e.target.value })
                }
              >
                <option value="seminer">📖 Seminer</option>
                <option value="spor">⚽ Spor</option>
                <option value="yemek">🍽️ Yemek</option>
                <option value="eglence">🎵 Eğlence</option>
              </select>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Enlem (Latitude)</label>
                <input
                  type="number"
                  step="any"
                  placeholder="38.6795"
                  value={newEvent.latitude}
                  onChange={(e) =>
                    setNewEvent({ ...newEvent, latitude: e.target.value })
                  }
                />
              </div>
              <div className="form-group">
                <label>Boylam (Longitude)</label>
                <input
                  type="number"
                  step="any"
                  placeholder="39.1995"
                  value={newEvent.longitude}
                  onChange={(e) =>
                    setNewEvent({ ...newEvent, longitude: e.target.value })
                  }
                />
              </div>
            </div>

            <div className="form-group">
              <label>Başlangıç Zamanı</label>
              <input
                type="datetime-local"
                value={newEvent.start_time}
                onChange={(e) =>
                  setNewEvent({ ...newEvent, start_time: e.target.value })
                }
                required
              />
            </div>

            <div className="modal-actions">
              <button
                type="button"
                className="cancel-btn"
                onClick={() => setShowCreateModal(false)}
              >
                İptal
              </button>
              <button
                type="submit"
                className="submit-btn"
                disabled={creatingEvent}
              >
                {creatingEvent ? 'Oluşturuluyor...' : 'Oluştur'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ── AR Camera Portal ── */}
      {showCamera && (
        <CameraView
          userPosition={userPosition}
          onClose={() => setShowCamera(false)}
        />
      )}
    </div>
  );
}
