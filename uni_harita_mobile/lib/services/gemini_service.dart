import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';

/// Gemini API'den dönen semantik analiz sonucu
class GeminiSearchResult {
  final String category; // yemek, spor, seminer, eglence, kutuphane, idari, fakulte
  final List<String> keywords;
  final String intent;

  const GeminiSearchResult({
    required this.category,
    required this.keywords,
    required this.intent,
  });

  factory GeminiSearchResult.fromJson(Map<String, dynamic> json) {
    return GeminiSearchResult(
      category: json['category'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      intent: json['intent'] as String? ?? '',
    );
  }
}

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Kullanıcı girdisini semantik olarak analiz eder
  /// Dönen sonuç: kategori + anahtar kelimeler + niyet
  static Future<GeminiSearchResult?> analyzeIntent(String userInput) async {
    final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    if (apiKey.isEmpty) {
      debugPrint('GEMINI_API_KEY bulunamadı');
      return null;
    }

    final url = '$_baseUrl?key=$apiKey';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': '''Sen bir üniversite kampüs asistanısın. Kullanıcının aşağıdaki girdisini analiz et ve kampüsteki hangi kategoriye yönlendirilmesi gerektiğini belirle.

Mevcut kategoriler:
- "yemek" → Yemek, kantin, kafeterya, açlık, susuzluk, içecek
- "spor" → Spor salonu, futbol, basketbol, koşu, egzersiz
- "seminer" → Seminer, konferans, ders, eğitim, sunum, workshop
- "eglence" → Konser, etkinlik, parti, eğlence, müzik, tiyatro, festival
- "kutuphane" → Sessiz yer, çalışma, okuma, kütüphane, ders çalışma
- "idari" → Öğrenci işleri, rektörlük, kayıt, belge, dilekçe
- "fakulte" → Fakülte, bölüm, lab, sınıf, derslik

Kullanıcı girdisi: "$userInput"

JSON formatında yanıt ver.'''
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'response_schema': {
          'type': 'object',
          'properties': {
            'category': {
              'type': 'string',
              'enum': [
                'yemek',
                'spor',
                'seminer',
                'eglence',
                'kutuphane',
                'idari',
                'fakulte'
              ]
            },
            'keywords': {
              'type': 'array',
              'items': {'type': 'string'}
            },
            'intent': {'type': 'string'}
          },
          'required': ['category', 'keywords', 'intent']
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final parsed = jsonDecode(text) as Map<String, dynamic>;
        return GeminiSearchResult.fromJson(parsed);
      } else {
        debugPrint('Gemini API Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Gemini API Exception: $e');
      return null;
    }
  }

  /// Aktif etkinliklere göre kampüs önerisi oluşturur
  static Future<String?> generateCampusRecommendation(List<EventModel> activeEvents) async {
    if (activeEvents.isEmpty) {
      return 'Kampüs şu an çok sakin ve huzurlu. Kütüphanede kahve içip ders çalışmak veya yeşil alanda tur atmak için harika bir gün!';
    }

    final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    if (apiKey.isEmpty) {
      debugPrint('GEMINI_API_KEY bulunamadı');
      return 'API anahtarı eksik ama kampüs seni bekliyor!';
    }

    final url = '$_baseUrl?key=$apiKey';

    // Veriyi basit bir string listesine dönüştür
    String eventsText = activeEvents.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final e = entry.value;
      return "Etkinlik $index: ${e.title}, Kategori: ${e.category.displayName}";
    }).join("\n");

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': '''Sen Fırat Üniversitesi kampüs rehberisin. Sana verdiğim etkinliklere bakarak öğrencilere samimi, enerjik ve kesinlikle en fazla 3-4 cümlelik bir tavsiye yazısı üret.

Aktif Etkinlikler:
$eventsText'''
            }
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text;
      } else {
        debugPrint('Gemini API Error ${response.statusCode}: ${response.body}');
        return 'Şu an öneri servisine ulaşılamıyor ama kampüste her zaman keşfedilecek bir şeyler vardır!';
      }
    } catch (e) {
      debugPrint('Gemini API Exception: $e');
      return 'Bağlantı sorunu yaşandı ancak haritadan etkinliklere göz atabilirsin!';
    }
  }
}
