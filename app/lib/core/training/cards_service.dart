/// F3.4 — خدمة البطاقات الخالصة: طابور اليوم (سقف ٢٠ + ٦ جديدة) وتطبيق
/// التقييمات عبر FSRS-5 (قرار ٤٢: أزرار ٣ — استبعاد easy عمداً).
/// الحتمية: نفس (dateKey, الحالات) ⇒ نفس الطابور — ويُجمَّد لليوم كله
/// (نمط «مهام اليوم»: صباحاً ومساءً واحدة).
library;

import '../content/models.dart';
import '../fsrs/fsrs5.dart';
import 'batch_builder.dart';
import 'training_store.dart';

/// سقف بطاقات اليوم (docs/14 — F3.4).
const int cardQueueCap = 20;

/// أقصى بطاقات جديدة في اليوم الواحد.
const int newCardsPerDay = 6;

/// بناء طابور اليوم من الحالات الحالية (لا يحفظ — الحفظ بيد الواجهة):
/// المستحقة أولاً (الأقدم استحقاقاً ثم الأصغر معرفاً) ثم الجديد الجديد
/// (الأصغر معرفاً، حتى newCardsPerDay) — ومقصوص بالسقف.
List<int> buildCardQueue({
  required List<CardItem> cards,
  required Map<int, CardStateData> states,
  required String dateKey,
  int cap = cardQueueCap,
  int newPerDay = newCardsPerDay,
}) {
  final due = <CardStateData>[];
  for (final s in states.values) {
    if (s.isDueOnOrAfter(dateKey)) due.add(s);
  }
  due.sort((a, b) {
    final byDue = a.dueDateKey.compareTo(b.dueDateKey);
    return byDue != 0 ? byDue : a.cardId.compareTo(b.cardId);
  });

  final knownIds = states.keys.toSet();
  final fresh = [
    for (final c in cards)
      if (!knownIds.contains(c.id)) c.id,
  ]..sort();

  final queue = <int>[
    for (final s in due) s.cardId,
    ...fresh.take(newPerDay),
  ];
  return queue.length > cap ? queue.sublist(0, cap) : queue;
}

/// حالة بطاقة جديدة مرتُّبعة الآن: FSRS يحدّث الذاكرة والاستحقاق من اليوم.
CardStateData reviewCard({
  required CardStateData? previous,
  required int cardId,
  required Grade grade,
  required String todayKey,
}) {
  final memory = previous == null
      ? CardMemory.newCard()
      : (CardMemory.newCard()
        ..difficulty = previous.difficulty
        ..stability = previous.stability
        ..reviews = previous.reviews
        ..lapses = previous.lapses);
  final reviewed = Fsrs5.review(memory, grade);
  final days = Fsrs5.nextIntervalDays(reviewed).round();
  return CardStateData(
    cardId: cardId,
    difficulty: reviewed.difficulty,
    stability: reviewed.stability,
    reviews: reviewed.reviews,
    lapses: reviewed.lapses,
    dueDateKey: dateKeyAfter(todayKey, days < 1 ? 1 : days),
  );
}

/// تطبيق تقييم بطاقة على كامل البيانات (خالصة): تحديث الحالة + تقدّم اليوم.
TrainingData applyCardReview(
  TrainingData data, {
  required int cardId,
  required Grade grade,
  required String todayKey,
}) {
  final day = data.cardDay;
  if (day == null || day.dateKey != todayKey || day.finished) return data;
  final states = {...data.cardStates};
  states[cardId] = reviewCard(
    previous: data.cardStates[cardId],
    cardId: cardId,
    grade: grade,
    todayKey: todayKey,
  );
  return TrainingData(
    daily: data.daily,
    mistakes: data.mistakes,
    cardStates: states,
    cardDay: day.advance(),
  );
}

/// تجهيز يوم البطاقات: يجمد طابور اليوم إذا لم يكن مجمداً (أو تغيّر اليوم).
/// يرجع البيانات المحدثة — الواجهة تحفظها ثم تفتح جلسة المراجعة.
TrainingData startCardDay(
  TrainingData data, {
  required List<CardItem> cards,
  required String todayKey,
}) {
  final existing = data.cardDay;
  if (existing != null && existing.dateKey == todayKey) return data;
  final queue = buildCardQueue(
    cards: cards,
    states: data.cardStates,
    dateKey: todayKey,
  );
  if (queue.isEmpty) return data;
  return TrainingData(
    daily: data.daily,
    mistakes: data.mistakes,
    cardStates: data.cardStates,
    cardDay: CardDayState(dateKey: todayKey, queue: queue),
  );
}

/// طابور اليوم الفعلي: المجمد إن كان لليوم، وإلا بناء استباقي للعرض حصراً.
List<int> todayCardQueue(TrainingData data, List<CardItem> cards,
    String todayKey) {
  final frozen = data.cardDay;
  if (frozen != null && frozen.dateKey == todayKey) return frozen.queue;
  return buildCardQueue(cards: cards, states: data.cardStates, dateKey: todayKey);
}
