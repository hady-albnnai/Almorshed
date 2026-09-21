/// F2.2-T2 — ContentKeyProvisioner: ابتلاع `kc_wrapped` من رد الخادم
/// (المتجه الذهبي نفسه الذي يخرجه supabase/functions/_shared/kc_wrap.ts —
/// تدقيقه: `deno run --allow-read tools/kc_wrap_vectors_check.ts`).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/crypto/content_key_vault.dart';
import 'package:fizya_clash/core/crypto/device_key_vault.dart';
import 'package:fizya_clash/core/crypto/kc_provision.dart';

Uint8List hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

void main() {
  final vectors = jsonDecode(
    File('${Directory.current.path}/test/fixtures/content_crypto_vectors.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final v = vectors['kc_wrap_v1'] as Map<String, dynamic>;
  final other = vectors['kc_wrap_v1_other_device'] as Map<String, dynamic>;

  ContentKeyProvisioner build(String seedHex) => ContentKeyProvisioner(
        deviceKeys: InMemoryDeviceKeyVault(hexToBytes(seedHex)),
        contentKeys: InMemoryContentKeyVault(),
      );

  test('المفتاح العام المرفوع = 44 محرف base64 لـ32 بايت (المتجه الذهبي)',
      () async {
    final p = build(v['device_seed'] as String);
    final b64 = await p.devicePublicB64();
    expect(b64, hasLength(44));
    expect(base64Decode(b64), equals(hexToBytes(v['device_pub'] as String)));
    expect(await p.hasKey, isFalse);
  });

  test('رد الخادم بـkc_wrapped ⇒ فكّ وحفظ K_c بالخزنة', () async {
    final p = build(v['device_seed'] as String);
    final response = <String, dynamic>{
      'ok': true,
      'kc_wrapped': base64Encode(hexToBytes(v['wrapped'] as String)),
    };
    expect(await p.ingest(response), isTrue);
    expect(await p.hasKey, isTrue);
    expect(await p.contentKeys.read(), equals(hexToBytes(v['kc'] as String)));
  });

  test('رد بلا kc_wrapped أو بقيمة معطوبة ⇒ لا تغيير ولا استثناء', () async {
    final p = build(v['device_seed'] as String);
    expect(await p.ingest(<String, dynamic>{'ok': true}), isFalse);
    expect(await p.ingest(<String, dynamic>{'kc_wrapped': ''}), isFalse);
    expect(await p.ingest(<String, dynamic>{'kc_wrapped': '!!!'}), isFalse);
    expect(
      await p.ingest(<String, dynamic>{'kc_wrapped': base64Encode([1, 2, 3])}),
      isFalse,
    );
    expect(await p.hasKey, isFalse);
  });

  test('تغليف موجّه لجهاز آخر ⇒ يُرفض والمفتاح القديم يبقى', () async {
    final p = build(other['device_seed'] as String);
    // أولاً مفتاحه الصحيح
    expect(
      await p.ingest(<String, dynamic>{
        'kc_wrapped': base64Encode(hexToBytes(other['wrapped'] as String)),
      }),
      isTrue,
    );
    // ثم تغليف الجهاز الأول — لا يفكّه
    expect(
      await p.ingest(<String, dynamic>{
        'kc_wrapped': base64Encode(hexToBytes(v['wrapped'] as String)),
      }),
      isFalse,
    );
    expect(
      await p.contentKeys.read(),
      equals(hexToBytes(other['kc'] as String)),
    );
  });
}
