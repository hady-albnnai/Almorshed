/// F3.3 — تخزين التدريب: دفعة اليوم (قابلة للاستئناف) + أرشيف أخطائي.
/// قرار ٥٧: KV يكفي الآن؛ أي ترحيل مستقبلي يتم خلف نفس الواجهة.
library;

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

/// F3.4 — حالة ذاكرة بطاقة محفوظة (DSR + الاستحقاق).
class CardStateData {
  const CardStateData({
    required this.cardId,
    required this.difficulty,
    required this.stability,
    required this.reviews,
    required this.lapses,
    required this.dueDateKey,
  });

  final int cardId;

  /// الصعوبة D ∈ [1,10] والثبات S بالأيام (نموذج DSR — قرار ٤٢).
  final double difficulty;
  final double stability;
  final int reviews;
  final int lapses;

  /// أول يوم تستحق فيه المراجعة ('YYYY-MM-DD').
  final String dueDateKey;

  bool isDueOnOrAfter(String todayKey) => todayKey.compareTo(dueDateKey) >= 0;

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'difficulty': difficulty,
        'stability': stability,
        'reviews': reviews,
        'lapses': lapses,
        'dueDateKey': dueDateKey,
      };

  factory CardStateData.fromJson(Map<String, dynamic> json) => CardStateData(
        cardId: json['cardId'] as int,
        difficulty: (json['difficulty'] as num).toDouble(),
        stability: (json['stability'] as num).toDouble(),
        reviews: json['reviews'] as int,
        lapses: json['lapses'] as int,
        dueDateKey: json['dueDateKey'] as String,
      );
}

/// F3.4 — حالة طابور البطاقات لليوم (مجمد عند أول بناء — عدالة مهام اليوم).
class CardDayState {
  const CardDayState({
    required this.dateKey,
    required this.queue,
    this.doneCount = 0,
    this.finished = false,
  });

  final String dateKey;

  /// معرفات البطاقات بترتيب المراجعة (≤ سقف ٢٠).
  final List<int> queue;
  final int doneCount;
  final bool finished;

  CardDayState advance() => CardDayState(
        dateKey: dateKey,
        queue: queue,
        doneCount: doneCount + 1,
        finished: doneCount + 1 >= queue.length,
      );

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'queue': queue,
        'doneCount': doneCount,
        'finished': finished,
      };

  factory CardDayState.fromJson(Map<String, dynamic> json) => CardDayState(
        dateKey: json['dateKey'] as String,
        queue: (json['queue'] as List<dynamic>).cast<int>(),
        doneCount: json['doneCount'] as int? ?? 0,
        finished: json['finished'] as bool? ?? false,
      );
}

/// بيانات التدريب ككتلة واحدة — مفتاح تخزين واحد training_v1.
/// F3.4: أُضيفت حالات البطاقات وطابور يومها — حقول اختيارية
/// (بيانات قديمة بلاها تُقرأ بقيم افتراضية — توافق خلفي كامل).
class TrainingData {
  const TrainingData({
    this.daily,
    this.mistakes = const [],
    this.cardStates = const {},
    this.cardDay,
    this.labChallengeDoneDateKey,
    this.labChallengeDays = const {},
  });

  /// حالة دفعة اليوم (null ⇒ لا دفعة محفوظة).
  final DailyBatchState? daily;

  /// أرشيف الأخطاء — الأحدث أولاً.
  final List<MistakeRecord> mistakes;

  /// F3.4 — حالة ذاكرة كل بطاقة مرتُّبعة.
  final Map<int, CardStateData> cardStates;

  /// F3.4 — طابور البطاقات لليوم (null ⇒ لم يُبنَ بعد).
  final CardDayState? cardDay;

  /// F3.5 — يوم إنجاز تحدي المختبر «اجعل T=٢ث» (+١٠ بسقف يومي — docs/12 §٦).
  final String? labChallengeDoneDateKey;

  /// المادة ١٤ — يوم إنجاز تحدّي كل تجربة من الخمس: {experimentId: dateKey}
  /// (النابض يبقى على حقله القديم). حدث XP واحد `labChallenge` مرة/يوم.
  final Map<String, String> labChallengeDays;

  /// نسخة معدّلة — تحفظ كل الحقول الأخرى كما هي (بدل إعادة بنائها يدوياً).
  TrainingData copyWith({
    DailyBatchState? daily,
    List<MistakeRecord>? mistakes,
    Map<int, CardStateData>? cardStates,
    CardDayState? cardDay,
    String? labChallengeDoneDateKey,
    Map<String, String>? labChallengeDays,
  }) =>
      TrainingData(
        daily: daily ?? this.daily,
        mistakes: mistakes ?? this.mistakes,
        cardStates: cardStates ?? this.cardStates,
        cardDay: cardDay ?? this.cardDay,
        labChallengeDoneDateKey:
            labChallengeDoneDateKey ?? this.labChallengeDoneDateKey,
        labChallengeDays: labChallengeDays ?? this.labChallengeDays,
      );

  Map<String, dynamic> toJson() => {
        'daily': daily?.toJson(),
        'mistakes': [for (final m in mistakes) m.toJson()],
        'cardStates': {
          for (final e in cardStates.entries) '${e.key}': e.value.toJson(),
        },
        'cardDay': cardDay?.toJson(),
        if (labChallengeDoneDateKey != null)
          'labChallengeDoneDateKey': labChallengeDoneDateKey,
        if (labChallengeDays.isNotEmpty) 'labChallengeDays': labChallengeDays,
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
        cardStates: {
          // النوع الصريح + .entries إلزاميان (علّتا F3.1 الموثقتان)
          for (final e in (json['cardStates'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .entries)
            int.parse(e.key):
                CardStateData.fromJson(e.value as Map<String, dynamic>),
        },
        cardDay: json['cardDay'] == null
            ? null
            : CardDayState.fromJson(json['cardDay'] as Map<String, dynamic>),
        labChallengeDoneDateKey:
            json['labChallengeDoneDateKey'] as String?,
        labChallengeDays: {
          for (final e in (json['labChallengeDays'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .entries)
            e.key: e.value as String,
        },
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
  return data.copyWith(mistakes: merged); // يحفظ البطاقات وأيام التحدي
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
