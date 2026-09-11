/// أرقام عربية-هندية لكل نصوص الواجهة (متسق مع النموذج المرجعي).
abstract final class ArabicNumber {
  static const String _digits = '٠١٢٣٤٥٦٧٨٩';

  static String from(int n) {
    final buf = StringBuffer();
    for (final ch in n.toString().split('')) {
      buf.write(_digits[int.parse(ch)]);
    }
    return buf.toString();
  }
}
