const BASE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

/**
 * Kullanıcı girdisini Gemini ile semantik olarak analiz eder.
 * Dönen sonuç: { category, keywords, intent }
 */
export async function analyzeIntent(userInput) {
  const apiKey = import.meta.env.VITE_GEMINI_API_KEY || '';
  if (!apiKey) {
    console.warn('VITE_GEMINI_API_KEY bulunamadı');
    return null;
  }

  const url = `${BASE_URL}?key=${apiKey}`;

  const requestBody = {
    contents: [
      {
        parts: [
          {
            text: `Sen bir üniversite kampüs asistanısın. Kullanıcının aşağıdaki girdisini analiz et ve kampüsteki hangi kategoriye yönlendirilmesi gerektiğini belirle.

Mevcut kategoriler:
- "yemek" → Yemek, kantin, kafeterya, açlık, susuzluk, içecek
- "spor" → Spor salonu, futbol, basketbol, koşu, egzersiz
- "seminer" → Seminer, konferans, ders, eğitim, sunum, workshop
- "eglence" → Konser, etkinlik, parti, eğlence, müzik, tiyatro, festival
- "kutuphane" → Sessiz yer, çalışma, okuma, kütüphane, ders çalışma
- "idari" → Öğrenci işleri, rektörlük, kayıt, belge, dilekçe
- "fakulte" → Fakülte, bölüm, lab, sınıf, derslik

Kullanıcı girdisi: "${userInput}"

JSON formatında yanıt ver.`,
          },
        ],
      },
    ],
    generationConfig: {
      response_mime_type: 'application/json',
      response_schema: {
        type: 'object',
        properties: {
          category: {
            type: 'string',
            enum: [
              'yemek',
              'spor',
              'seminer',
              'eglence',
              'kutuphane',
              'idari',
              'fakulte',
            ],
          },
          keywords: {
            type: 'array',
            items: { type: 'string' },
          },
          intent: { type: 'string' },
        },
        required: ['category', 'keywords', 'intent'],
      },
    },
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    });

    if (response.ok) {
      const data = await response.json();
      const text = data.candidates[0].content.parts[0].text;
      return JSON.parse(text);
    } else {
      console.error('Gemini API Error:', response.status);
      return null;
    }
  } catch (e) {
    console.error('Gemini API Exception:', e);
    return null;
  }
}

/**
 * Aktif etkinliklere göre kampüs önerisi oluşturur
 */
export async function generateCampusRecommendation(activeEvents) {
  const apiKey = import.meta.env.VITE_GEMINI_API_KEY || '';
  if (!apiKey) {
    console.warn('VITE_GEMINI_API_KEY bulunamadı');
    return null;
  }

  const url = `${BASE_URL}?key=${apiKey}`;

  const eventsText = (!activeEvents || activeEvents.length === 0)
    ? "Şu an kampüste hiç aktif etkinlik yok."
    : `Aktif Etkinlikler:\n${activeEvents.map(e => `- ${e.title}`).join('\n')}`;

  const requestBody = {
    contents: [
      {
        parts: [
          {
            text: `Sen Fırat Üniversitesi'nin samimi AI kampüs rehberisin. Aktif etkinliklere bakarak kullanıcıya ne yapabileceğine dair samimi, enerjik ve en fazla 3-4 cümlelik kısa bir kampüs özeti/tavsiyesi üret. Eğer o an hiç etkinlik yoksa, cana yakın bir dille kampüsün sakin olduğunu söyle.\n\n${eventsText}`
          }
        ]
      }
    ]
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    });

    if (response.ok) {
      const data = await response.json();
      const text = data.candidates[0].content.parts[0].text;
      return text;
    } else {
      console.error('Gemini API Error:', response.status);
      return null;
    }
  } catch (e) {
    console.error('Gemini API Exception:', e);
    return null;
  }
}

