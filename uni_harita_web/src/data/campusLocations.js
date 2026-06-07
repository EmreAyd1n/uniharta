/**
 * Kampüs lokasyonları — Flutter CampusLocation.locations'ın JS karşılığı
 */
export const campusLocations = [
  {
    name: 'Teknoloji Fakültesi',
    latitude: 38.6795,
    longitude: 39.1995,
    color: '#7c6cf0',
    category: 'Fakülte',
    icon: '💻',
  },
  {
    name: 'Rektörlük',
    latitude: 38.6812,
    longitude: 39.1960,
    color: '#F59E0B',
    category: 'İdari',
    icon: '🏛️',
  },
  {
    name: 'Kütüphane',
    latitude: 38.6790,
    longitude: 39.1950,
    color: '#3B82F6',
    category: 'Kütüphane',
    icon: '📚',
  },
  {
    name: 'Mühendislik Fakültesi',
    latitude: 38.6805,
    longitude: 39.2010,
    color: '#10B981',
    category: 'Fakülte',
    icon: '⚙️',
  },
  {
    name: 'Öğrenci İşleri',
    latitude: 38.6820,
    longitude: 39.1940,
    color: '#EC4899',
    category: 'İdari',
    icon: '📋',
  },
  {
    name: 'Yemekhane',
    latitude: 38.6800,
    longitude: 39.1970,
    color: '#FF6B35',
    category: 'Yemek',
    icon: '🍽️',
  },
  {
    name: 'Spor Salonu',
    latitude: 38.6815,
    longitude: 39.2000,
    color: '#06D6A0',
    category: 'Spor',
    icon: '⚽',
  },
  {
    name: 'Kantin',
    latitude: 38.6798,
    longitude: 39.1980,
    color: '#FFD166',
    category: 'Yemek',
    icon: '☕',
  },
  {
    name: 'Konferans Salonu',
    latitude: 38.6808,
    longitude: 39.1975,
    color: '#8338EC',
    category: 'Seminer',
    icon: '🎤',
  },
];

/**
 * Gemini kategorisine göre eşleşen lokasyonları filtrele
 */
const categoryMap = {
  yemek: ['Yemek'],
  spor: ['Spor'],
  seminer: ['Seminer'],
  eglence: ['Eğlence'],
  kutuphane: ['Kütüphane'],
  idari: ['İdari'],
  fakulte: ['Fakülte'],
};

export function filterByGeminiCategory(geminiCategory) {
  const matching = categoryMap[geminiCategory] || [];
  if (matching.length === 0) return campusLocations;
  return campusLocations.filter((loc) => matching.includes(loc.category));
}
