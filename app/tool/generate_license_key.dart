/// F4.4 — أداة توليد ثنائي مفتاح توقيع التراخيص (تشغّلها مرة واحدة على
/// جهاز المالك: `dart run tool/generate_license_key.dart` من مجلد app).
/// ⚠️ البذرة (PRIVATE) تُحفظ في أسرار Edge Functions حصراً — لا تُلصق
/// في أي ملف ولا تُشارك. المفتاح العام (PUBLIC) ليس سراً — يُرسل للمطوّر
/// ليحل محل placeholder في license_core.dart.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

void main(List<String> args) {
  // وضعان:
  //   dart run tool/generate_license_key.dart            ← مفتاح التوقيع
  //   dart run tool/generate_license_key.dart codes 50   ← ٥٠ كود تفعيل
  if (args.isNotEmpty && args[0] == 'codes') {
    _generateCodes(int.tryParse(args.length > 1 ? args[1] : '50') ?? 50);
    return;
  }
  _generateSigningKey();
}

/// F4.4/F6.1 — توليد أكواد تفعيل: ١٥ محرفاً من أبجدية Crockford-32
/// (بلا I/L/O/U — قرار ٣٤) عبر Random.secure حصراً.
/// فضاء البحث = 32^15 ≈ 4.25×10^22 (≈ 95.2 بت) — التخمين مستحيل عملياً،
/// والخادم يقيّد المحاولات (5 فاشلات/١٥ دقيقة — ترحيل 0004) فيصعب
/// التعداد القسري ولو آلياً. فحص تكرار محلي (تصادم مستحيل رياضياً
/// بهذا الفضاء لكن يُفحص تحسباً بأقل من مليون كود).
void _generateCodes(int n) {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // 32 محرفاً
  final rng = Random.secure();
  final seen = <String>{};
  while (seen.length < n) {
    final code = List.generate(15, (_) => alphabet[rng.nextInt(32)]).join();
    seen.add(code);
  }
  final codes = seen.toList()..sort();

  stdout.writeln('════ الأكواد للطباعة على البطاقات (X5-X5-X5) ════');
  for (final c in codes) {
    stdout.writeln('${c.substring(0, 5)}-${c.substring(5, 10)}-${c.substring(10)}');
  }
  stdout.writeln();
  stdout.writeln('-- SQL: الصق هذه الكتلة في SQL Editor لإصدار الأكواد:');
  stdout.writeln('insert into public.activation_codes (code, distributor) values');
  final values = <String>[];
  for (final c in codes) {
    values.add("    ('${c.substring(0, 5)}${c.substring(5, 10)}${c.substring(10)}', 'مكتب لورانيم')");
  }
  stdout.writeln(values.join(',\n'));
  stdout.writeln('on conflict (code) do nothing;');
  stdout.writeln();
  stdout.writeln('⚠️ تخزّن الأكواد بلا شرطات بالقاعدة — الشرطة للعرض حصراً.');
  stdout.writeln('⚠️ هذا الناتج حساس تجارياً (أكواد مال) — لا يُلصق بالمحادثة.');
}

void _generateSigningKey() {
  final seed = Uint8List(32);
  final rng = Random.secure();
  for (var i = 0; i < 32; i++) {
    seed[i] = rng.nextInt(256);
  }
  final privateKey = ed.newKeyFromSeed(seed);
  final publicKey = ed.public(privateKey);

  stdout.writeln('══════════════════════════════════════════════════════');
  stdout.writeln('PRIVATE SEED (base64) — Supabase Edge Function secret حصراً:');
  stdout.writeln(base64Encode(seed));
  stdout.writeln('──────────────────────────────────────────────────────');
  stdout.writeln('PUBLIC KEY (base64) — يُرسل للمطوّر ليوضع بlicense_core.dart:');
  stdout.writeln(base64Encode(publicKey.bytes));
  stdout.writeln('══════════════════════════════════════════════════════');
  stdout.writeln('⚠️ احفظ البذرة بمكان آمن واحد فقط (مدير أسرار Supabase) —');
  stdout.writeln('   ضياعها = إعادة إصدار كل التراخيص بمفتاح جديد.');
}
