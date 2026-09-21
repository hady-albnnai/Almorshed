// ═════════════════════════════════════════════════════════════════════
// F2.2-T2 — kc_wrap_v1 على الطرف الخادمي (Deno/WebCrypto حصراً — بلا npm)
// المرجع البتّي: docs/16-SERVER-CONTRACT.md §١٠.٢ — نظيرتها Dart:
// app/lib/core/crypto/kc_wrap.dart. أي تعديل هنا يكسر التطابق ⇒ شغّل
//   deno run tools/kc_wrap_vectors_check.ts
// قبل أي نشر (يقارن بالمتجهات الذهبية Node↔Dart↔Deno).
//
// السلكي 92 بايت: eph_pk(32) ‖ nonce(12) ‖ ct(32) ‖ mac(16)
// info = 'fizya-kc-wrap-v1' ‖ eph_pk ‖ device_pk  (يدخل HKDF وGCM-AAD معاً)
// ═════════════════════════════════════════════════════════════════════

/// بايتات على ArrayBuffer صرف (TS 5.7+: WebCrypto لا يقبل ArrayBufferLike).
export type Bytes = Uint8Array<ArrayBuffer>;

const DOMAIN: Bytes = new TextEncoder().encode('fizya-kc-wrap-v1') as Bytes; // 16B
const SALT: Bytes = new Uint8Array(32); // 32×0x00 صريح
export const KC_LENGTH = 32;
export const WRAPPED_LENGTH = 32 + 12 + 32 + 16;

// PKCS#8 لبذرة X25519 خام (للمتجهات الذهبية فقط — الإنتاج generateKey)
const PKCS8_PREFIX: Bytes = hexToBytes('302e020100300506032b656e04220420');

export function hexToBytes(hex: string): Bytes {
  const out: Bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  return out;
}

export function bytesToHex(b: Uint8Array): string {
  return [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
}

export function b64ToBytes(b64: string): Bytes {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)) as Bytes;
}

export function bytesToB64(b: Uint8Array): string {
  let s = '';
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s);
}

function concat(...parts: Uint8Array[]): Bytes {
  const n = parts.reduce((a, p) => a + p.length, 0);
  const out: Bytes = new Uint8Array(n);
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

async function ephemeralPair(seed?: Uint8Array): Promise<CryptoKeyPair> {
  if (!seed) {
    return (await crypto.subtle.generateKey('X25519', true, [
      'deriveBits',
    ])) as CryptoKeyPair;
  }
  if (seed.length !== 32) throw new Error('KC_WRAP_SEED_LEN');
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    concat(PKCS8_PREFIX, seed),
    'X25519',
    true,
    ['deriveBits'],
  );
  // المفتاح العام يُشتق بالمرور عبر JWK (Deno لا يصدّر العام من الخاص مباشرة)
  const jwk = await crypto.subtle.exportKey('jwk', privateKey);
  delete jwk.d;
  jwk.key_ops = [];
  const publicKey = await crypto.subtle.importKey('jwk', jwk, 'X25519', true, []);
  return { privateKey, publicKey };
}

async function rawPublic(key: CryptoKey): Promise<Bytes> {
  return new Uint8Array(await crypto.subtle.exportKey('raw', key));
}

async function deriveWrapKey(
  privateKey: CryptoKey,
  remotePubRaw: Bytes,
  info: Bytes,
): Promise<CryptoKey> {
  const remote = await crypto.subtle.importKey('raw', remotePubRaw, 'X25519', true, []);
  const shared = await crypto.subtle.deriveBits(
    { name: 'X25519', public: remote },
    privateKey,
    256,
  );
  const ikm = await crypto.subtle.importKey('raw', shared, 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt: SALT, info },
    ikm,
    { name: 'AES-GCM', length: 256 },
    true,
    ['encrypt', 'decrypt'],
  );
}

/// يغلّف K_c (32) لمفتاح جهاز X25519 عام (32) — 92 بايت.
/// [ephemeralSeed]/[nonce] للمتجهات الذهبية فقط — الإنتاج عشوائي تاماً.
export async function wrapKc(
  kc: Bytes,
  devicePub: Bytes,
  opts: { ephemeralSeed?: Bytes; nonce?: Bytes } = {},
): Promise<Bytes> {
  if (kc.length !== KC_LENGTH) throw new Error('KC_WRAP_KC_LEN');
  if (devicePub.length !== 32) throw new Error('KC_WRAP_DEVICE_PK_LEN');
  const eph = await ephemeralPair(opts.ephemeralSeed);
  const ephPub = await rawPublic(eph.publicKey);
  const nonce: Bytes = opts.nonce ?? crypto.getRandomValues(new Uint8Array(12));
  if (nonce.length !== 12) throw new Error('KC_WRAP_NONCE_LEN');
  const info = concat(DOMAIN, ephPub, devicePub);
  const key = await deriveWrapKey(eph.privateKey, devicePub, info);
  const sealed = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: nonce, additionalData: info, tagLength: 128 },
      key,
      kc,
    ),
  ); // WebCrypto: ct ‖ tag — نفس ترتيب السلكي
  return concat(ephPub, nonce, sealed);
}

/// فكّ التغليف بمفتاح جهاز خاص (للتحقق الذاتي والاختبارات — الجهاز يفكّ إنتاجاً).
export async function unwrapKc(
  wrapped: Bytes,
  deviceSeed: Bytes,
): Promise<Bytes> {
  if (wrapped.length !== WRAPPED_LENGTH) throw new Error('KC_WRAP_FORMAT');
  const dev = await ephemeralPair(deviceSeed);
  const devicePub = await rawPublic(dev.publicKey);
  const ephPub = wrapped.slice(0, 32);
  const nonce = wrapped.slice(32, 44);
  const sealed = wrapped.slice(44);
  const info = concat(DOMAIN, ephPub, devicePub);
  const key = await deriveWrapKey(dev.privateKey, ephPub, info);
  try {
    return new Uint8Array(
      await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: nonce, additionalData: info, tagLength: 128 },
        key,
        sealed,
      ),
    );
  } catch {
    throw new Error('KC_WRAP_AUTH');
  }
}

/// المفتاح العام X25519 من بذرة (للأدوات والمتجهات).
export async function x25519PublicFromSeed(seed: Bytes): Promise<Bytes> {
  return rawPublic((await ephemeralPair(seed)).publicKey);
}

/// صحة مفتاح جهاز X25519 قادم من العميل: base64 لـ32 بايت بالضبط.
export function parseDevicePubB64(b64: string): Bytes | null {
  if (!/^[A-Za-z0-9+/]{43}=$/.test(b64)) return null;
  try {
    const raw = b64ToBytes(b64);
    return raw.length === 32 ? raw : null;
  } catch {
    return null;
  }
}

/// يقرأ K_c من سر الدوال `KC_B64` (32 بايت) — null إن لم يُضبط (T3 لم يبدأ).
export function kcFromEnv(): Bytes | null {
  const b64 = Deno.env.get('KC_B64');
  if (!b64) return null;
  const kc = b64ToBytes(b64);
  return kc.length === KC_LENGTH ? kc : null;
}
