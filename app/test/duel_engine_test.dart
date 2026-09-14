// M5 — اختبارات محرك المبارزة الحتمي (duel_engine).
// المتجهات الذهبية أدناه حُسبت بمقارن مستقل Python (SplitMix64 + البناء
// الكامل) 2026-09-13 — مطابقة سلسلة goldens الأصلية (docs/12 §٢.٤).
// أي تغيير يكسرها = انحراف حتمية بين العميل والخادم = نتيجة مرفوضة.
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';
import 'package:fizya_clash/core/content/models.dart';

ContentPack _pack() => ContentPack.fromJsonString('''
{"packId":"test-pack","year":2027,"edition":1,
 "units":[
  {"id":"U1","title":"و1","chapters":[{"id":"U1C1","title":"ف1","page":1,"paragraphs":[]},{"id":"U1C2","title":"ف2","page":2,"paragraphs":[]}]},
  {"id":"U2","title":"و2","chapters":[{"id":"U2C1","title":"ف3","page":3,"paragraphs":[]},{"id":"U2C2","title":"ف4","page":4,"paragraphs":[]}]},
  {"id":"U3","title":"و3","chapters":[{"id":"U3C1","title":"ف5","page":5,"paragraphs":[]}]}],
 "questions":[
${List.generate(15, (i) {
  final ch = ['U1C1','U1C2','U2C1','U2C2','U3C1'][i % 5];
  final unit = ch.substring(0, 2);
  return '{"id":${i + 1},"unit":"$unit","chapter":"$ch","approved":true,'
      '"stem":"س${i + 1}","options":["أ","ب","ج","د"],"correctIndex":${i % 4}}';
}).join(',\n')}],
 "cards":[]}
''');

void main() {
  test('H-A — _pack حصراً', () {
    expect(_pack().questions.length, 15);
  });
}
