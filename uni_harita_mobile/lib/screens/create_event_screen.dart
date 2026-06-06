import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../models/event_model.dart';
import '../services/event_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  EventCategory _selectedCategory = EventCategory.seminer;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;

  // Haritadan seçilen konum
  double? _selectedLat;
  double? _selectedLng;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7c6cf0),
            surface: Color(0xFF1E1E2C),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7c6cf0),
            surface: Color(0xFF1E1E2C),
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedDate,
      firstDate: _selectedDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7c6cf0),
            surface: Color(0xFF1E1E2C),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedEndDate = date);
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? _selectedTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7c6cf0),
            surface: Color(0xFF1E1E2C),
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedEndTime = time);
  }

  void _openLocationPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MapLocationPicker(
          initialLat: _selectedLat ?? 38.6800,
          initialLng: _selectedLng ?? 39.1985,
          onLocationSelected: (lat, lng) {
            setState(() {
              _selectedLat = lat;
              _selectedLng = lng;
            });
          },
        ),
      ),
    );
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    DateTime? endTime;
    if (_selectedEndDate != null && _selectedEndTime != null) {
      endTime = DateTime(
        _selectedEndDate!.year,
        _selectedEndDate!.month,
        _selectedEndDate!.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );
    } else {
      // Varsayılan: başlangıçtan 2 saat sonra
      endTime = startTime.add(const Duration(hours: 2));
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    final event = EventModel(
      id: '', // Supabase otomatik oluşturacak
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      latitude: _selectedLat,
      longitude: _selectedLng,
      startTime: startTime,
      endTime: endTime,
      isActive: true,
      organizerId: userId,
      createdAt: DateTime.now(),
    );

    final result = await EventService.createEvent(event);

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(_selectedCategory.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Etkinlik başarıyla oluşturuldu!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true); // true = etkinlik oluşturuldu
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Etkinlik oluşturulamadı. Tekrar deneyin.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text(
          'Etkinlik Oluştur',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Başlık
            _buildSectionLabel('Etkinlik Başlığı'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                hint: 'Örn: Flutter Workshop',
                icon: Icons.title,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Lütfen bir başlık girin';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Açıklama
            _buildSectionLabel('Açıklama'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecoration(
                hint: 'Etkinlik detaylarını yazın...',
                icon: Icons.description,
              ),
            ),

            const SizedBox(height: 20),

            // Kategori
            _buildSectionLabel('Kategori'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: EventCategory.values.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category.color.withAlpha(40)
                          : const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? category.color : Colors.white.withAlpha(30),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon,
                            color: isSelected ? category.color : Colors.white54,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          category.displayName,
                          style: TextStyle(
                            color:
                                isSelected ? category.color : Colors.white54,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Tarih & Saat (Başlangıç)
            _buildSectionLabel('Başlangıç Tarihi & Saati'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.calendar_today,
                    label:
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.access_time,
                    label: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tarih & Saat (Bitiş — opsiyonel)
            _buildSectionLabel('Bitiş Tarihi & Saati (Opsiyonel)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.calendar_today,
                    label: _selectedEndDate != null
                        ? '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}'
                        : 'Tarih Seç',
                    onTap: _pickEndDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.access_time,
                    label: _selectedEndTime != null
                        ? _selectedEndTime!.format(context)
                        : 'Saat Seç',
                    onTap: _pickEndTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Konum Seçici
            _buildSectionLabel('Konum (Haritadan Seç)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openLocationPicker,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedLat != null
                        ? const Color(0xFF10B981)
                        : Colors.white.withAlpha(30),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedLat != null
                            ? const Color(0xFF10B981).withAlpha(30)
                            : Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedLat != null
                            ? Icons.check_circle
                            : Icons.map_outlined,
                        color: _selectedLat != null
                            ? const Color(0xFF10B981)
                            : Colors.white54,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLat != null
                                ? 'Konum Seçildi ✓'
                                : 'Haritadan Konum Seç',
                            style: TextStyle(
                              color: _selectedLat != null
                                  ? const Color(0xFF10B981)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedLat != null)
                            Text(
                              '${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Gönder Butonu
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7c6cf0),
                  disabledBackgroundColor: const Color(0xFF7c6cf0).withAlpha(80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF7c6cf0).withAlpha(100),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Etkinlik Oluştur',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: const Color(0xFF1E1E2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withAlpha(30)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withAlpha(30)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7c6cf0)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Haritadan Konum Seçme Ekranı
// ============================================================
class _MapLocationPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final Function(double lat, double lng) onLocationSelected;

  const _MapLocationPicker({
    required this.initialLat,
    required this.initialLng,
    required this.onLocationSelected,
  });

  @override
  State<_MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<_MapLocationPicker> {
  PointAnnotationManager? _annotationManager;
  double _selectedLat = 0;
  double _selectedLng = 0;

  // Web Map state
  final fm.MapController _webMapController = fm.MapController();

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;

    if (!kIsWeb) {
      final accessToken = dotenv.get('MAPBOX_ACCESS_TOKEN');
      MapboxOptions.setAccessToken(accessToken);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _annotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // Haritaya tıklama event'i ekle
    mapboxMap.setOnMapTapListener(_onMapTapped);

    // Başlangıç marker'ı ekle
    _updateMarker(_selectedLat, _selectedLng);
  }

  void _onMapTapped(MapContentGestureContext context) {
    final point = context.point;
    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();

    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
    });

    _updateMarker(lat, lng);
  }

  void _onWebMapTapped(fm.TapPosition tapPosition, ll.LatLng point) {
    setState(() {
      _selectedLat = point.latitude;
      _selectedLng = point.longitude;
    });
  }

  Future<void> _updateMarker(double lat, double lng) async {
    if (_annotationManager == null) return;

    // Mevcut marker'ları temizle
    await _annotationManager!.deleteAll();

    // Yeni marker ekle
    await _annotationManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      iconSize: 1.5,
      textField: '📍 Etkinlik Konumu',
      textSize: 13.0,
      textColor: Colors.white.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.5,
      textOffset: [0.0, 2.5],
    ));
  }

  void _confirmSelection() {
    widget.onLocationSelected(_selectedLat, _selectedLng);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Harita
          kIsWeb
              ? fm.FlutterMap(
                  mapController: _webMapController,
                  options: fm.MapOptions(
                    initialCenter: ll.LatLng(widget.initialLat, widget.initialLng),
                    initialZoom: 16.5,
                    onTap: _onWebMapTapped,
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                      additionalOptions: {
                        'accessToken': dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: ''),
                      },
                    ),
                    fm.MarkerLayer(
                      markers: [
                        fm.Marker(
                          point: ll.LatLng(_selectedLat, _selectedLng),
                          width: 140,
                          height: 70,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(200),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.redAccent),
                                ),
                                child: const Text(
                                  '📍 Etkinlik Konumu',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : MapWidget(
                  onMapCreated: _onMapCreated,
                  cameraOptions: CameraOptions(
                    center: Point(
                        coordinates:
                            Position(widget.initialLng, widget.initialLat)),
                    zoom: 16.5,
                  ),
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                ),

          // Üst bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Etkinlik Konumu Seç',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Ortadaki ipucu
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xCC1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, color: Colors.white54, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Haritaya dokunarak konum seçin',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Koordinat bilgisi + Onayla butonu
          Positioned(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Koordinat bilgisi
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(30)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_pin,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedLat.toStringAsFixed(5)}, ${_selectedLng.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Onayla butonu
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 8,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Bu Konumu Seç',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
