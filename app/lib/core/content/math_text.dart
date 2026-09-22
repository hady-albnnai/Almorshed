/// المادة ١١-ج — طبقة عرض الصيغ داخل النص العربي (بوّابة **F2.3**).
///
/// docs/02 §خطر ١ يضع القاعدة الصارمة: **لا كلمة عربية داخل سلسلة رياضية**، والعربي
/// برهة والصيغة جوّه والربط بـ`WidgetSpan` مع عزل bidi بـ U+2068/U+2069 (FSI/PDI).
/// هذه الطبقة تنفّذ العزل وحده — بلا حزمة خارجية وبلا أي قرار بمحرك رسم:
///  • `mathRuns(text)` يكشف الشريط الرياضية (وحدات، جذور، أسس، نسب) في نصّ مختلط.
///  • `isolateMath(text)` يلفّ كل شريط بعزّالَي الاتجاه ⇒ لا ينقلب «T0 = 2π√(L/g)»
///    حين يقع وسط جملة RTL — وهذا وحده ما كان يفسد قراءة الفقرة في أبسط حالة.
///  • [MathText] يعرض النص؛ وحين يُعتمد `flutter_math_fork` أو SVG مسبق البناء
///    (docs/02 وقاية ١) يُمرَّر `renderer` فتُستبدل الصيغة برسمها — بلا مساس بالمحتوى.
///
/// لا تقسيم دلالي: لا نعرف «الفيزياء»، نعرف فقط أين يتوقف العربي. وكل ما عدا ذلك
/// يبقى كما كتبه المؤلِّف حرفياً — لا إعادة صياغة في العرض.
library;

import 'package:flutter/widgets.dart';

/// حروف تُعلِم أن الشريط رياضي لا كلمة: جذور ومجاميع وأسوم ومقادير وعلامات مقارنة.
const String mathSignals = '√∑∏∫∮∝≈≠≤≥±×÷·⁰¹²³⁴⁵⁶⁷⁸⁹ⁿµ'
    'πΠωΩθφλμΔΣΦΨ′″₀₁₂₃₄₅₆₇₈₉ₙₘℓ∆';

/// علامات تُعدّ علاقة/عملية داخل الصيغة (الأقواس وحدها لا تكفي: «(A)» ليست معادلة).
const String mathOps = '=+-*/^<>≈≤≥±×÷·|';

/// حروف متغيرات يونانية — تُعتبَر «مجهولاً» كما يفعّل [A-Za-z0-9].
const String mathLetters = 'πΠωΩθφλμΔΣΦΨµℓ′″';

final RegExp _arabicRun = RegExp(r'[؀-ۿ]');
final RegExp _latinRun = RegExp(r'[A-Za-z]');
final RegExp _digitRun = RegExp(r'[0-9]');
final RegExp _alnumRun = RegExp(r'[A-Za-z0-9]');

/// الفواصل والعوازل التي لا تقطع الشريط الرياضي (نكتبها في اختبار واحد).
final RegExp _tokenBoundary = RegExp(r'\s+');

/// هل هذا الرمز شريط رياضي معزول؟ لا عربيّ داخله إطلاقاً (قاعدة docs/02).
bool isMathToken(String token) {
  if (token.isEmpty) return false;
  // قاعدة docs/02: لا عربيّ داخل الصيغة — وإن وُجد فلا عزل ولا رسم.
  if (_arabicRun.hasMatch(token)) return false;
  // لا مجهول في الشريط ⇒ ليست صيغة: «·» و«≈» وحدهما علامتان لا علاقة.
  final hasOperand = _alnumRun.hasMatch(token) ||
      token.split('').any((c) => mathLetters.contains(c));
  if (!hasOperand) return false;
  for (final r in token.runes) {
    if (mathSignals.contains(String.fromCharCode(r))) return true;
  }
  // معرّفات القواعد (mix_formulas) ليست صيغاً وإن احتوت أقواساً.
  if (token.contains('_')) return false;
  final numeric = _digitRun.hasMatch(token);
  final latin = _latinRun.hasMatch(token);
  final hasOp = token.split('').any((c) => mathOps.contains(c));
  if (numeric && latin) return true; // T0، 60Hz
  if (numeric && hasOp) return true; // =10، L/2
  // حرفٌ وعملية وبنية: m/s، R/Z، x=0 — وحرفان بلا علاقة لا يكفيان.
  return latin && hasOp && token.length >= 3;
}

/// شرائط الصيغ في نصّ (بترتيب وروده) — بلا علامات عزل.
List<String> mathRuns(String text) => [
      for (final t in text.split(_tokenBoundary))
        if (isMathToken(t)) t,
    ];

/// نصّ [text] كلُّ شريط صيغة فيه ملفوف بعزّالَي الاتجاه (FSI … PDI).
String isolateMath(String text) {
  final out = StringBuffer();
  var first = 0;
  for (final m in _tokenBoundary.allMatches(text)) {
    final piece = text.substring(first, m.start());
    if (piece.isNotEmpty) {
      out.write(isMathToken(piece) ? '\u{2068}$piece\u{2069}' : piece);
    }
    out.write(m[0]);
    first = m.end();
  }
  final tail = text.substring(first);
  if (tail.isNotEmpty) {
    out.write(isMathToken(tail) ? '\u{2068}$tail\u{2069}' : tail);
  }
  return out.toString();
}

/// كم شريطاً عُزل في النصّ (للاختبارات ولتقرير البوابة).
int isolatedRunCount(String text) => mathRuns(text).length;

/// نصّ جاهز للعرض مع عزل الصيغ — ونقطة التحويل الوحيدة إلى محرك رسم لاحقاً.
class MathText extends StatelessWidget {
  const MathText(
    this.source, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.renderer,
    this.softWrap = true,
  });

  /// النصّ الأصلي كما ألَّفه المؤلِّف — لا تُضاف علامات عزل إلى [source] يدوياً.
  final String source;

  final TextStyle? style;
  final TextAlign? textAlign;

  /// لا يُمرَّر عادةً: الاتجاه يُستنتج من السياق (RTL عندنا) والعزل يكتفي بـ FSI/PDI.
  final TextDirection? textDirection;

  /// بديل الرسم: تُستدعى بكل شريط صيغة (بالنصّ الخام بلا علامات العزل).
  /// null = العرض النصي المعزول (المسار الحالي). عند اعتماد `flutter_math_fork`
  /// أو صور SVG مسبوقة البناء تُمرَّر هنا — لا في المحتوى ولا في التصحيح.
  final Widget Function(String formula)? renderer;

  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    if (renderer == null) {
      return Text(
        isolateMath(source),
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
      );
    }
    final render = renderer!;
    final spans = <InlineSpan>[];
    var first = 0;
    for (final m in _tokenBoundary.allMatches(source)) {
      _append(spans, source.substring(first, m.start()), m[0]!, render);
      first = m.end();
    }
    _append(spans, source.substring(first), '', render);
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
    );
  }

  void _append(
    List<InlineSpan> spans,
    String piece,
    String gap,
    Widget Function(String) render,
  ) {
    if (piece.isNotEmpty) {
      spans.add(isMathToken(piece)
          ? WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: render(piece),
              ),
            )
          : TextSpan(text: piece));
    }
    if (gap.isNotEmpty) spans.add(TextSpan(text: gap));
  }
}
