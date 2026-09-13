import { buildSessionFromBank, mix64, stream, STREAM_C, scopeTagOf } from '/home/user/Almorshed/supabase/functions/_shared/duel_session.ts';

// ١) متجهات mix64 الذهبية (من اختبار Dart الأصلي)
const assert = (cond: boolean, name: string) => { if (!cond) { console.error('FAIL', name); process.exit(1); } };
assert(mix64(0n) === 0xE220A8397B1DCDAFn, 'mix64(0)');
assert(mix64(1n) === 0x910A2DEC89025CC1n, 'mix64(1)');
assert(mix64((1n<<64n)-1n) === 0xE4D971771B652C20n, 'mix64(max)');
assert(mix64(0x1234567890ABCDEFn) === 0x1C948E1575796814n, 'mix64(golden)');
const g = stream(0x1234567890ABCDEFn);
assert(g() === 0x1C948E1575796814n && g() === 0xAE9EF1AB67004BDBn && g() === 0x7A2988D31F16E86En && g() === 0x7A5DAEA24EBA3BA7n && g() === 0xBB83C0C2207AD3E6n, 'stream golden 5');

// ٢) متجه المبارزة الاصطناعي (مطابق Python)
const bank = [];
const chapters = ['U1C1','U1C2','U2C1','U2C2','U3C1'];
for (let i = 0; i < 15; i++) {
  bank.push({ id: i+1, chapterIndex: i%5, correctIndex: i%4, optionsN: 4 });
}
const seed = (2852n << 50n) | 676889741750429n;
const s = buildSessionFromBank(seed, 10, bank);
console.log('ids:', JSON.stringify(s.questionIds));
console.log('corrects:', JSON.stringify(s.questionIds.map(qid => s.optionOrders.get(qid)!.indexOf(bank[qid-1].correctIndex))));
assert(JSON.stringify(s.questionIds) === JSON.stringify([11,12,3,4,5,1,2,8,9,10]), 'ids golden');
assert(JSON.stringify(s.questionIds.map(qid => s.optionOrders.get(qid)!.indexOf(bank[qid-1].correctIndex))) === JSON.stringify([1,1,3,1,0,1,1,1,3,0]), 'corrects golden');
const coin = stream((seed ^ STREAM_C))();
console.log('coin:', coin % 2n === 0n ? 0 : 1);
assert(coin % 2n === 1n, 'coin golden');

// ٣) البذرة موجبة وتطابق دلالة int Dart (تعادل بتّي)
assert(Number(seed >> 50n) === 2852, 'tag extraction');
assert(seed === 3211743424056914077n, 'seed golden');

// ٤) scopeTag يطابق 2852 (WebCrypto)
const tag = await scopeTagOf({ units: ['U1','U2','U3'], count: 10, mode: 'quiz', pack: 'test-pack-1' });
console.log('scopeTag:', tag);
assert(tag === 2852, 'scopeTag golden');
console.log('TS PORT = PYTHON = DART ✓✓✓');
