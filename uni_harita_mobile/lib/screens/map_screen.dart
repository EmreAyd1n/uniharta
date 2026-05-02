import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Fırat Üniversitesi merkez koordinatları
  static const double _latitude = 38.6800;
  static const double _longitude = 39.1985;
  static const double _zoom = 16.5;

  MapboxMap? _mapboxMap;

  // Kampüs üzerindeki önemli noktalar
  static const List<Map<String, dynamic>> _campusLocations = [
    {
      'name': 'Teknoloji Fakültesi',
      'lat': 38.6795,
      'lng': 39.1995,
      'color': Color(0xFF7c6cf0),
    },
    {
      'name': 'Rektörlük',
      'lat': 38.6812,
      'lng': 39.1960,
      'color': Color(0xFFF59E0B),
    },
    {
      'name': 'Kütüphane',
      'lat': 38.6790,
      'lng': 39.1950,
      'color': Color(0xFF3B82F6),
    },
    {
      'name': 'Mühendislik Fakültesi',
      'lat': 38.6805,
      'lng': 39.2010,
      'color': Color(0xFF10B981),
    },
  ];

  @override
  void initState() {
    super.initState();
    // Access token'ı .env'den oku ve Mapbox'a ayarla
    final accessToken = dotenv.get('MAPBOX_ACCESS_TOKEN');
    MapboxOptions.setAccessToken(accessToken);
  }

  /// Harita oluşturulduğunda çağrılır
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _addMarkers();
  }

  /// Programatik olarak marker ikonu oluşturur (asset gerektirmez)
  Future<Uint8List> _createMarkerIcon(Color color) async {
    const int size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Dış gölge dairesi
    final shadowPaint = Paint()
      ..color = color.withAlpha(60)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, shadowPaint);

    // Ana daire
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.8, mainPaint);

    // İç beyaz nokta
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 7, innerPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Tüm kampüs noktalarını haritaya ekler
  Future<void> _addMarkers() async {
    if (_mapboxMap == null) return;

    final annotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();

    for (final location in _campusLocations) {
      final iconBytes = await _createMarkerIcon(location['color'] as Color);

      final options = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            location['lng'] as double,
            location['lat'] as double,
          ),
        ),
        image: iconBytes,
        iconSize: 0.45,
        textField: location['name'] as String,
        textSize: 12.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, 2.0],
      );

      await annotationManager.create(options);
    }
  }

  /// Supabase oturumunu kapatır ve giriş ekranına yönlendirir
  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    // Navigation is now handled by AuthWrapper
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Harita
          MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_longitude, _latitude)),
              zoom: _zoom,
            ),
            styleUri: MapboxStyles.DARK,
          ),

          // Çıkış Yap butonu — sol üst köşe
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleLogout,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A2E), // koyu yarı-saydam arka plan
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.red.withAlpha(100),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(120),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, size: 18, color: Color(0xFFFCA5A5)),
                      SizedBox(width: 8),
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
