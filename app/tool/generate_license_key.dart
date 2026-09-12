/// F4.4 — أداة توليد ثنائي مفتاح توقيع التراخيص (تشغّلها مرة واحدة على
/// جهاز المالك: `dart run tool/generate_license_key.dart` من مجلد app).
/// ⚠️ البذرة (PRIVATE) تُحفظ في أسرار Edge Functions حصراً — لا تُلصق
/// في أي ملف ولا تُشارك. المفتاح العام (PUBLIC) ليس سراً — يُرسل للمطوّر
/// ليحل محل placeholder في license_core.dart.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

void main() {
  final seed = Uint8List(32);
  final rng = Random.secure();
  for (var i = 0; i < 32; i++) {
    seed[i] = rng.nextInt(256);
  }
  final privateKey = ed.newKeyFromSeed(seed);
  final publicKey = ed.public(privateKey);

  print('══════════════════════════════════════════════════════');
  print('PRIVATE SEED (base64) — Supabase Edge Function secret حصراً:');
  print(base64Encode(seed));
  print('──────────────────────────────────────────────────────');
  print('PUBLIC KEY (base64) — يُرسل للمطوّر ليوضع بlicense_core.dart:');
  print(base64Encode(publicKey.bytes));
  print('══════════════════════════════════════════════════════');
  print('⚠️ احفظ البذرة بمكان آمن واحد فقط (مدير أسرار Supabase) —');
  print('   ضياعها = إعادة إصدار كل التراخيص بمفتاح جديد.');
}
