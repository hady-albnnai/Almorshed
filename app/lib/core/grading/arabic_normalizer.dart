/// المادة ١١ — تطبيع النص العربي لمطابقة المفاتيح (docs/22 §٤ البند ١١).
///
/// القواعد الثابتة: ة→ه · أإآٱ→ا · ى→ي · ؤ→و · ئ→ي · حذف التشكيل والتطويل
/// وعلامات الترقيم · توحيد الأرقام العربية-الهندية إلى اللاتينية · فصل الحرف
/// العربي عن اللاتيني (وm ⇒ و m) · حذف «ال» التعريف وواو العطف عند المقارنة
/// الكلمية فقط (لا عند العرض). التطبيع يُطبَّق على إجابة الطالب وعلى المفتاح
/// معاً ثم يُقارَنان — فأي «تساهل» متناظر لا يخلق ظلماً.
library;

abstract final class ArabicNormalizer {
  static const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const String _persianIndic = '۰۱۲۳۴۵۶۷۸۹';

  /// حروف التشكيل والتطويل (U+064B–U+0652، U+0670، U+0640) وعلامات الاتجاه.
  static final RegExp _diacritics =
      RegExp('[\u064B-\u0652\u0670\u0640\u200f\u200e\u202a-\u202e\u061c]');

  /// كل ما ليس حرفاً/رقماً/مسافة — علامات ترقيم عربية ولاتينية ورموز.
  static final RegExp _punct = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static final RegExp _arabicThenLatin = RegExp(r'([\u0600-\u06FF])([A-Za-z0-9])');
  static final RegExp _latinThenArabic = RegExp(r'([A-Za-z0-9])([\u0600-\u06FF])');
  static final RegExp _spaces = RegExp(r'\s+');

  /// بادئات الجرّ والعطف التي يُتسامح معها عند مقارنة كلمة بكلمة.
  static const List<String> _prefixes = [
    'بال', 'كال', 'فال', 'ولل', 'لل', 'ب', 'ل', 'ك', 'ف', 'و',
  ];

  /// التطبيع الحرفي (بلا حذف «ال»).
  static String normalize(String input) {
    var s = input.trim();
    s = s.replaceAll(_diacritics, '');
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('گ', 'ك')
        .replaceAll('ک', 'ك')
        .replaceAll('ی', 'ي');
    s = latinDigits(s);
    s = s.replaceAllMapped(_arabicThenLatin, (m) => '${m[1]} ${m[2]}');
    s = s.replaceAllMapped(_latinThenArabic, (m) => '${m[1]} ${m[2]}');
    s = s.replaceAll(_punct, ' ');
    s = s.replaceAll(_spaces, ' ').trim();
    return s.toLowerCase();
  }

  /// الكلمات المطبَّعة مع حذف «ال» التعريف وواو العطف الملتصقة والمنفردة.
  static List<String> tokens(String input) {
    final out = <String>[];
    for (final w in normalize(input).split(' ')) {
      var t = w;
      if (t.isEmpty || t == 'و') continue;
      if (t.length > 4 && t.startsWith('وال')) t = t.substring(3);
      if (t.length > 3 && t.startsWith('ال')) t = t.substring(2);
      if (t.length > 3 && t.startsWith('و')) t = t.substring(1);
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  /// هل يحوي النصُّ المفتاحَ (كلمات متتالية) بعد التطبيع؟
  static bool contains(String text, String key) {
    final t = tokens(text);
    final k = tokens(key);
    if (k.isEmpty || t.length < k.length) return false;
    for (var i = 0; i + k.length <= t.length; i++) {
      var ok = true;
      for (var j = 0; j < k.length; j++) {
        if (!_tokenMatches(t[i + j], k[j])) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  static bool _tokenMatches(String w, String k) {
    if (w == k) return true;
    for (final p in _prefixes) {
      if (w.length > p.length + 1 &&
          w.startsWith(p) &&
          w.substring(p.length) == k) {
        return true;
      }
      if (k.length > p.length + 1 &&
          k.startsWith(p) &&
          k.substring(p.length) == w) {
        return true;
      }
    }
    return false;
  }

  /// الأرقام العربية-الهندية والفارسية → لاتينية.
  static String latinDigits(String s) {
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final i = _arabicIndic.indexOf(ch);
      final j = _persianIndic.indexOf(ch);
      if (i >= 0) {
        buf.write(i);
      } else if (j >= 0) {
        buf.write(j);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }
}
