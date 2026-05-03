import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapboxRouteService {
  static Future<Map<String, dynamic>?> getWalkingRoute(Position start, Position end) async {
    final token = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');
    if (token.isEmpty) {
      return null;
    }

    // Mapbox Directions API expects coordinates in {longitude},{latitude} format
    final String url = 'https://api.mapbox.com/directions/v5/mapbox/walking/'
        '${start.lng},${start.lat};${end.lng},${end.lat}'
        '?geometries=geojson&access_token=$token';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          return {
            'geometry': route['geometry'] as Map<String, dynamic>,
            'distance': route['distance'] as num,
            'duration': route['duration'] as num,
          };
        }
      }
    } catch (e) {
      print('Route fetch error: $e');
    }

    return null;
  }
}
