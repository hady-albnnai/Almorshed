// ═══════════════════════════════════════════════════════════════════════
// duel_session.ts — منفذ TS لمحرك الجلسة الحتمي (docs/12 §٢) — F5.1.
// مطابق بتّياً لـ app/lib/core/rng/splitmix64.dart + session.dart،
// ومتحقق منه بمقارن مستقل Python (متجهات ذهبية docs/16 §٦.١).
// القاعدة: نفس البذرة + نفس البنك ⇒ نفس الأسئلة وترتيب الخيارات على
// كل الأجهزة وعلى السيرفر — أي انحراف = نتيجة مرفوضة.
// ⚠️ كل العمليات BigInt مقنعة بـ64 بت؛ الإزاحة يميناً بعد القناع (منطقية).
// ═══════════════════════════════════════════════════════════════════════

const MASK = (1n << 64n) - 1n;
const GM = 0x9e3779b97f4a7c15n;
const M1 = 0xbf58476d1ce4e5b9n;
const M2 = 0x94d049bb133111ebn;

/** الشرخ الأساسي — مطابق لـ_split بDart: قناع قبل كل إزاحة = إزاحة منطقية. */
function mixCore(z: bigint): bigint {
  z = ((z ^ (z >> 30n)) * M1) & MASK;
  z = ((z ^ (z >> 27n)) * M2) & MASK;
  return (z ^ (z >> 31n)) & MASK;
}

/** mix64(x) ≡ next من حالة x — نفس تعريف docs/12 §٢.٢ حرفياً. */
export function mix64(seed: bigint): bigint {
  return mixCore((seed + GM) & MASK);
}

/** مولّد جلسة: كل استدعاء يعطي uint64 التالي (مطابق SplitMix64.next). */
export function stream(seed: bigint): () => bigint {
  let s = seed & MASK;
  return () => {
    s = (s + GM) & MASK;
    return mixCore(s);
  };
}

export const STREAM_A = 0xa11cen; // ترتيب الأسئلة
export const STREAM_C = 0xc0ffeen; // كسر التعادل

/** Fisher–Yates حتمي بمولّد معطى — يعدّل نسخة ويعيدها (docs/12 §٢.٣). */
export function fisherYates<T>(input: T[], rng: () => bigint): T[] {
  const list = input.slice();
  for (let i = list.length - 1; i > 0; i--) {
    const j = Number(rng() % BigInt(i + 1));
    const tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}

export interface BankRow {
  id: number;
  chapterIndex: number;
  correctIndex: number;
  optionsN: number;
}

export interface BuiltSession {
  /** معرفات الأسئلة بالترتيب النهائي (طولها = count). */
  questionIds: number[];
  /** لكل معرف سؤال: ترتيب فهارس الخيارات المعروضة. */
  optionOrders: Map<number, number[]>;
}

/** بناء الجلسة — مطابق buildSession بDart خطوة بخطوة (docs/12 §٢.٣). */
export function buildSessionFromBank(
  seed: bigint,
  count: number,
  bank: BankRow[],
): BuiltSession {
  if (count <= 0) throw new Error('COUNT_POSITIVE');
  if (bank.length < count) throw new Error('BANK_TOO_SMALL');

  // ٣) خلط البنك بتيار A
  const shuffled = fisherYates(
    bank.map((b) => b.id),
    stream((seed ^ STREAM_A) & MASK),
  );
  const byId = new Map<number, BankRow>(bank.map((b) => [b.id, b]));

  // ٤) توازن الفصول round-robin — الفصول بترتيب فهرسها الحتمي
  const byChapter = new Map<number, number[]>();
  for (const id of shuffled) {
    const ci = byId.get(id)!.chapterIndex;
    if (!byChapter.has(ci)) byChapter.set(ci, []);
    byChapter.get(ci)!.push(id);
  }
  const chapters = [...byChapter.keys()].sort((a, b) => a - b);
  const cursors = new Map<number, number>(chapters.map((c) => [c, 0]));
  const chosen: number[] = [];
  let guard = 0;
  while (chosen.length < count && guard <= bank.length) {
    let progressed = false;
    for (const c of chapters) {
      if (chosen.length === count) break;
      const pool = byChapter.get(c)!;
      const i = cursors.get(c)!;
      if (i < pool.length) {
        chosen.push(pool[i]);
        cursors.set(c, i + 1);
        progressed = true;
      }
    }
    if (!progressed) break;
    guard++;
  }

  // ٥) خلط الخيارات: بذرة مشتقة حتماً لكل سؤال — mix64(seed ⊕ q.id)
  const optionOrders = new Map<number, number[]>();
  for (const id of chosen) {
    const row = byId.get(id)!;
    const opts: number[] = [];
    for (let i = 0; i < row.optionsN; i++) opts.push(i);
    optionOrders.set(
      id,
      fisherYates(opts, stream(mix64((seed ^ BigInt(id)) & MASK))),
    );
  }

  return { questionIds: chosen, optionOrders };
}

/** فهرس الإجابة الصحيحة بالعرض بعد الخلط (مطابق displayCorrectIndex بDart). */
export function displayCorrectIndex(
  row: BankRow,
  optionOrder: number[],
): number {
  return optionOrder.indexOf(row.correctIndex);
}

// ── scopeTag (العقد §٦.٠): 13 بت من sha256 لنص النطاق ──
// مطابق Dart: ((b0<<8)|b1) & 0x1FFF من sha256(utf8(scopeStr)).
export function scopeString(scope: {
  units: string[];
  count: number;
  mode: string;
  pack: string;
}): string {
  return (
    'duel-v1|' +
    [...scope.units].sort().join(',') +
    '|count=' +
    scope.count +
    '|mode=' +
    scope.mode +
    '|pack=' +
    scope.pack
  );
}

export async function scopeTagOf(scope: {
  units: string[];
  count: number;
  mode: string;
  pack: string;
}): Promise<number> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(scopeString(scope)),
  );
  const b = new Uint8Array(digest);
  return ((b[0] << 8) | b[1]) & 0x1fff;
}
