// F6.5 — currentSeason(): مرآة حرفية لدالة current_season() الخادمية (0011).
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/cert/certificate.dart';

void main() {
  // الموسم يبدأ ١ أيلول بتوقيت دمشق (UTC+3).
  test('أيلول ← بداية موسم جديد', () {
    // 2026-09-01 00:00 دمشق = 2026-08-31 21:00 UTC
    expect(currentSeason(DateTime.utc(2026, 9, 1, 0, 0)), '2026-2027');
  });

  test('آب ← لا يزال الموسم السابق', () {
    expect(currentSeason(DateTime.utc(2026, 8, 15)), '2025-2026');
  });

  test('حدّ ١ أيلول عند منتصف الليل بدمشق يقع في الموسم الجديد', () {
    // 2026-08-31 21:00 UTC = 2026-09-01 00:00 دمشق ⇒ الموسم الجديد
    expect(currentSeason(DateTime.utc(2026, 8, 31, 21, 0)), '2026-2027');
  });

  test('قبيل منتصف ليل ١ أيلول بدمشق لا يزال الموسم السابق', () {
    // 2026-08-31 20:59 UTC = 2026-08-31 23:59 دمشق ⇒ الموسم السابق
    expect(currentSeason(DateTime.utc(2026, 8, 31, 20, 59)), '2025-2026');
  });

  test('كانون الثاني ← منتصف الموسم', () {
    expect(currentSeason(DateTime.utc(2027, 1, 10)), '2026-2027');
  });
}
