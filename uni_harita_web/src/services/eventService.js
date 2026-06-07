import { supabase } from '../supabaseClient';

/**
 * Etkinlik kategorileri — Flutter EventCategory enum karşılığı
 */
export const EVENT_CATEGORIES = {
  seminer: { displayName: 'Seminer', icon: '📖', color: '#7c6cf0' },
  spor: { displayName: 'Spor', icon: '⚽', color: '#10B981' },
  yemek: { displayName: 'Yemek', icon: '🍽️', color: '#F59E0B' },
  eglence: { displayName: 'Eğlence', icon: '🎵', color: '#EC4899' },
};

export function getCategoryMeta(categoryName) {
  return EVENT_CATEGORIES[categoryName] || EVENT_CATEGORIES.seminer;
}

/**
 * Supabase'den bugünkü aktif etkinlikleri gerçek zamanlı dinler.
 * @param {Function} callback - Yeni etkinlik listesi geldiğinde çağrılır.
 * @returns {Function} unsubscribe fonksiyonu
 */
export function subscribeToActiveEvents(callback) {
  // İlk yükleme
  fetchActiveEvents().then(callback);

  // Realtime subscription
  const channel = supabase
    .channel('public:events')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'events' },
      () => {
        // Her değişiklikte taze veri çek
        fetchActiveEvents().then(callback);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}

/**
 * Bugünkü aktif etkinlikleri çeker
 */
export async function fetchActiveEvents() {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  try {
    const { data, error } = await supabase
      .from('events')
      .select('*')
      .eq('is_active', true)
      .gte('start_time', todayStart.toISOString())
      .order('start_time', { ascending: true });

    if (error) throw error;
    return data || [];
  } catch (e) {
    console.error('Fetch active events error:', e);
    return [];
  }
}

/**
 * Bir etkinliğe katıl
 */
export async function joinEvent(eventId) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return false;

    const { error } = await supabase.from('event_participants').insert({
      event_id: eventId,
      user_id: user.id,
    });

    return !error;
  } catch (e) {
    console.error('Join event error:', e);
    return false;
  }
}

/**
 * Bir etkinlikten ayrıl
 */
export async function leaveEvent(eventId) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return false;

    const { error } = await supabase
      .from('event_participants')
      .delete()
      .eq('event_id', eventId)
      .eq('user_id', user.id);

    return !error;
  } catch (e) {
    console.error('Leave event error:', e);
    return false;
  }
}

/**
 * Bir etkinliğin katılımcılarını gerçek zamanlı dinler
 * @returns {Function} unsubscribe fonksiyonu
 */
export function subscribeToParticipants(eventId, callback) {
  // İlk yükleme
  fetchParticipants(eventId).then(callback);

  const channel = supabase
    .channel(`participants:${eventId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'event_participants',
        filter: `event_id=eq.${eventId}`,
      },
      () => {
        fetchParticipants(eventId).then(callback);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}

async function fetchParticipants(eventId) {
  try {
    const { data, error } = await supabase
      .from('event_participants')
      .select('*')
      .eq('event_id', eventId);

    if (error) throw error;
    return data || [];
  } catch (e) {
    console.error('Fetch participants error:', e);
    return [];
  }
}
