import '../../core/content/models.dart';

/// تقدم قراءة فصل واحد (F3.1).
class ChapterProgress {
  const ChapterProgress({this.cursor = 0, this.completed = false});

  final int cursor;
  final bool completed;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'cursor': cursor, 'completed': completed};

  factory ChapterProgress.fromJson(Map<String, dynamic> json) =>
      ChapterProgress(
        cursor: (json['cursor'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as bool?) ?? false,
      );
}

/// لقطة تقدم القراءة كاملة (مفتاحها معرف الفصل).
class ReadProgress {
  const ReadProgress({this.chapters = const {}});

  final Map<String, ChapterProgress> chapters;

  Set<String> get completedIds => chapters.entries
      .where((e) => e.value.completed)
      .map((e) => e.key)
      .toSet();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chapters': {
          for (final e in chapters.entries) e.key: e.value.toJson(),
        },
      };

  factory ReadProgress.fromJson(Map<String, dynamic> json) => ReadProgress(
        chapters: {
          for (final e
              in ((json['chapters'] as Map<String, dynamic>?) ?? const {}))
            e.key: ChapterProgress.fromJson(e.value as Map<String, dynamic>),
        },
      );
}

/// نسبة إنجاز الوحدة ٠–١٠٠ — دالة خالصة قابلة للاختبار (F3.1).
int unitPercent(Unit unit, Set<String> completedIds) {
  final total = unit.chapters.length;
  if (total == 0) return 0;
  final done =
      unit.chapters.where((c) => completedIds.contains(c.id)).length;
  return (done * 100 / total).round();
}

/// واجهة التخزين — التنفيذ الفعلي shared_preferences، وزائف للاختبارات.
/// قرار ٥٧: تقدم القراءة KV يكفيه shared_preferences؛ والـDrift يُؤجل
/// لدفتر XP (F7) حيث تُلزم المعاملات — والواجهة تجعل الترحيل رخيصاً.
abstract class ProgressStore {
  Future<ReadProgress> load();
  Future<void> save(ReadProgress progress);
}

/// زائف الذاكرة — للاختبارات وللحقن.
class InMemoryProgressStore implements ProgressStore {
  ReadProgress _progress = const ReadProgress();

  @override
  Future<ReadProgress> load() async => _progress;

  @override
  Future<void> save(ReadProgress progress) async {
    _progress = progress;
  }
}
