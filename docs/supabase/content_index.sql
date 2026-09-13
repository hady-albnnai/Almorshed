-- ═══ مولَّد آلياً بـ tools/gen_content_index.py — لا تحرير يدوي ═══
-- بنك المبارزات: المعتمد حصراً (قرار ٢٤) — معرفات بلا نصوص (قرار ٥٥).
-- الحزمة: syria-2027-v1 إصدار 1 (2027) — الصفوف المعتمدة: 0
-- يُطبَّق من SQL Editor — upsert آمن لإعادة التطبيق.
-- (لا أسئلة معتمدة بعد — تُعاد التوليد بعد اعتماد الأستاذ)
insert into public.content_questions (id, unit, chapter, chapter_index, correct_index, options_n) values
  (0, 'X', 'X0', 0, 0, 4)
on conflict (id) do update set
  unit = excluded.unit, chapter = excluded.chapter,
  chapter_index = excluded.chapter_index,
  correct_index = excluded.correct_index,
  options_n = excluded.options_n;
delete from public.content_questions where id = 0;
