import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart';

import '../models/campus_location.dart';
import '../models/event_model.dart';
import '../services/location_service.dart';
import '../services/event_service.dart';

class ArCameraScreen extends StatefulWidget {
  const ArCameraScreen({super.key});

  @override
  State<ArCameraScreen> createState() => _ArCameraScreenState();
}

class _ArCameraScreenState extends State<ArCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraReady = false;

  geo.Position? _currentPosition;
  double? _currentHeading; // compass heading (0-360)
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<geo.Position>? _positionSubscription;

  List<EventModel> _activeEvents = [];

  // Görüş açısı (derece)
  static const double _fieldOfView = 60.0;
  // Maksimum gösterim mesafesi (metre)
  static const double _maxDistance = 500.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSensors();
    _loadEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _initSensors() async {
    // Konum al
    final position = await LocationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() => _currentPosition = position);
    }

    // Konum stream
    _positionSubscription =
        LocationService.getPositionStream().listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    // Pusula stream (sadece mobil için)
    if (!kIsWeb) {
      _compassSubscription = FlutterCompass.events?.listen((event) {
        if (mounted && event.heading != null) {
          setState(() => _currentHeading = event.heading);
        }
      });
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await EventService.fetchActiveEvents();
      if (mounted) {
        setState(() => _activeEvents = events);
      }
    } catch (e) {
      debugPrint('Events load error: $e');
    }
  }

  /// İki koordinat arasındaki bearing (azimut) hesapla (derece)
  double _calculateBearing(
      double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final x = sin(dLng) * cos(lat2Rad);
    final y =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    final bearing = atan2(x, y);
    return (_toDegrees(bearing) + 360) % 360;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
  double _toDegrees(double radians) => radians * 180 / pi;

  /// Görüş açısındaki binaları hesapla
  List<_ArOverlayItem> _calculateVisibleItems() {
    if (kIsWeb) return [];
    if (_currentPosition == null || _currentHeading == null) return [];

    final items = <_ArOverlayItem>[];
    final userLat = _currentPosition!.latitude;
    final userLng = _currentPosition!.longitude;
    final heading = _currentHeading!;

    for (final location in CampusLocation.locations) {
      final distance = geo.Geolocator.distanceBetween(
        userLat,
        userLng,
        location.latitude,
        location.longitude,
      );

      if (distance > _maxDistance) continue;

      final bearing = _calculateBearing(
        userLat,
        userLng,
        location.latitude,
        location.longitude,
      );

      // Heading ile bearing arasındaki fark
      double diff = bearing - heading;
      // Normalize to -180..180
      while (diff > 180) {
        diff -= 360;
      }
      while (diff < -180) {
        diff += 360;
      }

      if (diff.abs() <= _fieldOfView / 2) {
        // Ekrandaki yatay pozisyonu hesapla (0.0 - 1.0)
        final horizontalPosition = 0.5 + (diff / _fieldOfView);

        // Bu binada aktif etkinlik var mı?
        final relatedEvents = _activeEvents.where((e) {
          if (!e.hasLocation) return false;
          final eventDist = geo.Geolocator.distanceBetween(
            location.latitude,
            location.longitude,
            e.latitude!,
            e.longitude!,
          );
          return eventDist < 50; // 50m yakınındaki etkinlikler
        }).toList();

        items.add(_ArOverlayItem(
          location: location,
          distance: distance,
          horizontalPosition: horizontalPosition,
          events: relatedEvents,
        ));
      }
    }

    // Mesafeye göre sırala (yakınlar önce)
    items.sort((a, b) => a.distance.compareTo(b.distance));
    return items;
  }

  Widget _buildArOverlay(_ArOverlayItem item, double screenWidth) {
    final leftPosition = item.horizontalPosition * screenWidth - 90;
    // Mesafeye göre boyut (yakınlar daha büyük)
    final scale = 1.0 - (item.distance / _maxDistance) * 0.4;
    final distanceText = item.distance < 1000
        ? '${item.distance.toInt()}m'
        : '${(item.distance / 1000).toStringAsFixed(1)}km';

    return Positioned(
      left: leftPosition.clamp(8.0, screenWidth - 196.0),
      top: 140 + (item.distance / _maxDistance) * 200,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value * scale,
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          width: 188,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.location.color.withAlpha(150),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: item.location.color.withAlpha(60),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.location.color.withAlpha(80),
                        item.location.color.withAlpha(30),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.location.icon,
                          color: item.location.color, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.location.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Mesafe
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        distanceText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.location.color.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.location.category,
                          style: TextStyle(
                            color: item.location.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Etkinlikler
                if (item.events.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      border: Border(
                        top: BorderSide(color: Colors.white.withAlpha(20)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: item.events.take(2).map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(event.category.icon,
                                  size: 12, color: event.category.color),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompassIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: _currentHeading != null
                    ? -_toRadians(_currentHeading!)
                    : 0,
                child: const Icon(Icons.navigation,
                    color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                _currentHeading != null
                    ? '${_currentHeading!.toInt()}° ${_getDirectionName(_currentHeading!)}'
                    : 'Pusula bekleniyor...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDirectionName(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'K';
    if (heading >= 22.5 && heading < 67.5) return 'KD';
    if (heading >= 67.5 && heading < 112.5) return 'D';
    if (heading >= 112.5 && heading < 157.5) return 'GD';
    if (heading >= 157.5 && heading < 202.5) return 'G';
    if (heading >= 202.5 && heading < 247.5) return 'GB';
    if (heading >= 247.5 && heading < 292.5) return 'B';
    return 'KB';
  }

  Widget _buildWebOverlayList(double screenWidth) {
    final userLat = _currentPosition?.latitude ?? 38.6795;
    final userLng = _currentPosition?.longitude ?? 39.1995;
    
    final items = <_ArOverlayItem>[];
    for (final location in CampusLocation.locations) {
      final distance = geo.Geolocator.distanceBetween(
        userLat,
        userLng,
        location.latitude,
        location.longitude,
      );
      
      if (distance > _maxDistance) continue;
      
      final relatedEvents = _activeEvents.where((e) {
        if (!e.hasLocation) return false;
        final eventDist = geo.Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          e.latitude!,
          e.longitude!,
        );
        return eventDist < 50; // 50m yakınındaki etkinlikler
      }).toList();
      
      items.add(_ArOverlayItem(
        location: location,
        distance: distance,
        horizontalPosition: 0.0,
        events: relatedEvents,
      ));
    }
    
    items.sort((a, b) => a.distance.compareTo(b.distance));
    
    if (items.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('Yakında kampüs lokasyonu bulunamadı', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final distanceText = item.distance < 1000
            ? '${item.distance.toInt()}m'
            : '${(item.distance / 1000).toStringAsFixed(1)}km';
            
        return Container(
          width: 220,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.location.color.withAlpha(150),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: item.location.color.withAlpha(60),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.location.color.withAlpha(100),
                        item.location.color.withAlpha(40),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.location.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.location.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.straighten, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(distanceText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.location.color.withAlpha(60),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.location.category,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (item.events.isNotEmpty) ...[
                        const Text('Aktif Etkinlikler:', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...item.events.take(1).map((event) {
                          return Row(
                            children: [
                              Icon(event.category.icon, size: 12, color: event.category.color),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                               ),
                            ],
                          );
                        }).toList(),
                      ] else ...[
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white30),
                            SizedBox(width: 4),
                            Text('Planlı etkinlik yok', style: TextStyle(color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final visibleItems = _calculateVisibleItems();

    final visibleItemsCount = kIsWeb
        ? CampusLocation.locations.where((loc) {
            final userLat = _currentPosition?.latitude ?? 38.6795;
            final userLng = _currentPosition?.longitude ?? 39.1995;
            final distance = geo.Geolocator.distanceBetween(userLat, userLng, loc.latitude, loc.longitude);
            return distance <= _maxDistance;
          }).length
        : visibleItems.length;

    final visibleEventsCount = kIsWeb
        ? _activeEvents.where((e) {
            if (!e.hasLocation) return false;
            final userLat = _currentPosition?.latitude ?? 38.6795;
            final userLng = _currentPosition?.longitude ?? 39.1995;
            final distance = geo.Geolocator.distanceBetween(userLat, userLng, e.latitude!, e.longitude!);
            return distance <= _maxDistance;
          }).length
        : visibleItems.fold<int>(0, (sum, item) => sum + item.events.length);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera Preview
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Positioned.fill(
              child: _ArCameraShimmer(),
            ),

          // AR Overlay Etiketler
          ...visibleItems
              .map((item) => _buildArOverlay(item, screenWidth)),

          // Pusula Göstergesi (sadece mobil için)
          if (!kIsWeb) _buildCompassIndicator(),

          // Web Kampüs Kartları Overlay (Sadece Web için)
          if (kIsWeb)
            Positioned(
              bottom: 100 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              height: 160,
              child: _buildWebOverlayList(screenWidth),
            ),

          // Geri Butonu
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Alt bilgi çubuğu
          Positioned(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$visibleItemsCount bina görüş alanında',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.event, color: Colors.white54, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$visibleEventsCount etkinlik',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArCameraShimmer extends StatelessWidget {
  const _ArCameraShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1A),
      child: Stack(
        children: [
          // Center focus viewfinder
          Center(
            child: Shimmer.fromColors(
              baseColor: Colors.white.withAlpha(10),
              highlightColor: Colors.white.withAlpha(30),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Center(
                  child: Icon(Icons.center_focus_weak, size: 48, color: Colors.white),
                ),
              ),
            ),
          ),
          // Top compass skeleton card
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 60,
            right: 60,
            child: Shimmer.fromColors(
              baseColor: Colors.white.withAlpha(10),
              highlightColor: Colors.white.withAlpha(30),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          // Bottom stats card skeleton
          Positioned(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: Shimmer.fromColors(
              baseColor: Colors.white.withAlpha(10),
              highlightColor: Colors.white.withAlpha(30),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AR Overlay'de gösterilecek eleman
class _ArOverlayItem {
  final CampusLocation location;
  final double distance; // metre
  final double horizontalPosition; // 0.0 - 1.0 (ekrandaki konum)
  final List<EventModel> events;

  const _ArOverlayItem({
    required this.location,
    required this.distance,
    required this.horizontalPosition,
    this.events = const [],
  });
}
