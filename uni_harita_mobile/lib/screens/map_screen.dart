import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campus_location.dart';
import '../services/mapbox_route_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Fırat Üniversitesi merkez koordinatları (Teknoloji Fakültesi)
  static const double _latitude = 38.6795;
  static const double _longitude = 39.1995;
  static const double _zoom = 16.5;

  MapboxMap? _mapboxMap;

  CampusLocation? _selectedDestination;
  num? _routeDistance;
  num? _routeDuration;

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

    for (final location in CampusLocation.locations) {
      final iconBytes = await _createMarkerIcon(location.color);

      final options = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            location.longitude,
            location.latitude,
          ),
        ),
        image: iconBytes,
        iconSize: 0.45,
        textField: location.name,
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
  }

  /// Haritaya rota çizer
  Future<void> _drawRoute(CampusLocation destination) async {
    if (_mapboxMap == null) return;

    setState(() {
      _selectedDestination = destination;
      _routeDistance = null;
      _routeDuration = null;
    });

    // Başlangıç (Teknoloji Fakültesi)
    final start = Position(_longitude, _latitude);
    // Hedef
    final end = Position(destination.longitude, destination.latitude);

    final routeData = await MapboxRouteService.getWalkingRoute(start, end);

    if (routeData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota hesaplanamadı')),
        );
      }
      return;
    }

    final geoJsonGeometry = routeData['geometry'];
    final distance = routeData['distance'] as num;
    final duration = routeData['duration'] as num;

    try {
      // Önce varsa eski rotayı temizleyelim
      try {
        await _mapboxMap!.style.removeStyleLayer('route-layer');
        await _mapboxMap!.style.removeStyleSource('route-source');
      } catch (_) {}

      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: "route-source",
        data: jsonEncode({
          "type": "Feature",
          "properties": {},
          "geometry": geoJsonGeometry
        }),
      ));

      await _mapboxMap!.style.addLayer(LineLayer(
        id: "route-layer",
        sourceId: "route-source",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineColor: const Color(0xFF800000).toARGB32(), // Fırat Üniversitesi bordosu
        lineWidth: 6.0,
      ));

      // Kamerayı otomatik olarak ayarla
      try {
        final minLat = start.lat < end.lat ? start.lat : end.lat;
        final maxLat = start.lat > end.lat ? start.lat : end.lat;
        final minLng = start.lng < end.lng ? start.lng : end.lng;
        final maxLng = start.lng > end.lng ? start.lng : end.lng;

        final bounds = CoordinateBounds(
            southwest: Point(coordinates: Position(minLng, minLat)),
            northeast: Point(coordinates: Position(maxLng, maxLat)),
            infiniteBounds: false);
            
        final cameraOptions = await _mapboxMap!.cameraForCoordinateBounds(
            bounds,
            MbxEdgeInsets(top: 150.0, left: 80.0, bottom: 300.0, right: 80.0), // alt kısma kart için daha fazla boşluk
            null,
            null,
            null,
            null);
            
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(duration: 1200));
      } catch (e) {
        print('Camera adjust error: $e');
      }

      if (mounted) {
        setState(() {
          _routeDistance = distance;
          _routeDuration = duration;
        });
      }

    } catch (e) {
      print('Route drawing error: $e');
    }
  }

  void _showDestinationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Hedef Seçin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: CampusLocation.locations.length,
                  itemBuilder: (context, index) {
                    final location = CampusLocation.locations[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: location.color.withAlpha(50),
                        child: Icon(Icons.location_on, color: location.color),
                      ),
                      title: Text(location.name),
                      subtitle: Text(location.category),
                      onTap: () {
                        Navigator.pop(context); // Bottom sheet'i kapat
                        _drawRoute(location); // Rotayı çizmeye başla
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoOverlay() {
    if (_selectedDestination == null || _routeDistance == null || _routeDuration == null) {
      return const SizedBox.shrink();
    }

    final distanceText = _routeDistance! < 1000
        ? '${_routeDistance!.toInt()} Metre'
        : '${(_routeDistance! / 1000).toStringAsFixed(1)} KM';

    final durationText = '${(_routeDuration! / 60).ceil()} Dakika';

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1E1E2C), // Koyu şık arkaplan
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _selectedDestination!.color.withAlpha(50),
                    child: Icon(Icons.flag, color: _selectedDestination!.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Varış Noktası',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Text(
                          _selectedDestination!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedDestination = null;
                      });
                      _mapboxMap?.style.removeStyleLayer('route-layer').catchError((_) {});
                      _mapboxMap?.style.removeStyleSource('route-source').catchError((_) {});
                    },
                  )
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: Colors.white24, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_walk, color: Colors.greenAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        distanceText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.white24,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.orangeAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        durationText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

          // Search Butonu - Sol üst
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showDestinationPicker,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A2E), // Koyu yarı saydam arkaplan
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.blue.withAlpha(100),
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
                      Icon(Icons.search, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        'Hedef Ara',
                        style: TextStyle(
                          color: Colors.blueAccent,
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

          // Çıkış Yap butonu — sağ üst
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
                        'Çıkış',
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

          // Info Overlay (Eğer rota varsa görünür)
          _buildInfoOverlay(),
        ],
      ),
    );
  }
}
