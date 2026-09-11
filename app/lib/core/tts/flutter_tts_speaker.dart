import 'package:flutter_tts/flutter_tts.dart';

import 'speaker.dart';

/// التنفيذ الحقيقي فوق flutter_tts — على أندرويد: محرك النظام.
/// ⚠️ محذّرة موثقة (docs/14 §١٦-ب): isLanguageAvailable قد يجيب «متاح»
/// والبيانات الصوتية غير منزّلة (KEY_FEATURE_NOT_INSTALLED) —
/// الحكم النهائي تجربة الجهاز الفعلي، لا هذا الفحص وحده.
class FlutterTtsSpeaker implements Speaker {
  FlutterTtsSpeaker() : _tts = FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> hasArabicEngine() async {
    try {
      return await _tts.isLanguageAvailable('ar') == true;
    } catch (_) {
      // لا منصة ولا محرك (VM اختبار/جهاز بلا TTS) — الزر يختفي بهدوء.
      return false;
    }
  }

  @override
  Future<void> speak(String text) async {
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(0.45); // العربية تميل للسرعة بالإعدادات الافتراضية
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    // speak() تنتظر نهاية النطق — أنضف من معمليات اليد (بحث §١٦: SO #58567628).
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
