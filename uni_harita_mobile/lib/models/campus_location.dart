import 'package:flutter/material.dart';

class CampusLocation {
  final String name;
  final double latitude;
  final double longitude;
  final Color color;
  final String category;

  const CampusLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.color,
    this.category = 'Fakülte',
  });

  static const List<CampusLocation> locations = [
    CampusLocation(
      name: 'Teknoloji Fakültesi',
      latitude: 38.6795,
      longitude: 39.1995,
      color: Color(0xFF7c6cf0),
      category: 'Fakülte',
    ),
    CampusLocation(
      name: 'Rektörlük',
      latitude: 38.6812,
      longitude: 39.1960,
      color: Color(0xFFF59E0B),
      category: 'İdari',
    ),
    CampusLocation(
      name: 'Kütüphane',
      latitude: 38.6790,
      longitude: 39.1950,
      color: Color(0xFF3B82F6),
      category: 'Sosyal',
    ),
    CampusLocation(
      name: 'Mühendislik Fakültesi',
      latitude: 38.6805,
      longitude: 39.2010,
      color: Color(0xFF10B981),
      category: 'Fakülte',
    ),
    CampusLocation(
      name: 'Öğrenci İşleri',
      latitude: 38.6820,
      longitude: 39.1940,
      color: Color(0xFFEC4899),
      category: 'İdari',
    ),
  ];
}
