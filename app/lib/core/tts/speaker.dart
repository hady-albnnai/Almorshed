/// واجهة النطق — تجريد فوق flutter_tts يسمح بحقن الزائف في الاختبارات
/// (نفس نمط حقن packLoader الذي نجح في F3.2 جزء أول).
/// قرار F3.2: غياب المحرك العربي = زر «اسمعني» يختفي كلياً، لا يُعطَّل.
abstract class Speaker {
  /// هل يتوفر محرك نطق عربي عامل على هذا الجهاز؟
  Future<bool> hasArabicEngine();

  /// ينطق النص وينتظر اكتمال النطق (awaitSpeakCompletion — بحث docs/14 §١٦).
  Future<void> speak(String text);

  /// يوقف النطق الجاري فوراً.
  Future<void> stop();
}
