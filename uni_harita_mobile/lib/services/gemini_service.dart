import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      print('GEMINI_API_KEY bulunamadı');
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
        print('Gemini API Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Gemini API Exception: $e');
      return null;
    }
  }
}
