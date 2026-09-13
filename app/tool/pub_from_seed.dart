// أداة استعادة المفتاح العام من البذرة المحفوظة (المالك فقط).
// آمنة بالتصميم: البذرة تُقرأ من stdin حصراً — لا تُكتب بأي ملف،
// ولا تطبع، ولا تُرسل. الناتج الوحيد: المفتاح العام (عامّ بطبيعته).
// تشغيل: dart run tool/pub_from_seed.dart  ← ثم الصق البذرة وEnter.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

void main() {
  stdout.write('الصق PRIVATE SEED (base64) ثم Enter: ');
  final line = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  if (line.isEmpty) {
    stderr.writeln('✗ لا إدخال');
    exit(2);
  }
  final Uint8List seed;
  try {
    seed = base64Decode(line);
  } catch (_) {
    stderr.writeln('✗ ليست base64 سليمة');
    exit(2);
  }
  if (seed.length != 32) {
    stderr.writeln('✗ البذرة يجب أن تكون 32 بايت (وهي ${seed.length})');
    exit(2);
  }
  final privateKey = ed.newKeyFromSeed(seed);
  final publicKey = ed.public(privateKey);
  stdout.writeln();
  stdout.writeln('PUBLIC KEY (base64) — هذا السطر عامّ وآمن للإرسال:');
  stdout.writeln(base64Encode(publicKey.bytes));
}
