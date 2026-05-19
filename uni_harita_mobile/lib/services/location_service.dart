import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Konum servisinin açık olup olmadığını ve izin durumunu kontrol eder.
  /// Gerekirse kullanıcıya şık bir diyalog ile uyarı gösterir ve izin ister.
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Konum servisleri açık mı kontrol et.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        _showLocationDialog(
          context,
          'Konum Servisi Kapalı',
          'Haritada yerinizi görebilmek ve rota oluşturabilmek için lütfen cihazınızın konum servislerini açın.',
        );
      }
      return false;
    }

    // 2. Uygulama izinlerini kontrol et.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          _showLocationDialog(
            context,
            'Konum İzni Gerekli',
            'Size en iyi kampüs deneyimini sunabilmek için konum izninize ihtiyacımız var.',
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showLocationDialog(
          context,
          'Konum İzni Kalıcı Olarak Reddedildi',
          'Konum izinleri kalıcı olarak reddedilmiş. Lütfen cihaz ayarlarına giderek UniHarita için konum iznini etkinleştirin.',
          isSettings: true,
        );
      }
      return false;
    }

    return true;
  }

  /// Mevcut konumu bir kereliğine alır
  static Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('getCurrentLocation Error: $e');
      return null;
    }
  }

  /// Canlı konum değişikliklerini dinlemek için bir Stream döndürür
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10 metre değiştiğinde yeni konum verisi gönder
      ),
    );
  }

  /// Konum izin/servis hataları için şık uyarı diyaloğu
  static void _showLocationDialog(
    BuildContext context,
    String title,
    String message, {
    bool isSettings = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.blue.withAlpha(50), width: 1),
          ),
          title: Row(
            children: [
              const Icon(Icons.location_off, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            if (isSettings)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Geolocator.openAppSettings();
                },
                child: const Text('Ayarlara Git', style: TextStyle(color: Colors.white)),
              ),
            if (!isSettings)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Tamam', style: TextStyle(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }
}
