/// F3.3 — تخزين التدريب: دفعة اليوم (قابلة للاستئناف) + أرشيف أخطائي.
/// قرار ٥٧: KV يكفي الآن؛ أي ترحيل مستقبلي يتم خلف نفس الواجهة.

/// حالة دفعة اليوم — تُحفظ مع كل إجابة ليعمل الاستئناف داخل اليوم نفسه.
class DailyBatchState {
  const DailyBatchState({
    required this.dateKey,
    required this.order,
    Map<int, int>? answers,
    this.done = false,
    this.score = 0,
  }) : answers = answers ?? const {};

  /// مفتاح اليوم المحلي 'YYYY-MM-DD' — التناوب عند منتصف الليل المحلي.
  final String dateKey;

  /// معرفات الأسئلة بترتيب الجلسة (≤ ١٠) — محفوظ فلا يتغير بفتح لاحق.
  final List<int> order;

  /// معرف السؤال ← فهرس الخيار المعروض المختار.
  final Map<int, int> answers;

  /// اكتملت الدفعة (لا إعادة في اليوم نفسه).
  final bool done;

  /// عدد الصحيح عند الإتمام.
  final int score;

  bool get isFinished => done;
  int get answeredCount => answers.length;

  DailyBatchState withAnswer(int questionId, int selectedIndex) =>
      DailyBatchState(
        dateKey: dateKey,
        order: order,
        answers: {...answers, questionId: selectedIndex},
        done: done,
        score: score,
      );

  DailyBatchState finish(int finalScore) => DailyBatchState(
        dateKey: dateKey,
        order: order,
        answers: answers,
        done: true,
        score: finalScore,
      );

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'order': order,
        'answers': {
          for (final e in answers.entries) '${e.key}': e.value,
        },
        'done': done,
        'score': score,
      };

  factory DailyBatchState.fromJson(Map<String, dynamic> json) =>
      DailyBatchState(
        dateKey: json['dateKey'] as String,
        order: (json['order'] as List<dynamic>).cast<int>(),
        answers: {
          // ⚠️ النوع صريح إلزامي (علّة const {} → Set الموثقة F3.1)
          for (final e in ((json['answers'] as Map<String, dynamic>? ??
              const <String, dynamic>{})).entries)
            int.parse(e.key): e.value as int,
        },
        done: json['done'] as bool? ?? false,
        score: json['score'] as int? ?? 0,
      );
}

/// سجل خطأ واحد — الأحدث محل الأقدم لنفس السؤال.
class MistakeRecord {
  const MistakeRecord({
    required this.questionId,
    required this.chosenIndex,
    required this.correctIndex,
    required this.atMs,
  });

  final int questionId;
  final int chosenIndex;
  final int correctIndex;
  final int atMs;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'chosenIndex': chosenIndex,
        'correctIndex': correctIndex,
        'atMs': atMs,
      };

  factory MistakeRecord.fromJson(Map<String, dynamic> json) => MistakeRecord(
        questionId: json['questionId'] as int,
        chosenIndex: json['chosenIndex'] as int,
        correctIndex: json['correctIndex'] as int,
        atMs: json['atMs'] as int,
      );
}

/// بيانات التدريب ككتلة واحدة — مفتاح تخزين واحد training_v1.
class TrainingData {
  const TrainingData({this.daily, this.mistakes = const []});

  /// حالة دفعة اليوم (null ⇒ لا دفعة محفوظة).
  final DailyBatchState? daily;

  /// أرشيف الأخطاء — الأحدث أولاً.
  final List<MistakeRecord> mistakes;

  Map<String, dynamic> toJson() => {
        'daily': daily?.toJson(),
        'mistakes': [for (final m in mistakes) m.toJson()],
      };

  factory TrainingData.fromJson(Map<String, dynamic> json) => TrainingData(
        daily: json['daily'] == null
            ? null
            : DailyBatchState.fromJson(json['daily'] as Map<String, dynamic>),
        mistakes: [
          // النوع الصريح إلزامي (علّة const {} الموثقة)
          for (final m in (json['mistakes'] as List<dynamic>? ??
              const <dynamic>[]))
            MistakeRecord.fromJson(m as Map<String, dynamic>),
        ],
      );
}

/// دمج أخطاء جلسة جديدة بالأرشف — خالصة وقابلة للاختبار.
/// الأحدث يحل محل الأقدم لنفس questionId، والترتيب الزمني تنازلي.
TrainingData withNewMistakes(TrainingData data, List<MistakeRecord> added) {
  final byId = <int, MistakeRecord>{
    for (final m in data.mistakes) m.questionId: m,
    for (final m in added) m.questionId: m,
  };
  final merged = byId.values.toList()
    ..sort((a, b) => b.atMs.compareTo(a.atMs));
  return TrainingData(daily: data.daily, mistakes: merged);
}

/// واجهة تخزين التدريب — InMemory للاختبارات وSharedPrefs على الجهاز.
abstract class TrainingStore {
  Future<TrainingData> load();
  Future<void> save(TrainingData data);
}

/// تنفيذ بالذاكرة للاختبارات.
class InMemoryTrainingStore implements TrainingStore {
  TrainingData _data = const TrainingData();
  @override
  Future<TrainingData> load() async => _data;
  @override
  Future<void> save(TrainingData data) async => _data = data;
}
