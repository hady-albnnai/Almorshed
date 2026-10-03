# -*- coding: utf-8 -*-
"""APP-NAWWASAT-1 — يولّد content/generated/nawwasat-learning-units.json
من مخرجات تأليف النوط (rebuild/nawwasat/units/unit-*.json) بصيغة موحّدة
متوافق مع docs/35 (قرارات ٧٤–٧٨): الوحدة = شرح (نص الأستاذ كما هو) +
بطاقات + تجربة (إن وُجدت) + مثال + قوالب أسئلة، بحالة approved_by_teacher.
"""
import glob
import json
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
UNITS_DIR = os.path.join(BASE, 'rebuild', 'nawwasat', 'units')
OUT = os.path.join(BASE, 'content', 'generated', 'nawwasat-learning-units.json')

# خريطة وحداتنا ← فصول حزمة التطبيق (نفس النوط بثلاثة فصول):
# U1-xx النواس المرن = U1C1 · U2-xx نواس الفتل = U1C2 · U3-xx النواس الثقلي = U1C3
CHAPTER = {'U1': 'U1C1', 'U2': 'U1C2', 'U3': 'U1C3'}


def main():
    out = []
    for path in sorted(glob.glob(os.path.join(UNITS_DIR, 'unit-*.json'))):
        u = json.load(open(path, encoding='utf-8'))
        uid = u['unit_id']                     # U1-01 …
        prefix = uid.split('-')[0]             # U1/U2/U3
        ex = u.get('explanation', {})
        if isinstance(ex, dict) and 'parts' in ex:
            note = ex['parts']                 # نص الأستاذ كما هو (R1–R14 فقط)
        elif isinstance(ex, dict) and 'text' in ex:
            note = [ex['text']]
        else:
            note = []
        out.append({
            'unit_id': uid,
            'map_ref': u.get('map_ref', ''),
            'chapter': CHAPTER[prefix],
            'section': u.get('section', ''),
            'title': u['title'],
            'source_blocks': u.get('source_blocks', []),
            'note': note,
            'cards': u.get('cards', []),
            'experiment': u.get('experiment'),
            'example': u.get('example'),
            'question_templates': u.get('question_templates', []),
            'figures': u.get('figures', []),
            'next_unit_hint': u.get('next_unit_hint', ''),
            'review_image': f"ui-mockup/unit-{u.get('map_ref', '?')}-review-1400.png",
            'approved_by_teacher': False,
            'status': u.get('status', 'draft'),
        })
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    n_cards = sum(len(x['cards']) for x in out)
    n_qs = sum((1 if x['example'] else 0) + len(x['question_templates']) for x in out)
    print(f"wrote {OUT} | units: {len(out)} | cards: {n_cards} | questions: {n_qs}")


if __name__ == '__main__':
    main()
