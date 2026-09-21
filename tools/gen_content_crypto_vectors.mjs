// ═════════════════════════════════════════════════════════════════════
// F2.2-T1 — مولّد/مدقّق المتجهات الذهبية لـ pack_seal_v1 و kc_wrap_v1
// (قرار ٣٠ · قرار ٦٧ — المرجع البتّي: docs/16-SERVER-CONTRACT.md §١٠).
//
// التشغيل (يكتب app/test/fixtures/content_crypto_vectors.json):
//   node tools/gen_content_crypto_vectors.mjs
// التدقيق (يقارن الملف الموجود بلا كتابة):
//   node tools/gen_content_crypto_vectors.mjs --verify
//
// صيغة mjs عكس نظيرتها duel_session_vectors_check.ts: تجري على أي
// node ‏14+ بلا إضافات (node 20 بلا --experimental-strip-types).
//
// الذات-التحقّق قبل أي إخراج: X25519 ضد RFC 7748 §6.1 و HKDF ضد
// RFC 5869 حالة ١ — ثم فكّ طرفي. نظيرتها Dart بـ
// app/test/kc_wrap_test.dart و app/test/content_seal_test.dart.
// مفاتيح الاختبارية هنا معلَنة عمداً — لا تُستعمل إنتاجاً أبداً.
// ═════════════════════════════════════════════════════════════════════
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

// ── X25519 من بذرة خام 32 بايت عبر DER المعياري ──
const PKCS8_X25519_PREFIX = Buffer.from('302e020100300506032b656e04220420', 'hex');
const SPKI_X25519_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');

function x25519PrivateFromSeed(seed) {
  return crypto.createPrivateKey({
    key: Buffer.concat([PKCS8_X25519_PREFIX, seed]),
    format: 'der',
    type: 'pkcs8',
  });
}

function x25519PubRaw(priv) {
  const der = crypto.createPublicKey(priv).export({ format: 'der', type: 'spki' });
  return Buffer.from(der.subarray(der.length - 32));
}

function x25519PublicFromRaw(raw) {
  return crypto.createPublicKey({
    key: Buffer.concat([SPKI_X25519_PREFIX, raw]),
    format: 'der',
    type: 'spki',
  });
}

function x25519Shared(priv, pubRaw) {
  return crypto.diffieHellman({ privateKey: priv, publicKey: x25519PublicFromRaw(pubRaw) });
}

// ── AES-256-GCM مطابق لـ cryptography Dart (nonce 12 · tag 16 · AAD) ──
function aesGcmSeal(key, nonce, aad, plain) {
  const c = crypto.createCipheriv('aes-256-gcm', key, nonce, { authTagLength: 16 });
  c.setAAD(aad);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return { ct, mac: c.getAuthTag() };
}

function hkdfSha256(ikm, salt, info, length) {
  return Buffer.from(crypto.hkdfSync('sha256', ikm, salt, info, length));
}

const hex = (b) => Buffer.from(b).toString('hex');
const fromHex = (s) => Buffer.from(s, 'hex');

// ── ١) ذات-التحقّق: RFC 7748 §6.1 ──
const RFC_ALICE_SEED = fromHex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
const RFC_BOB_SEED = fromHex('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb');
const RFC_ALICE_PUB = '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a';
const RFC_BOB_PUB = 'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f';
const RFC_SHARED = '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742';

const alicePriv = x25519PrivateFromSeed(RFC_ALICE_SEED);
const bobPriv = x25519PrivateFromSeed(RFC_BOB_SEED);
const alicePub = hex(x25519PubRaw(alicePriv));
const bobPub = hex(x25519PubRaw(bobPriv));
const sharedAB = hex(x25519Shared(alicePriv, fromHex(bobPub)));

const rfc7748 = {
  alice_seed: hex(RFC_ALICE_SEED),
  alice_pub: alicePub,
  bob_seed: hex(RFC_BOB_SEED),
  bob_pub: bobPub,
  shared: sharedAB,
};

// ── ٢) ذات-التحقّق: RFC 5869 حالة ١ (HKDF-SHA256) ──
const K1_IKM = fromHex('0b'.repeat(22));
const K1_SALT = fromHex('000102030405060708090a0b0c');
const K1_INFO = fromHex('f0f1f2f3f4f5f6f7f8f9');
const K1_OKM = '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865';
const k1Out = hex(hkdfSha256(K1_IKM, K1_SALT, K1_INFO, 42));

const rfc5869_case1 = {
  ikm: hex(K1_IKM),
  salt: hex(K1_SALT),
  info: hex(K1_INFO),
  okm: k1Out,
};

// ── ٣) kc_wrap_v1 — متجهان (جهازان) بمفتاح/nonce مثبّتين ──
const WRAP_DOMAIN = Buffer.from('fizya-kc-wrap-v1', 'utf8'); // 16 بايت ASCII
const ZERO_SALT = Buffer.alloc(32, 0);

function kcWrapVector(deviceSeed, ephSeed, kc, nonce) {
  const devicePriv = x25519PrivateFromSeed(deviceSeed);
  const devicePub = x25519PubRaw(devicePriv);
  const ephPriv = x25519PrivateFromSeed(ephSeed);
  const ephPub = x25519PubRaw(ephPriv);
  const shared = x25519Shared(ephPriv, devicePub);
  const info = Buffer.concat([WRAP_DOMAIN, ephPub, devicePub]);
  const wrapKey = hkdfSha256(shared, ZERO_SALT, info, 32);
  const { ct, mac } = aesGcmSeal(wrapKey, nonce, info, kc);
  const wrapped = Buffer.concat([ephPub, nonce, ct, mac]);
  return {
    device_seed: hex(deviceSeed),
    device_pub: hex(devicePub),
    eph_seed: hex(ephSeed),
    eph_pub: hex(ephPub),
    kc: hex(kc),
    nonce: hex(nonce),
    shared: hex(shared),
    wrap_key: hex(wrapKey),
    wrapped: hex(wrapped),
  };
}

