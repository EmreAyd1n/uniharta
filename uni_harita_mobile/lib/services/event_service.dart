import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';

class EventService {
  static final _client = Supabase.instance.client;

  /// Bugünkü aktif etkinlikleri çeker
  static Future<List<EventModel>> fetchActiveEvents() async {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();

    final response = await _client
        .from('events')
        .select()
        .eq('is_active', true)
        .gte('start_time', todayStart)
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Kategoriye göre aktif etkinlikleri çeker
  static Future<List<EventModel>> fetchEventsByCategory(String category) async {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();

    final response = await _client
        .from('events')
        .select()
        .eq('is_active', true)
        .eq('category', category)
        .gte('start_time', todayStart)
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
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
      print('Event create error: $e');
      return null;
    }
  }

  /// Tüm aktif etkinlikleri çeker (filtre olmadan)
  static Future<List<EventModel>> fetchAllEvents() async {
    final response = await _client
        .from('events')
        .select()
        .eq('is_active', true)
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
