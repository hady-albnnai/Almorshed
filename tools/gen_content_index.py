#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════
# gen_content_index.py — توليد docs/supabase/content_index.sql (F5.1)
# المصدر: app/assets/content/pack.json — بنك «المعتمد حصراً» (قرار ٢٤).
# الناتج معرفات وبنى فقط — لا نصوص كتاب (قرار ٥٥).
# فهرس الفصول بترتيب وحدات الحزمة نفسه (مطابق batch_builder.dart حرفياً).
# الاستخدام: python3 tools/gen_content_index.py
# ═══════════════════════════════════════════════════════════════════════
import json
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, 'app', 'assets', 'content', 'pack.json')
OUT = os.path.join(ROOT, 'docs', 'supabase', 'content_index.sql')

pack = json.load(open(PACK, encoding='utf-8'))
qs = [q for q in pack['questions'] if q.get('approved', False)]

# فهرس الفصول بترتيب الحزمة (وحدات ثم فصولها) — كما batch_builder بالضبط
chapter_index = {}
for u in pack['units']:
    for c in u['chapters']:
        chapter_index.setdefault(c['id'], len(chapter_index))

rows = []
for q in qs:
    rows.append((q['id'], q['unit'], q['chapter'],
                 chapter_index.get(q['chapter'], 0),
                 q['correctIndex'], len(q['options'])))

with io.open(OUT, 'w', encoding='utf-8') as f:
    f.write('-- ═══ مولَّد آلياً بـ tools/gen_content_index.py — لا تحرير يدوي ═══\n')
    f.write('-- بنك المبارزات: المعتمد حصراً (قرار ٢٤) — معرفات بلا نصوص (قرار ٥٥).\n')
    f.write('-- الحزمة: %s إصدار %d (%d) — الصفوف المعتمدة: %d\n' %
            (pack['packId'], pack['edition'], pack['year'], len(rows)))
    f.write('-- يُطبَّق من SQL Editor — upsert آمن لإعادة التطبيق.\n')
    if not rows:
        f.write('-- (لا أسئلة معتمدة بعد — تُعاد التوليد بعد اعتماد الأستاذ)\n')
    f.write('insert into public.content_questions (id, unit, chapter, chapter_index, correct_index, options_n) values\n')
    vals = ['(%d, %s, %s, %d, %d, %d)' %
            (r[0], "'%s'" % r[1], "'%s'" % r[2], r[3], r[4], r[5]) for r in rows]
    f.write(',\n'.join(vals) if vals else '  (0, \'X\', \'X0\', 0, 0, 4)')
    f.write('\non conflict (id) do update set\n'
            '  unit = excluded.unit, chapter = excluded.chapter,\n'
            '  chapter_index = excluded.chapter_index,\n'
            '  correct_index = excluded.correct_index,\n'
            '  options_n = excluded.options_n;\n')
    if not rows:
        f.write('delete from public.content_questions where id = 0;\n')

print('content_index.sql: %d صف معتمد' % len(rows))
