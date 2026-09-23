/// F3.1 — قاعدة Drift المركزية المشفّرة (SQLCipher · قرار ٣٠).
///
/// • على الجهاز: تُفتح ملفاً `fizya_clash.db` في مجلد الدعم بالتطبيق، عبر
///   مكتبة **SQLCipher** الأصلية (AES-256) مع `PRAGMA key` من بذرة تُشتق
///   لمرة واحدة وتُخزَّن في `flutter_secure_storage` (Keystore على أندرويد).
/// • في الاختبارات: تُفتح قاعدة في الذاكرة بلا تشفير (NativeDatabase.memory)
///   عبر الباني `AppDatabase.forTesting(...)` — لا حاجة لملفات ولا لأسرار.
///
/// ⚠️ يعتمد على `app_database.g.dart` المولَّد بـ`build_runner` على جهاز
/// المالك (قرار ٥١):
///   flutter pub run build_runner build --delete-conflicting-outputs
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ChapterProgressRows,
    DailyBatchRows,
    MistakeRows,
    CardStateRows,
    CardDayRows,
    LabChallengeRows,
    XpEventRows,
    SettingsRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// الإنتاج: اتصال مشفّر كسول (يُفتح عند أول استعلام).
  AppDatabase() : super(_openEncrypted());

  /// الاختبارات/الحقن: تمرير تنفيذ صريح (عادةً NativeDatabase.memory()).
  AppDatabase.forExecutor(super.executor);

  /// اختبار مريح: قاعدة ذاكرة غير مشفّرة.
  factory AppDatabase.forTesting() =>
      AppDatabase.forExecutor(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {
          // فرض قيود المفاتيح الأجنبية (سلامة علائقية).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// اسم مفتاح البذرة في الخزنة الآمنة — بذرة قاعدة مستقلة عن مفاتيح المحتوى.
const String _kDbKeyName = 'db_sqlcipher_key_v1';

/// يفتح اتصالاً مشفّراً كسولاً بـSQLCipher:
/// أولاً يحمّل مكتبة SQLCipher الأصلية بدل sqlite العادي على أندرويد/iOS؛
/// ثم يقرأ/يشتق بذرة سرّية من الخزنة الآمنة (تُنشأ مرة واحدة)؛
/// ثم يطبّق PRAGMA key قبل أي عملية — فالملف مشفّر بالكامل على القرص.
LazyDatabase _openEncrypted() {
  return LazyDatabase(() async {
    // استخدم مكتبة SQLCipher الأصلية على المنصّات المحمولة.
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideForAll(openCipherOnAndroid);

    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'fizya_clash.db'));

    // بذرة التشفير — تُنشأ لمرة واحدة وتُحفظ في Keystore.
    final key = await _loadOrCreateDbKey();

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        // ضمان تحميل SQLCipher أيضاً داخل الأيزوليت الخلفي.
        open.overrideForAll(openCipherOnAndroid);
      },
      setup: (db) {
        // المفتاح أولاً — قبل أي جدول/استعلام.
        final quoted = key.replaceAll("'", "''");
        db.execute("PRAGMA key = '$quoted'");
        // تحقّق أن المكتبة فعلاً SQLCipher (وإلا cipher_version فارغ).
        final res = db.select('PRAGMA cipher_version');
        if (res.isEmpty) {
          throw StateError(
            'SQLCipher غير محمّل — cipher_version فارغ (تحقّق من '
            'sqlcipher_flutter_libs في البناء).',
          );
        }
      },
    );
  });
}

/// يقرأ بذرة القاعدة من الخزنة الآمنة أو ينشئها عشوائياً لأول مرة.
Future<String> _loadOrCreateDbKey() async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final existing = await storage.read(key: _kDbKeyName);
  if (existing != null && existing.isNotEmpty) return existing;

  // 32 بايت عشوائية قوية من مولّد النظام ⇒ hex (64 محرفاً).
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final hex = _bytesToHex(bytes);
  await storage.write(key: _kDbKeyName, value: hex);
  return hex;
}

String _bytesToHex(List<int> bytes) {
  const digits = '0123456789abcdef';
  final b = StringBuffer();
  for (final byte in bytes) {
    b.write(digits[(byte >> 4) & 0xf]);
    b.write(digits[byte & 0xf]);
  }
  return b.toString();
}
