-- F2.2-T2 (قرار ٣٠/٦٧ — docs/16 §١٠): مفتاح X25519 العام لكل جهاز
-- يُرفع عند التفعيل ويُستعمل لتغليف K_c (kc_wrap_v1). null للأجهزة القديمة
-- حتى أول heartbeat يحمل device_x25519_pub_b64.
alter table public.devices
  add column if not exists x25519_pub_b64 text
  check (x25519_pub_b64 is null or length(x25519_pub_b64) = 44);
