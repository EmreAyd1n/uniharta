import 'package:flutter/material.dart';

class CampusLocation {
  final String name;
  final double latitude;
  final double longitude;
  final Color color;
  final String category;
  final IconData icon;

  const CampusLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.color,
    this.category = 'Fakülte',
    this.icon = Icons.location_on,
  });

  static const List<CampusLocation> locations = [
    CampusLocation(
      name: 'Teknoloji Fakültesi',
      latitude: 38.6795,
      longitude: 39.1995,
      color: Color(0xFF7c6cf0),
      category: 'Fakülte',
      icon: Icons.computer,
    ),
    CampusLocation(
      name: 'Rektörlük',
      latitude: 38.6812,
      longitude: 39.1960,
      color: Color(0xFFF59E0B),
      category: 'İdari',
      icon: Icons.account_balance,
    ),
    CampusLocation(
      name: 'Kütüphane',
      latitude: 38.6790,
      longitude: 39.1950,
      color: Color(0xFF3B82F6),
      category: 'Kütüphane',
      icon: Icons.local_library,
    ),
    CampusLocation(
      name: 'Mühendislik Fakültesi',
      latitude: 38.6805,
      longitude: 39.2010,
      color: Color(0xFF10B981),
      category: 'Fakülte',
      icon: Icons.engineering,
    ),
    CampusLocation(
      name: 'Öğrenci İşleri',
      latitude: 38.6820,
      longitude: 39.1940,
      color: Color(0xFFEC4899),
      category: 'İdari',
      icon: Icons.assignment_ind,
    ),
    CampusLocation(
      name: 'Yemekhane',
      latitude: 38.6800,
      longitude: 39.1970,
      color: Color(0xFFFF6B35),
      category: 'Yemek',
      icon: Icons.restaurant,
    ),
    CampusLocation(
      name: 'Spor Salonu',
      latitude: 38.6815,
      longitude: 39.2000,
      color: Color(0xFF06D6A0),
      category: 'Spor',
      icon: Icons.sports_soccer,
    ),
    CampusLocation(
      name: 'Kantin',
      latitude: 38.6798,
      longitude: 39.1980,
      color: Color(0xFFFFD166),
      category: 'Yemek',
      icon: Icons.coffee,
    ),
    CampusLocation(
      name: 'Konferans Salonu',
      latitude: 38.6808,
      longitude: 39.1975,
      color: Color(0xFF8338EC),
      category: 'Seminer',
      icon: Icons.mic,
    ),
  ];

  /// Gemini kategorisine göre eşleşen lokasyonları filtrele
  static List<CampusLocation> filterByGeminiCategory(String geminiCategory) {
    final Map<String, List<String>> categoryMap = {
      'yemek': ['Yemek'],
      'spor': ['Spor'],
      'seminer': ['Seminer'],
      'eglence': ['Eğlence'],
      'kutuphane': ['Kütüphane'],
      'idari': ['İdari'],
      'fakulte': ['Fakülte'],
    };

    final matchingCategories = categoryMap[geminiCategory] ?? [];
    if (matchingCategories.isEmpty) return locations;

    return locations
        .where((loc) => matchingCategories.contains(loc.category))
        .toList();
  }
}
