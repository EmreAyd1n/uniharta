/**
 * Mapbox Directions API ile yürüyüş rotası hesapla
 * @returns {{ geometry, distance, duration }} veya null
 */
export async function getWalkingRoute(startLng, startLat, endLng, endLat) {
  const token = import.meta.env.VITE_MAPBOX_ACCESS_TOKEN || '';
  if (!token) return null;

  const url =
    `https://api.mapbox.com/directions/v5/mapbox/walking/` +
    `${startLng},${startLat};${endLng},${endLat}` +
    `?geometries=geojson&access_token=${token}`;

  try {
    const response = await fetch(url);
    if (!response.ok) return null;

    const data = await response.json();
    if (data.routes && data.routes.length > 0) {
      const route = data.routes[0];
      return {
        geometry: route.geometry,
        distance: route.distance,
        duration: route.duration,
      };
    }
  } catch (e) {
    console.error('Route fetch error:', e);
  }

  return null;
}
