import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import 'local_database_service.dart';
import 'package:flutter/foundation.dart';

class EventService {
  static final _client = Supabase.instance.client;

  /// Bugünkü aktif etkinlikleri çeker
  static Future<List<EventModel>> fetchActiveEvents() async {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();

    try {
      final response = await _client
          .from('events')
          .select()
          .eq('is_active', true)
          .gte('start_time', todayStart)
          .order('start_time', ascending: true);

      final events = (response as List)
          .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
          .toList();
          
      // Cache'e kaydet
      if (!kIsWeb) {
        await LocalDatabaseService().cacheEvents(events);
      }
      return events;
    } catch (e) {
      debugPrint('Fetch active events error: $e');
      if (!kIsWeb) {
        return await LocalDatabaseService().getCachedEvents();
      }
      return [];
    }
  }

  /// Kategoriye göre aktif etkinlikleri çeker
  static Future<List<EventModel>> fetchEventsByCategory(String category) async {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();

    try {
      final response = await _client
          .from('events')
          .select()
          .eq('is_active', true)
          .eq('category', category)
          .gte('start_time', todayStart)
          .order('start_time', ascending: true);

      final events = (response as List)
          .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
          .toList();
          
      if (!kIsWeb) {
        await LocalDatabaseService().cacheEvents(events);
      }
      return events;
    } catch (e) {
      debugPrint('Fetch events by category error: $e');
      if (!kIsWeb) {
        return await LocalDatabaseService().getCachedEvents(category: category);
      }
      return [];
    }
  }

  /// Yeni etkinlik oluşturur
  static Future<EventModel?> createEvent(EventModel event) async {
    try {
      final response = await _client
          .from('events')
          .insert(event.toJson())
          .select()
          .single();

      return EventModel.fromJson(response);
    } catch (e) {
      debugPrint('Event create error: $e');
      return null;
    }
  }

  /// Tüm aktif etkinlikleri çeker (filtre olmadan)
  static Future<List<EventModel>> fetchAllEvents() async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('is_active', true)
          .order('start_time', ascending: true);

      final events = (response as List)
          .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
          .toList();
          
      if (!kIsWeb) {
        await LocalDatabaseService().cacheEvents(events);
      }
      return events;
    } catch (e) {
      debugPrint('Fetch all events error: $e');
      if (!kIsWeb) {
        return await LocalDatabaseService().getCachedEvents();
      }
      return [];
    }
  }

  /// Gerçek zamanlı aktif etkinlikleri dinler
static Stream<List<EventModel>> streamActiveEvents() async* {
  final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  
  // 1. Önce önbellekten verileri anında gönder (Offline fallback ve hızlı açılış için)
  if (!kIsWeb) {
    try {
      final cachedEvents = await LocalDatabaseService().getCachedEvents();
      if (cachedEvents.isNotEmpty) {
        yield cachedEvents;
      }
    } catch (_) {}
  }

  // 2. Supabase Realtime Stream başlat
  try {
    yield* _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('is_active', true) // Supabase Stream sadece 'eq' destekler
        .map((maps) {
          // 1. Gelen ham verileri EventModel listesine çeviriyoruz
          final events = maps.map((map) => EventModel.fromJson(map)).toList();
          
          // 2. [gte] yerine: Bugünün başlangıcından sonraki etkinlikleri Dart ile filtreliyoruz
          final filteredEvents = events.where((event) => 
            event.startTime.isAfter(todayStart) || event.startTime.isAtSameMomentAs(todayStart)
          ).toList();
          
          // 3. [order] yerine: Etkinlikleri tarihe göre yakından uzağa sıralıyoruz
          filteredEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
          
          // 4. Arka planda sessizce önbelleğe kaydet
          if (!kIsWeb) {
            LocalDatabaseService().cacheEvents(filteredEvents);
          }
          
          return filteredEvents;
        });
  } catch (e) {
    debugPrint('Supabase stream error: $e');
    // Hata olursa stream kapanır, UI son cache edilen veriyle devam eder.
  }
}

  /// Bir etkinliğe katıl
  static Future<bool> joinEvent(String eventId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('event_participants').insert({
        'event_id': eventId,
        'user_id': user.id,
      });
      return true;
    } catch (e) {
      debugPrint('Join event error: $e');
      return false;
    }
  }

  /// Bir etkinlikten ayrıl
  static Future<bool> leaveEvent(String eventId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client
          .from('event_participants')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      debugPrint('Leave event error: $e');
      return false;
    }
  }

  /// Bir etkinliğe katılıp katılmadığını kontrol et
  static Future<bool> checkParticipation(String eventId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      final response = await _client
          .from('event_participants')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Gerçek zamanlı olarak katılımcıları dinler (sayı vs. için)
  static Stream<List<Map<String, dynamic>>> streamEventParticipants(String eventId) {
    return _client
        .from('event_participants')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId);
  }
}
