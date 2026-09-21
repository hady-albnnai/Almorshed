// ═════════════════════════════════════════════════════════════════════
// F2.2-T2 — تدقيق kc_wrap_v1 الخادمي (Deno/WebCrypto) ضد المتجهات الذهبية
// app/test/fixtures/content_crypto_vectors.json (المولَّدة بـNode والمتحقَّق
// منها بـDart). التشغيل من جذر المستودع:
//   deno run --allow-read tools/kc_wrap_vectors_check.ts
// ═════════════════════════════════════════════════════════════════════
import {
  bytesToHex,
  hexToBytes,
  unwrapKc,
  wrapKc,
  x25519PublicFromSeed,
} from '../supabase/functions/_shared/kc_wrap.ts';

const fixtures = JSON.parse(
  await Deno.readTextFile(
    new URL('../app/test/fixtures/content_crypto_vectors.json', import.meta.url),
  ),
);

let fails = 0;
const check = (cond: boolean, name: string) => {
  console.log(`${cond ? 'OK  ' : 'FAIL'} ${name}`);
  if (!cond) fails++;
};

// ١) RFC 7748 §6.1 — المفتاح العام من البذرة
const rfc = fixtures.rfc7748;
check(
  bytesToHex(await x25519PublicFromSeed(hexToBytes(rfc.alice_seed))) === rfc.alice_pub,
  'RFC 7748 alice_pub',
);
check(
  bytesToHex(await x25519PublicFromSeed(hexToBytes(rfc.bob_seed))) === rfc.bob_pub,
  'RFC 7748 bob_pub',
);

// ٢) kc_wrap_v1 — تغليف حتمي بتّي مطابق (eph_seed + nonce معلومان)
const v = fixtures.kc_wrap_v1;
const wrapped = await wrapKc(hexToBytes(v.kc), hexToBytes(v.device_pub), {
  ephemeralSeed: hexToBytes(v.eph_seed),
  nonce: hexToBytes(v.nonce),
});
check(bytesToHex(wrapped) === v.wrapped, 'kc_wrap_v1 wrapped == golden (92B)');

// ٣) الفكّ الطرفي: جهازه يفكّ — وجهاز آخر يُرفض
const kc = await unwrapKc(hexToBytes(v.wrapped), hexToBytes(v.device_seed));
check(bytesToHex(kc) === v.kc, 'unwrap by own device ⇒ K_c');
const other = fixtures.kc_wrap_v1_other_device;
let rejected = false;
try {
  await unwrapKc(hexToBytes(v.wrapped), hexToBytes(other.device_seed));
} catch (e) {
  rejected = String(e).includes('KC_WRAP_AUTH');
}
check(rejected, 'unwrap by other device ⇒ KC_WRAP_AUTH');

// ٤) المتجه الثاني (جهاز آخر) تغليفه الخاص مطابق
const w2 = await wrapKc(hexToBytes(other.kc), hexToBytes(other.device_pub), {
  ephemeralSeed: hexToBytes(other.eph_seed),
  nonce: hexToBytes(other.nonce),
});
check(bytesToHex(w2) === other.wrapped, 'kc_wrap_v1_other_device wrapped == golden');

// ٥) تغليف عشوائي (مسار الإنتاج) ⇒ دورة كاملة
const seed = crypto.getRandomValues(new Uint8Array(32));
const pub = await x25519PublicFromSeed(seed);
const kcRand = crypto.getRandomValues(new Uint8Array(32));
const wr = await wrapKc(kcRand, pub);
check(wr.length === 92, 'random wrap length 92');
check(bytesToHex(await unwrapKc(wr, seed)) === bytesToHex(kcRand), 'random roundtrip');

console.log(fails === 0 ? '\n✅ kc_wrap_v1 Deno ↔ Node ↔ Dart متطابقة' : `\n❌ ${fails} فشل`);
Deno.exit(fails === 0 ? 0 : 1);
