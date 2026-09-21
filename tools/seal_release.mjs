#!/usr/bin/env node
// ═════════════════════════════════════════════════════════════════════
// F2.2-T2 — أداة الإصدار: K_c لكل إصدار منهاج + ختم pack.json/glossary.json
// بصيغة pack_seal_v1 (docs/16 §١٠.١ — نظيرة Dart: content_seal.dart).
//
//   توليد مفتاح إصدار جديد (يُطبع base64 — يُوضع سرّاً بالدوال KC_B64):
//     node tools/seal_release.mjs keygen
//
//   ختم أصول الإصدار (يكتب *.sealed بجانب الأصل — لا يلمس النصي):
//     KC_B64=... node tools/seal_release.mjs seal [app/assets/content]
//
//   تحقّق: فكّ *.sealed بالمفتاح ومقارنته بالأصل بايتاً بايتاً:
//     KC_B64=... node tools/seal_release.mjs verify [app/assets/content]
//
// قواعد (قرار ٣٠ · ٦٧ · docs/11 §٧):
//   • K_c لا يُكتب في المستودع ولا في APK — يعيش سرّاً بالدوال فقط،
//     ويُغلَّف لكل جهاز بـkc_wrap_v1 (license_activate/heartbeat).
//   • nonce عشوائي 12 بايت لكل عملية ختم — إعادة الختم تنتج ملفاً مختلفاً.
//   • T3: شحن *.sealed بالإنتاج بعد اعتماد الأستاذ فقط (docs/16 §١٠.٣).
// ═════════════════════════════════════════════════════════════════════
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const MAGIC = Buffer.from('FCP1', 'ascii');
const AAD = Buffer.from('fizya-pack-seal-v1', 'ascii');
const FILES = ['pack.json', 'glossary.json'];

export function sealBytes(kc, plain) {
  const nonce = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', kc, nonce, { authTagLength: 16 });
  c.setAAD(AAD);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return Buffer.concat([MAGIC, nonce, ct, c.getAuthTag()]);
}

export function openBytes(kc, sealed) {
  if (sealed.length < 4 + 12 + 16 || !sealed.subarray(0, 4).equals(MAGIC)) {
    throw new Error('pack_seal_v1: format');
  }
  const nonce = sealed.subarray(4, 16);
  const ct = sealed.subarray(16, sealed.length - 16);
  const mac = sealed.subarray(sealed.length - 16);
  const d = crypto.createDecipheriv('aes-256-gcm', kc, nonce, { authTagLength: 16 });
  d.setAAD(AAD);
  d.setAuthTag(mac);
  return Buffer.concat([d.update(ct), d.final()]);
}

function kcFromEnv() {
  const b64 = process.env.KC_B64;
  if (!b64) {
    console.error('KC_B64 غير مضبوط — ولّده بـ `node tools/seal_release.mjs keygen`');
    process.exit(2);
  }
  const kc = Buffer.from(b64, 'base64');
  if (kc.length !== 32) {
    console.error('KC_B64 يجب أن يكون 32 بايت base64');
    process.exit(2);
  }
  return kc;
}

const [, , cmd, dirArg] = process.argv;
const dir = path.resolve(dirArg ?? 'app/assets/content');

if (cmd === 'keygen') {
  const kc = crypto.randomBytes(32);
  console.log(kc.toString('base64'));
  console.error(
    '⚠️ احفظه سرّاً بالدوال: supabase secrets set KC_B64=<القيمة> — ولا تُودعه بالمستودع.',
  );
} else if (cmd === 'seal') {
  const kc = kcFromEnv();
  for (const f of FILES) {
    const src = path.join(dir, f);
    const plain = fs.readFileSync(src);
    const sealed = sealBytes(kc, plain);
    fs.writeFileSync(`${src}.sealed`, sealed);
    console.log(`✓ ${f} → ${f}.sealed (${plain.length} → ${sealed.length} بايت)`);
  }
} else if (cmd === 'verify') {
  const kc = kcFromEnv();
  let bad = 0;
  for (const f of FILES) {
    const src = path.join(dir, f);
    const plain = fs.readFileSync(src);
    const opened = openBytes(kc, fs.readFileSync(`${src}.sealed`));
    const ok = opened.equals(plain);
    console.log(`${ok ? 'OK  ' : 'FAIL'} ${f}.sealed`);
    if (!ok) bad++;
  }
  process.exit(bad ? 1 : 0);
} else {
  console.error('الاستعمال: seal_release.mjs keygen | seal [dir] | verify [dir]');
  process.exit(2);
}
