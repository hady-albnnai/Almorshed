// ═══════════════════════════════════════════════════════════════════════
// duel_finish — الحكم الخادمي للمبارزة (F5.1 — docs/16 §٦).
// إعادة توليد الجلسة من البذرة وتصحيح الإجابات دونه (docs/14 F5.1):
// أي تعارض ⇒ رفض ٤٢٢ ولا نتيجة. الخدمة وحدها تكتب الحكم (الزناد duels_guard
// يمنع العملاء من لمس status/scores/winner — الترحيل 0005).
// idempotent: إعادة النداء بعد done تعيد النتيجة المخزنة نفسها.
// ═══════════════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  BankRow,
  buildSessionFromBank,
  displayCorrectIndex,
  scopeTagOf,
  stream,
  STREAM_C,
} from '../_shared/duel_session.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

// ثوابت المبارزة — مطابقة لعميل Dart (duel_engine.dart) والعقد §٦.٢
const QUESTION_SECONDS = 20;
const GRACE_MS = 60_000;
const POINTS_PER_CORRECT = 100;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

interface DuelRow {
  id: string;
  seed_text: string;
  scope: {
    units: string[];
    count: number;
    mode: string;
    pack: string;
  };
  status: string;
  host_device: string;
  guest_device: string | null;
  started_at: string | null;
  host_score: number | null;
  guest_score: number | null;
  winner_device: string | null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, reason: 'METHOD' }, 405);

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── ١) الهوية: مشاركٌ موثق حصراً ──
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const { data: userData, error: userErr } = await admin.auth.getUser(token);
    if (userErr || !userData?.user)
      return json({ ok: false, reason: 'UNAUTHENTICATED' }, 401);
    const uid = userData.user.id;

    const body = await req.json();
    const duelId = String(body?.duel_id ?? '');
    if (!UUID_RE.test(duelId))
      return json({ ok: false, reason: 'DUEL_ID_FORMAT' }, 422);

    // ── ٢) المبارزة من القاعدة (لا ثقة بالادعاء) ──
    const { data: duel, error: duelErr } = await admin
      .from('duels')
      .select('*, seed_text:seed::text')
      .eq('id', duelId)
      .maybeSingle<DuelRow>();
    if (duelErr || !duel) return json({ ok: false, reason: 'NO_DUEL' }, 404);

    // ── ٣) نداء idempotent بعد الإقفال ⇒ النتيجة المخزنة نفسها ──
    if (duel.status === 'done' && duel.winner_device) {
      return json({
        ok: true,
        already: true,
        duel_id: duel.id,
        host_score: duel.host_score,
        guest_score: duel.guest_score,
        winner_device: duel.winner_device,
      });
    }
    if (duel.status !== 'live' || !duel.started_at)
      return json({ ok: false, reason: 'NOT_LIVE' }, 409);

    // ── ٤) منادي مشارك؟ (يحدد جهازه أيضاً) ──
    const participants = [duel.host_device, duel.guest_device].filter(
      (x): x is string => x !== null,
    );
    const { data: myDevices } = await admin
      .from('devices')
      .select('id')
      .eq('profile_id', uid)
      .in('id', participants);
    const callerDevice = myDevices?.[0]?.id as string | undefined;
    if (!callerDevice) return json({ ok: false, reason: 'NOT_PARTICIPANT' }, 403);

    // ── ٥) اتساق البذرة مع النطاق (tag داخل البذرة = tag النطاق) ──
    const scope = duel.scope;
    // شكل النطاق (كتبه المضيف عبر PostgREST — 0007 يقيّده بالقاعدة، وهذا قفل ثانٍ)
    if (typeof scope !== 'object' || scope === null ||
        !Array.isArray(scope.units) || scope.units.length === 0 || scope.units.length > 5 ||
        !scope.units.every((u: unknown) => typeof u === 'string' && /^U[1-5]$/.test(u)) ||
        typeof scope.count !== 'number' || !Number.isInteger(scope.count) ||
        scope.count < 1 || scope.count > 50)
      return json({ ok: false, reason: 'SCOPE_SHAPE' }, 422);
    const seed = BigInt(duel.seed_text); // bigint موقّع — البذرة < 2^63 بالبناء
    const tag = await scopeTagOf(scope);
    if (Number(seed >> 50n) !== tag)
      return json({ ok: false, reason: 'SCOPE_MISMATCH' }, 422);

    // ── ٦) بنك المعتمد من القاعدة — فهرس الفصول خادمي حصراً ──
    const { data: bankRows, error: bankErr } = await admin
      .from('content_questions')
      .select('id, chapter_index, correct_index, options_n')
      .in('unit', scope.units);
    if (bankErr)
      return json({ ok: false, reason: 'CONTENT_INTERNAL' }, 500);
    const bank: BankRow[] = (bankRows ?? []).map((r) => ({
      id: r.id as number,
      chapterIndex: r.chapter_index as number,
      correctIndex: r.correct_index as number,
      optionsN: r.options_n as number,
    }));
    if (bank.length < scope.count)
      return json({ ok: false, reason: 'CONTENT_MISSING' }, 422);

    // ── ٧) إعادة التوليد من البذرة — مرجعية الحكم ──
    const session = buildSessionFromBank(seed, scope.count, bank);
    const rowById = new Map(bank.map((b) => [b.id, b]));
    const correctDisplay: number[] = session.questionIds.map((qid) =>
      displayCorrectIndex(rowById.get(qid)!, session.optionOrders.get(qid)!),
    );

    // ── ٨) الإجابات المخزنة — أي تعارض يرفض الكل ──
    const { data: answersRaw, error: ansErr } = await admin
      .from('duel_answers')
      .select('device_id, q_index, chosen')
      .eq('duel_id', duelId);
    if (ansErr) return json({ ok: false, reason: 'ANSWERS_INTERNAL' }, 500);
    const optionsOfQ = new Map<number, number>();
    session.questionIds.forEach((qid, i) =>
      optionsOfQ.set(i, rowById.get(qid)!.optionsN),
    );
    const byDevice = new Map<string, Map<number, number>>();
    for (const a of answersRaw ?? []) {
      const qi = a.q_index as number;
      const ch = a.chosen as number;
      if (qi < 0 || qi >= session.questionIds.length || ch < 0 ||
          ch >= (optionsOfQ.get(qi) ?? 0))
        return json({ ok: false, reason: 'BAD_ANSWER' }, 422);
      if (!byDevice.has(a.device_id)) byDevice.set(a.device_id, new Map());
      byDevice.get(a.device_id)!.set(qi, ch);
    }

    // ── ٩) اكتمال الطرفين (إعلان، أو إجابات كاملة، أو مهلة فائتة) ──
    const { data: statuses } = await admin
      .from('duel_status')
      .select('device_id')
      .eq('duel_id', duelId);
    const doneSet = new Set((statuses ?? []).map((s) => s.device_id as string));
    const deadlineMs =
      new Date(duel.started_at!).getTime() +
      scope.count * QUESTION_SECONDS * 1000 +
      GRACE_MS;
    const deadlinePassed = Date.now() > deadlineMs;
    const opponent =
      callerDevice === duel.host_device ? duel.guest_device : duel.host_device;
    const opponentDone =
      opponent === null ||
      doneSet.has(opponent) ||
      (byDevice.get(opponent)?.size ?? 0) >= session.questionIds.length ||
      deadlinePassed;
    if (doneSet.has(callerDevice) === false && !deadlinePassed) {
      return json({ ok: false, reason: 'NOT_DONE_YET' }, 409);
    }
    if (!opponentDone) return json({ ok: false, reason: 'WAITING_OPPONENT' }, 409);

    // ── ١٠) التصحيح: نقاط ×متتالية (٣⇒×٢، ٦⇒×٣) — مطابق العميل ──
    const grade = (device: string | null) => {
      let score = 0;
      let corrects = 0;
      let streak = 0;
      if (device !== null) {
        const mine = byDevice.get(device) ?? new Map<number, number>();
        session.questionIds.forEach((_qid, i) => {
          const chosen = mine.get(i);
          if (chosen !== undefined && chosen === correctDisplay[i]) {
            streak++;
            corrects++;
            const mult = streak >= 6 ? 3 : streak >= 3 ? 2 : 1;
            score += POINTS_PER_CORRECT * mult;
          } else {
            streak = 0;
          }
        });
      }
      return { score, corrects };
    };
    const hostG = grade(duel.host_device);
    const guestG = grade(duel.guest_device);

    // ── ١١) الحسم: نقاط ← صحيحات ← عملة streamC (docs/12 §٢.٣) ──
    let winner: string;
    let tieBreak: 'score' | 'corrects' | 'coin';
    if (hostG.score !== guestG.score) {
      winner = hostG.score > guestG.score ? duel.host_device : duel.guest_device!;
      tieBreak = 'score';
    } else if (hostG.corrects !== guestG.corrects) {
      winner =
        hostG.corrects > guestG.corrects ? duel.host_device : duel.guest_device!;
      tieBreak = 'corrects';
    } else {
      const coin = stream((seed ^ STREAM_C) & MASK)();
      winner = coin % 2n === 0n ? duel.host_device : duel.guest_device!;
      tieBreak = 'coin';
    }

    // ── ١٢) الإقفال الذري (من live حصراً — التزامن بين نداءين آمن) ──
    const { data: updated, error: upErr } = await admin
      .from('duels')
      .update({
        status: 'done',
        host_score: hostG.score,
        guest_score: guestG.score,
        winner_device: winner,
        ended_at: new Date().toISOString(),
      })
      .eq('id', duelId)
      .eq('status', 'live')
      .select('id')
      .maybeSingle();
    if (upErr) return json({ ok: false, reason: 'COMMIT_INTERNAL' }, 500);
    if (!updated) {
      // نداء آخر أقفلها بين القراءة والكتابة ⇒ النتيجة المخزنة هي المرجع
      const { data: again } = await admin
        .from('duels')
        .select('*, seed_text:seed::text')
        .eq('id', duelId)
        .maybeSingle<DuelRow>();
      if (again?.status === 'done' && again.winner_device) {
        return json({
          ok: true,
          already: true,
          duel_id: again.id,
          host_score: again.host_score,
          guest_score: again.guest_score,
          winner_device: again.winner_device,
        });
      }
      return json({ ok: false, reason: 'COMMIT_RACE' }, 409);
    }

    return json({
      ok: true,
      already: false,
      duel_id: duel.id,
      host_score: hostG.score,
      guest_score: guestG.score,
      winner_device: winner,
      tie_break: tieBreak,
      corrects: correctDisplay, // كشف الصحيح بالعرض لكل سؤال (ترتيب الجلسة)
      my_device: callerDevice,
    });
  } catch (e) {
    return json({ ok: false, reason: 'INTERNAL', detail: String(e) }, 500);
  }
});