const TEST_KC = fromHex('33'.repeat(32));
const TEST_NONCE = fromHex('44'.repeat(12));
const wrap1 = kcWrapVector(fromHex('11'.repeat(32)), fromHex('22'.repeat(32)), TEST_KC, TEST_NONCE);
const wrapOther = kcWrapVector(fromHex('55'.repeat(32)), fromHex('22'.repeat(32)), TEST_KC, TEST_NONCE);

// ── ٤) pack_seal_v1 — متجه مثبّت ──
const SEAL_AAD = Buffer.from('fizya-pack-seal-v1', 'utf8'); // 18 بايت ASCII
const SEAL_KEY = fromHex('66'.repeat(32));
const SEAL_NONCE = fromHex('77'.repeat(12));
const SEAL_PLAIN = Buffer.from('فيزياء ⚡ 2027 — pack_seal_v1', 'utf8');
const sealBox = aesGcmSeal(SEAL_KEY, SEAL_NONCE, SEAL_AAD, SEAL_PLAIN);
const pack_seal_v1 = {
  key: hex(SEAL_KEY),
  nonce: hex(SEAL_NONCE),
  aad: hex(SEAL_AAD),
  plain_utf8: SEAL_PLAIN.toString('utf8'),
  plain_hex: hex(SEAL_PLAIN),
  sealed: hex(Buffer.concat([Buffer.from('FCP1', 'ascii'), SEAL_NONCE, sealBox.ct, sealBox.mac])),
};

const vectors = {
  format: 'fizya-content-crypto-vectors-1',
  generated_by: 'tools/gen_content_crypto_vectors.mjs',
  note: 'مفاتيح اختبارية معلَنة — لا تُستعمل إنتاجاً. مولَّدة ومعتمدة عبر Node crypto (نفس عائلة Deno Edge).',
  rfc7748,
  rfc5869_case1,
  kc_wrap_v1: wrap1,
  kc_wrap_v1_other_device: wrapOther,
  pack_seal_v1,
};

// ── الذات-التحقّق الصارم قبل أي كتابة/قبول ──
function assertEq(label, actual, expected) {
  if (actual !== expected) {
    console.error(`FATAL ${label}:`);
    console.error(`  actual  = ${actual}`);
    console.error(`  expected= ${expected}`);
    process.exit(1);
  }
  console.log(`ok ${label}`);
}

assertEq('rfc7748.alice_pub', alicePub, RFC_ALICE_PUB);
assertEq('rfc7748.bob_pub', bobPub, RFC_BOB_PUB);
assertEq('rfc7748.shared', sharedAB, RFC_SHARED);
assertEq('rfc5869_case1.okm', k1Out, K1_OKM);
if (wrap1.wrapped.length !== 92 * 2) {
  console.error(`FATAL kc_wrap_v1 طول: ${wrap1.wrapped.length / 2}`);
  process.exit(1);
}
console.log('ok kc_wrap_v1 طول 92 بايت');
if (wrap1.wrapped === wrapOther.wrapped) {
  console.error('FATAL: التغليف لا يختلف بين جهازين!');
  process.exit(1);
}
console.log('ok kc_wrap_v1 يختلف بين جهازين');

// فكّ طرفي (ذات-تحقّق داخلي): يفكه جهازه ولا يفكه الآخر.
function kcUnwrapOk(deviceSeed, wrappedHex) {
  const wrapped = fromHex(wrappedHex);
  const ephPub = wrapped.subarray(0, 32);
  const nonce = wrapped.subarray(32, 44);
  const ct = wrapped.subarray(44, 44 + 32);
  const mac = wrapped.subarray(76, 92);
  const devicePriv = x25519PrivateFromSeed(deviceSeed);
  const devicePub = x25519PubRaw(devicePriv);
  const shared = x25519Shared(devicePriv, ephPub);
  const info = Buffer.concat([WRAP_DOMAIN, ephPub, devicePub]);
  const wrapKey = hkdfSha256(shared, ZERO_SALT, info, 32);
  const d = crypto.createDecipheriv('aes-256-gcm', wrapKey, nonce, { authTagLength: 16 });
  d.setAAD(info);
  d.setAuthTag(mac);
  try {
    const kc = Buffer.concat([d.update(ct), d.final()]);
    return hex(kc) === hex(TEST_KC);
  } catch {
    return false;
  }
}

if (!kcUnwrapOk(fromHex('11'.repeat(32)), wrap1.wrapped)) {
  console.error('FATAL: الجهاز المقصود لم يفكّ تغليفه!');
  process.exit(1);
}
console.log('ok kc_wrap_v1 فكّ بالجهاز المقصود');
if (kcUnwrapOk(fromHex('55'.repeat(32)), wrap1.wrapped)) {
  console.error('FATAL: جهاز آخر فكّ التغليف!');
  process.exit(1);
}
console.log('ok kc_wrap_v1 رفض جهاز آخر');

// ── الكتابة أو التدقيق ──
const outPath = path.resolve('app/test/fixtures/content_crypto_vectors.json');
const serialized = `${JSON.stringify(vectors, null, 2)}\n`;

if (process.argv.includes('--verify')) {
  const onDisk = fs.readFileSync(outPath, 'utf8');
  assertEq('verify: الملف على القرص', onDisk === serialized ? 'match' : 'diff', 'match');
  console.log(`verified ${outPath}`);
} else {
  fs.writeFileSync(outPath, serialized, 'utf8');
  console.log(`written ${outPath}`);
}
