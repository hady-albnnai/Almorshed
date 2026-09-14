// M6/F6.1-إدارة — اختبارات نماذج أداة المكتب (بلا شبكة — تحليل خالص).
// يثبت أن عميل Dart يقرأ ردّ فعل stats كما يرسله office_codes حرفياً.
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/office_api.dart';

void main() {
  test('OfficeStats من JSON — الحقول الأربعة', () {
    final s = OfficeStats.fromJson(const {
      'issued': 5,
      'activated': 12,
      'revoked': 2,
      'activeLicenses': 13,
    });
    expect(s.issued, 5);
    expect(s.activated, 12);
    expect(s.revoked, 2);
    expect(s.activeLicenses, 13);
  });

  test('OfficeStats من JSON ناقص — أصفار بلا انفجار', () {
    final s = OfficeStats.fromJson(const {});
    expect(s.activated, 0);
    expect(s.issued, 0);
  });

  test('Subscriber من JSON — كامل', () {
    final s = Subscriber.fromJson(const {
      'code': 'K7M2P-9QW4X-ABCDE',
      'status': 'activated',
      'distributor': 'مكتب لورانيم',
      'release_id': '2027-v1',
      'devices_used': 2,
      'created_at': '2026-09-14T10:00:00Z',
      'activated_at': '2026-09-14T11:30:00Z',
    });
    expect(s.code, 'K7M2P-9QW4X-ABCDE');
    expect(s.status, 'activated');
    expect(s.active, isTrue);
    expect(s.devicesUsed, 2);
    expect(s.distributor, 'مكتب لورانيم');
    expect(s.releaseId, '2027-v1');
  });

  test('Subscriber — حالات الحالة الفعالة/الملغاة/المصدرة', () {
    expect(Subscriber.fromJson(const {'status': 'activated'}).active, isTrue);
    expect(Subscriber.fromJson(const {'status': 'revoked'}).active, isFalse);
    expect(Subscriber.fromJson(const {'status': 'issued'}).active, isFalse);
  });

  test('استثناء أداة المكتب — forbidden يلتقط 403 للمفتاح الخاطئ', () {
    const e = OfficeApiException('FORBIDDEN', 403);
    expect(e.forbidden, isTrue);
    const e2 = OfficeApiException('INTERNAL', 500);
    expect(e2.forbidden, isFalse);
  });
}
