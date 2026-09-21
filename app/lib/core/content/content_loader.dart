import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../crypto/content_key_vault.dart';
import '../crypto/content_seal.dart';
import 'models.dart';
import 'term_linter.dart';

/// محمّل الحزمة — F2.2 (قرارات ١٣: مخزون مسبق · ٣٠/٦٧: تشفير pack_seal_v1 ·
/// ٦: نسخة+طبعة).
///
/// الواجهة ثابتة (loadGlossary/loadPack): بلا خزنة مفتاح أو بلا K_c ⇒ قراءة
/// نصية من assets كالسابق (مسار العرض/الحزمة التجريبية — docs/11 §٥)؛
/// بخزنة فيها K_c ⇒ فكّ pack_seal_v1 من الأصول المشفرة في الذاكرة حصراً.
class ContentLoader {
  ContentLoader({AssetRoot? root, ContentKeyVault? keys})
      : _root = root ?? const AssetRoot.defaults(),
        _keys = keys;

  final AssetRoot _root;
  final ContentKeyVault? _keys;

  Glossary? _glossaryCache;
  ContentPack? _packCache;

  /// القاموس المعجمي الكامل (444 مدخلاً · 30 BAN · مرادفات SYN).
  Future<Glossary> loadGlossary() async {
    if (_glossaryCache != null) return _glossaryCache!;
    final raw = await _loadSource(_root.glossaryPath, _root.sealedGlossaryPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final g = Glossary.fromJson(json);
    _glossaryCache = g;
    return g;
  }

  /// حزمة المحتوى + فحص سلامة إلزامي قبل العودة (الفشل المبكر).
  Future<ContentPack> loadPack() async {
    if (_packCache != null) return _packCache!;
    final raw = await _loadSource(_root.packPath, _root.sealedPackPath);
    final pack = ContentPack.fromJsonString(raw);
    _assertHealthy(pack);
    _packCache = pack;
    return pack;
  }

  /// مصدر المتن: نصي بلا مفتاح · مشفر pack_seal_v1 بوجود K_c (قرار ٣٠).
  ///
  /// استثناء ContentSealException يمرّ كما هو (عبث/مفتاح خاطئ)؛ ما عداه
  /// يُغلَّف بفشل مبكر موصوف (قرار ٦: صفر تسامح مع الناقص).
  Future<String> _loadSource(String plainPath, String sealedPath) async {
    final kc = await _keys?.read();
    if (kc == null) return rootBundle.loadString(plainPath);
    final data = await rootBundle.load(sealedPath);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    try {
      final clear = await ContentSeal.open(bytes, key: kc);
      return utf8.decode(clear);
    } on ContentSealException {
      rethrow;
    } catch (e) {
      throw StateError('حزمة مشفرة غير سليمة ($sealedPath): $e');
    }
  }

  /// فحص السلامة — أي خلل بنيوي يُرمى فوراً (قرار ٦: صفر تسامح مع الناقص).
  void _assertHealthy(ContentPack pack) {
    final problems = <String>[];

    // كل سؤال/بطاقة يجب أن يرجع لوحدة وفصلاً موجودين فعلاً.
    final unitIds = pack.units.map((u) => u.id).toSet();
    final chapterIds = pack.units
        .expand((u) => u.chapters.map((c) => c.id))
        .toSet();

    for (final q in pack.questions) {
      if (!unitIds.contains(q.unit)) {
        problems.add('Q${q.id}: وحدة غير معروفة ${q.unit}');
      }
      if (!chapterIds.contains(q.chapter)) {
        problems.add('Q${q.id}: فصل غير معروف ${q.chapter}');
      }
      if (q.options.length < 2) problems.add('Q${q.id}: خيارات أقل من اثنين');
      if (q.correctIndex < 0 || q.correctIndex >= q.options.length) {
        problems.add('Q${q.id}: correctIndex خارج النطاق');
      }
    }
    for (final c in pack.cards) {
      if (!unitIds.contains(c.unit)) problems.add('C${c.id}: وحدة غير معروفة');
      if (!chapterIds.contains(c.chapter)) {
        problems.add('C${c.id}: فصل غير معروف');
      }
    }
    if (pack.units.isEmpty) problems.add('الحزمة بلا وحدات');

    if (problems.isNotEmpty) {
      throw StateError('حزمة غير سليمة (${problems.length}):\n'
          '${problems.take(10).join('\n')}');
    }
  }

  /// فحص Lint كامل — يُستدعى في الاختبارات وأدوات البناء (يمنع BAN حرفياً
  /// من الوصول للمستخدم عبر الحزمة المُحمَّلة — F2.4 أساس).
  Future<Map<String, List<LintIssue>>> lintLoadedPack() async {
    final pack = await loadPack();
    final g = await loadGlossary();
    return TermLinter.lintPack(
      pack,
      banned: g.banned.toSet(),
      synonyms: g.synonyms,
    );
  }
}

class AssetRoot {
  const AssetRoot({
    required this.glossaryPath,
    required this.packPath,
    this.sealedGlossaryPath = 'assets/content/glossary.json.sealed',
    this.sealedPackPath = 'assets/content/pack.json.sealed',
  });

  const AssetRoot.defaults()
      : glossaryPath = 'assets/content/glossary.json',
        packPath = 'assets/content/pack.json',
        sealedGlossaryPath = 'assets/content/glossary.json.sealed',
        sealedPackPath = 'assets/content/pack.json.sealed';

  final String glossaryPath;
  final String packPath;

  /// مسارا pack_seal_v1 (يُقرأان حصراً عند وجود K_c — قرار ٣٠).
  final String sealedGlossaryPath;
  final String sealedPackPath;
}

/// القاموس المعجمي المفكوك.
class Glossary {
  Glossary({
    required this.version,
    required this.terms,
    required this.banned,
    required this.synonyms,
  });

  final String version;
  final List<Map<String, dynamic>> terms;
  final List<String> banned;
  final Map<String, String> synonyms;

  factory Glossary.fromJson(Map<String, dynamic> json) => Glossary(
        version: json['glossary_version'] as String? ?? '',
        terms: (json['terms'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
        banned: (json['banned'] as List<dynamic>).cast<String>(),
        synonyms: (json['synonyms'] as Map<String, dynamic>)
            .cast<String, String>(),
      );

  int get termCount => terms.length;
}
