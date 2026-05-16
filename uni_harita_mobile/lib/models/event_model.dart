import 'package:flutter/material.dart';

/// Etkinlik kategorileri
enum EventCategory {
  seminer,
  spor,
  yemek,
  eglence;

  String get displayName {
    switch (this) {
      case EventCategory.seminer:
        return 'Seminer';
      case EventCategory.spor:
        return 'Spor';
      case EventCategory.yemek:
        return 'Yemek';
      case EventCategory.eglence:
        return 'Eğlence';
    }
  }

  IconData get icon {
    switch (this) {
      case EventCategory.seminer:
        return Icons.menu_book_rounded;
      case EventCategory.spor:
        return Icons.sports_soccer;
      case EventCategory.yemek:
        return Icons.restaurant;
      case EventCategory.eglence:
        return Icons.music_note_rounded;
    }
  }

  Color get color {
    switch (this) {
      case EventCategory.seminer:
        return const Color(0xFF7c6cf0);
      case EventCategory.spor:
        return const Color(0xFF10B981);
      case EventCategory.yemek:
        return const Color(0xFFF59E0B);
      case EventCategory.eglence:
        return const Color(0xFFEC4899);
    }
  }

  static EventCategory fromString(String value) {
    return EventCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventCategory.seminer,
    );
  }
}

/// Supabase events tablosuna karşılık gelen model
class EventModel {
  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final double? latitude;
  final double? longitude;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final String? organizerId;
  final String? buildingId;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.title,
    this.description = '',
    this.category = EventCategory.seminer,
    this.latitude,
    this.longitude,
    required this.startTime,
    this.endTime,
    this.isActive = true,
    this.organizerId,
    this.buildingId,
    required this.createdAt,
  });

  /// Supabase JSON -> EventModel
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: EventCategory.fromString(json['category'] as String? ?? 'seminer'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      isActive: json['is_active'] as bool? ?? true,
      organizerId: json['organizer_id'] as String?,
      buildingId: json['building_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// EventModel -> Supabase JSON (insert/update)
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      'is_active': isActive,
      if (organizerId != null) 'organizer_id': organizerId,
      if (buildingId != null) 'building_id': buildingId,
    };
  }

  /// Konum bilgisi var mı?
  bool get hasLocation => latitude != null && longitude != null;
}
