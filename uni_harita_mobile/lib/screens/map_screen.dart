import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_location.dart';
import '../models/event_model.dart';
import '../services/mapbox_route_service.dart';
import '../services/location_service.dart';
import '../services/event_service.dart';
import '../services/gemini_service.dart';
import 'ar_camera_screen.dart';
import 'create_event_screen.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _latitude = 38.6795;
  static const double _longitude = 39.1995;
  static const double _zoom = 16.5;

  MapboxMap? _mapboxMap;
  CampusLocation? _selectedDestination;
  num? _routeDistance;
  num? _routeDuration;
  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStreamSubscription;

  // Yeni state'ler
  List<EventModel> _events = [];
  String _activeFilter = 'Tümü';
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchResultText;
  EventModel? _selectedEvent;
  
  bool _isOrganizer = false;
  StreamSubscription<List<EventModel>>? _eventsSubscription;
  PointAnnotationManager? _eventAnnotationManager;

  final List<String> _filterCategories = [
    'Tümü', 'Seminer', 'Spor', 'Yemek', 'Eğlence'
  ];

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final accessToken = dotenv.get('MAPBOX_ACCESS_TOKEN');
    MapboxOptions.setAccessToken(accessToken);
    _checkUserRole();
    _startEventsStream();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client.from('profiles').select('user_type').eq('id', user.id).single();
      if (mounted) setState(() => _isOrganizer = data['user_type'] == 'organizator');
    } catch (_) {
      final user = Supabase.instance.client.auth.currentUser;
      if (mounted && user != null) {
        setState(() => _isOrganizer = user.userMetadata?['user_type'] == 'organizator');
      }
    }
  }

  void _startEventsStream() {
    _eventsSubscription = EventService.streamActiveEvents().listen((events) {
      if (!mounted) return;
      if (_events.isNotEmpty && events.length > _events.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [const Icon(Icons.celebration, color: Colors.white), const SizedBox(width: 8), const Text('Yeni bir etkinlik eklendi!')]),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
      setState(() => _events = events);
      _addEventMarkers();
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _addMarkers();
    await _addEventMarkers();
    if (!mounted) return;
    final hasPermission = await LocationService.checkAndRequestPermissions(context);
    if (hasPermission) _enableLocationTracking();
  }

  void _enableLocationTracking() async {
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true, pulsingEnabled: true,
      ));
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() => _currentPosition = position);
      }
      _positionStreamSubscription = LocationService.getPositionStream().listen((geo.Position position) {
        if (!mounted) return;
        setState(() => _currentPosition = position);
        if (_selectedDestination != null) _drawRoute(_selectedDestination!);
      });
    } catch (e) {
      debugPrint('Location tracking error: $e');
    }
  }

  void _focusOnUserLocation() {
    if (_mapboxMap == null || _currentPosition == null) return;
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude)),
        zoom: _zoom,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<Uint8List> _createMarkerIcon(Color color) async {
    const int size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final shadowPaint = Paint()..color = color.withAlpha(60)..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, shadowPaint);
    final mainPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.8, mainPaint);
    final innerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 7, innerPaint);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null) return;
    final annotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    for (final location in CampusLocation.locations) {
      final iconBytes = await _createMarkerIcon(location.color);
      await annotationManager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(location.longitude, location.latitude)),
        image: iconBytes, iconSize: 0.45,
        textField: location.name, textSize: 12.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5, textOffset: [0.0, 2.0],
      ));
    }
  }

  Future<void> _addEventMarkers() async {
    if (_mapboxMap == null) return;
    if (_eventAnnotationManager == null) {
      _eventAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    } else {
      await _eventAnnotationManager!.deleteAll();
    }
    for (final event in _events) {
      if (!event.hasLocation) continue;
      if (_activeFilter != 'Tümü' && event.category.displayName != _activeFilter) continue;
      final iconBytes = await _createMarkerIcon(event.category.color);
      await _eventAnnotationManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(event.longitude!, event.latitude!)),
        image: iconBytes, iconSize: 0.5,
        textField: '🎯 ${event.title}', textSize: 11.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5, textOffset: [0.0, 2.5],
      ));
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _drawRoute(CampusLocation destination) async {
    if (_mapboxMap == null) return;
    setState(() {
      _selectedDestination = destination;
      _routeDistance = null; _routeDuration = null;
    });
    final start = _currentPosition != null
        ? Position(_currentPosition!.longitude, _currentPosition!.latitude)
        : Position(_longitude, _latitude);
    final end = Position(destination.longitude, destination.latitude);
    final routeData = await MapboxRouteService.getWalkingRoute(start, end);
    if (routeData == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota hesaplanamadı')));
      return;
    }
    final geoJsonGeometry = routeData['geometry'];
    final distance = routeData['distance'] as num;
    final duration = routeData['duration'] as num;
    try {
      try {
        await _mapboxMap!.style.removeStyleLayer('route-layer');
        await _mapboxMap!.style.removeStyleSource('route-source');
      } catch (_) {}
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: "route-source",
        data: jsonEncode({"type": "Feature", "properties": {}, "geometry": geoJsonGeometry}),
      ));
      await _mapboxMap!.style.addLayer(LineLayer(
        id: "route-layer", sourceId: "route-source",
        lineJoin: LineJoin.ROUND, lineCap: LineCap.ROUND,
        lineColor: const Color(0xFF800000).toARGB32(), lineWidth: 6.0,
      ));
      try {
        final minLat = start.lat < end.lat ? start.lat : end.lat;
        final maxLat = start.lat > end.lat ? start.lat : end.lat;
        final minLng = start.lng < end.lng ? start.lng : end.lng;
        final maxLng = start.lng > end.lng ? start.lng : end.lng;
        final bounds = CoordinateBounds(
          southwest: Point(coordinates: Position(minLng, minLat)),
          northeast: Point(coordinates: Position(maxLng, maxLat)),
          infiniteBounds: false,
        );
        final cameraOptions = await _mapboxMap!.cameraForCoordinateBounds(
          bounds, MbxEdgeInsets(top: 150.0, left: 80.0, bottom: 300.0, right: 80.0),
          null, null, null, null,
        );
        await _mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1200));
      } catch (e) { print('Camera adjust error: $e'); }
      if (mounted) setState(() { _routeDistance = distance; _routeDuration = duration; });
    } catch (e) { print('Route drawing error: $e'); }
  }

  Future<void> _drawRouteToEvent(EventModel event) async {
    if (!event.hasLocation) return;
    final tempLocation = CampusLocation(
      name: event.title, latitude: event.latitude!, longitude: event.longitude!,
      color: event.category.color, category: event.category.displayName,
      icon: event.category.icon,
    );
    await _drawRoute(tempLocation);
  }

  // Semantik Arama
  Future<void> _performSemanticSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _isSearching = true; _searchResultText = null; });
    final result = await GeminiService.analyzeIntent(query);
    if (result == null) {
      if (mounted) {
        setState(() { _isSearching = false; _searchResultText = 'Arama sonucu bulunamadı'; });
      }
      return;
    }
    setState(() {
      _isSearching = false;
      _searchResultText = result.intent;
    });
    // Kategoriye göre filtrele
    final matchingLocations = CampusLocation.filterByGeminiCategory(result.category);
    final matchingEvents = _events.where((e) => e.category.name == result.category).toList();

    if (matchingLocations.isNotEmpty) {
      final target = matchingLocations.first;
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(target.longitude, target.latitude)),
          zoom: 17.5,
        ),
        MapAnimationOptions(duration: 1200),
      );
    } else if (matchingEvents.isNotEmpty && matchingEvents.first.hasLocation) {
      final e = matchingEvents.first;
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(e.longitude!, e.latitude!)),
          zoom: 17.5,
        ),
        MapAnimationOptions(duration: 1200),
      );
    }
  }

  void _onFilterChanged(String filter) {
    setState(() => _activeFilter = filter);
    // Event marker'ları yeniden ekle (basit yaklaşım)
    _addEventMarkers();
  }

  /// Hedef seçim bottom sheet'i — arama çubuğundan veya event kartından çağrılabilir
  void showDestinationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
              const Text('Hedef Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: CampusLocation.locations.length,
                  itemBuilder: (ctx2, index) {
                    final location = CampusLocation.locations[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: location.color.withAlpha(50),
                        child: Icon(location.icon, color: location.color)),
                      title: Text(location.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(location.category, style: const TextStyle(color: Colors.white54)),
                      onTap: () { Navigator.pop(ctx2); _drawRoute(location); },
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

  void _openCreateEvent() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()));
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16, right: 70,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCC1A1A2E), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.withAlpha(80)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ne arıyorsun? (Örn: Karnım acıktı)',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13),
                  prefixIcon: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF7c6cf0)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _performSemanticSearch,
              ),
            ),
            if (_isSearching)
              const Padding(padding: EdgeInsets.only(right: 12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7c6cf0))))
            else
              IconButton(icon: const Icon(Icons.search, color: Colors.blueAccent, size: 20),
                onPressed: () => _performSemanticSearch(_searchController.text)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 0, right: 0,
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _filterCategories.length,
          itemBuilder: (context, index) {
            final cat = _filterCategories[index];
            final isActive = _activeFilter == cat;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => _onFilterChanged(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF7c6cf0) : const Color(0xCC1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isActive ? const Color(0xFF7c6cf0) : Colors.white.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == 0) Icon(Icons.celebration, size: 14, color: isActive ? Colors.white : Colors.white54),
                      if (index == 1) Icon(Icons.menu_book_rounded, size: 14, color: isActive ? Colors.white : Colors.white54),
                      if (index == 2) Icon(Icons.sports_soccer, size: 14, color: isActive ? Colors.white : Colors.white54),
                      if (index == 3) Icon(Icons.restaurant, size: 14, color: isActive ? Colors.white : Colors.white54),
                      if (index == 4) Icon(Icons.music_note, size: 14, color: isActive ? Colors.white : Colors.white54),
                      const SizedBox(width: 6),
                      Text(index == 0 ? 'Bugün Ne Var?' : cat,
                        style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchResultBanner() {
    if (_searchResultText == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF7c6cf0).withAlpha(200), borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_searchResultText!, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2)),
            GestureDetector(
              onTap: () => setState(() => _searchResultText = null),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    if (_selectedDestination == null || _routeDistance == null || _routeDuration == null) return const SizedBox.shrink();
    final distanceText = _routeDistance! < 1000 ? '${_routeDistance!.toInt()} Metre' : '${(_routeDistance! / 1000).toStringAsFixed(1)} KM';
    final durationText = '${(_routeDuration! / 60).ceil()} Dakika';
    return Positioned(
      bottom: 24, left: 16, right: 16,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1E1E2C),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: _selectedDestination!.color.withAlpha(50),
                child: Icon(Icons.flag, color: _selectedDestination!.color, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Varış Noktası', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(_selectedDestination!.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ])),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () {
                setState(() { _selectedDestination = null; _selectedEvent = null; });
                _mapboxMap?.style.removeStyleLayer('route-layer').catchError((_) {});
                _mapboxMap?.style.removeStyleSource('route-source').catchError((_) {});
              }),
            ]),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(color: Colors.white24, height: 1)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Row(children: [
                const Icon(Icons.directions_walk, color: Colors.greenAccent, size: 24),
                const SizedBox(width: 8),
                Text(distanceText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              Container(height: 24, width: 1, color: Colors.white24),
              Row(children: [
                const Icon(Icons.timer, color: Colors.orangeAccent, size: 24),
                const SizedBox(width: 8),
                Text(durationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEventCard() {
    if (_selectedEvent == null) return const SizedBox.shrink();
    final event = _selectedEvent!;
    return Positioned(
      bottom: 24, left: 16, right: 16,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1E1E2C),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              CircleAvatar(radius: 22, backgroundColor: event.category.color.withAlpha(40),
                child: Icon(event.category.icon, color: event.category.color, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(event.category.displayName, style: TextStyle(color: event.category.color, fontSize: 12)),
              ])),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _selectedEvent = null)),
            ]),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.description, style: const TextStyle(color: Colors.white60, fontSize: 13), maxLines: 2),
            ],
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: EventService.streamEventParticipants(event.id),
              builder: (context, snapshot) {
                final participants = snapshot.data ?? [];
                final count = participants.length;
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                final isGoing = participants.any((p) => p['user_id'] == currentUserId);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white54, size: 18),
                          const SizedBox(width: 6),
                          Text('$count kişi gidiyor', style: const TextStyle(color: Colors.white70)),
                        ]
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (isGoing) {
                            await EventService.leaveEvent(event.id);
                          } else {
                            await EventService.joinEvent(event.id);
                          }
                        },
    style: ElevatedButton.styleFrom(
  backgroundColor: isGoing ? Colors.white24 : const Color(0xFF10B981),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  minimumSize: const ui.Size(0, 0), // Başına ui. ekledik
),
                        child: Text(isGoing ? 'Vazgeç' : 'Gidiyorum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                );
              }
            ),
            SizedBox(width: double.infinity, height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                label: const Text('Oraya Git', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() => _selectedEvent = null);
                  _drawRouteToEvent(event);
                },
              ),
            ),
          ]),
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
            cameraOptions: CameraOptions(center: Point(coordinates: Position(_longitude, _latitude)), zoom: _zoom),
            styleUri: MapboxStyles.MAPBOX_STREETS,
          ),
          // Semantik Arama
          _buildSearchBar(),
          // Filtre Chipleri
          _buildFilterChips(),
          // Arama Sonucu Banner
          _buildSearchResultBanner(),
          // Çıkış butonu
          Positioned(
            top: MediaQuery.of(context).padding.top + 12, right: 16,
            child: Material(color: Colors.transparent,
              child: InkWell(onTap: _handleLogout, borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A2E), shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withAlpha(100)),
                  ),
                  child: const Icon(Icons.logout, size: 18, color: Color(0xFFFCA5A5)),
                ),
              ),
            ),
          ),
          // GPS Butonu
          Positioned(
            bottom: _selectedDestination == null && _selectedEvent == null ? 24 : 180, right: 16,
            child: FloatingActionButton(heroTag: 'gps_btn', mini: true,
              onPressed: _focusOnUserLocation, backgroundColor: const Color(0xCC1A1A2E),
              child: const Icon(Icons.my_location, color: Colors.blueAccent)),
          ),
          // AR Kamera Butonu
          Positioned(
            bottom: _selectedDestination == null && _selectedEvent == null ? 80 : 236, right: 16,
            child: FloatingActionButton(heroTag: 'ar_btn', mini: true,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArCameraScreen())),
              backgroundColor: const Color(0xCC1A1A2E),
              child: const Icon(Icons.camera_alt, color: Color(0xFF7c6cf0))),
          ),
          // Etkinlik Oluştur Butonu (Sadece Organizatörler)
          if (_isOrganizer)
            Positioned(
              bottom: _selectedDestination == null && _selectedEvent == null ? 136 : 292, right: 16,
              child: FloatingActionButton(heroTag: 'create_event_btn', mini: true,
                onPressed: _openCreateEvent, backgroundColor: const Color(0xCC1A1A2E),
                child: const Icon(Icons.add, color: Color(0xFF10B981))),
            ),
          // Event seçili kart veya rota bilgisi
          if (_selectedEvent != null) _buildEventCard()
          else _buildInfoOverlay(),
        ],
      ),
    );
  }
}
