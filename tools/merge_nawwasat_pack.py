# -*- coding: utf-8 -*-
"""APP-NAWWASAT-1 — دمج نوطة النواسات الكاملة في حزمة التطبيق (pack.json).

يدمج `tools/nawwasat-learning-units.json` (أو المسار المعطى سطر الأوامر) (33 وحدة — نص الأستاذ
كما هو + بطاقات + أمثلة + قوالب أسئلة) في `app/assets/content/pack.json`:

  1) حقل جديد `learningUnits` — طبقة التعلم الكاملة (docs/35 مرحلة C).
  2) `cards` ← بطاقات الوحدات (معرّفات 9100+، فصلها U1C1/U1C2/U1C3).
  3) `questions` ← أسئلة الوحدات (معرّفات 9200+، approved:false حتى
     اعتماد الأستاذ — قرار ٢٤: غير المعتمدة محجوبة).
  4) `experimentId` — الفلاشات الجديدة بمواقعها الدقيقة داخل الدروس:
       U1C1P5  ← spring   (النابض: حالة الحركة Fs = k·x)
       U1C2P6  ← torsion  (نواس الفتل: تمهيد + التجارب ١–٣)
       U1C3P2  ← gravity  (النواس الثقلي: غير التوافقية)
       U1C3P11 ← simple   (النواس البسيط: T ~ √l)

السكريبت قاهر (idempotent): يمرّات متعددة تعطي الناتج نفسه — يزيل أولاً
دخوله السابقة (نطاق المعرّفات) ثم يعيد الحق. لا يمسّ شيئاً خارج هذا.
"""
import json
import os
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
PACK = os.path.join(BASE, 'app', 'assets', 'content', 'pack.json')
# ملف الوحدات: الأولوية لمسار سطر الأوامر (argv[1]) ثم tools/ ثم content/generated/
_cand = [sys.argv[1]] if len(sys.argv) > 1 else []
_cand += [os.path.join(BASE, 'tools', 'nawwasat-learning-units.json'),
          os.path.join(BASE, 'content', 'generated', 'nawwasat-learning-units.json')]
UNITS = next((c for c in _cand if os.path.exists(c)), _cand[0])
if not os.path.exists(UNITS):
    sys.exit(f'ملف الوحدات غير موجود — جرّب: python tools\\merge_nawwasat_pack.py <مسار nawwasat-learning-units.json>')

CARD_ID_BASE = 9100     # 9100..9299 — بطاقات النواسات
Q_ID_BASE = 9300        # 9300..9999 — أسئلة النواسات
CARD_ID_MAX = 9299
Q_ID_MAX = 9999

# الفلاشات الجديدة بمواقعها الدقيقة (قرار المالك: فتل = U1-1..4، بسيط = U1-5)
PLACEMENTS = {
    ('U1C1', 'U1C1P5'): 'spring',    # حالة الحركة — قوة النابض Fs = k·(x+x₀)
    ('U1C2', 'U1C2P6'): 'torsion',   # «٤. ماذا يعتمد عليه الدور؟ (التجارب الثلاث)»
    ('U1C3', 'U1C3P2'): 'gravity',   # «لماذا النواس الثقلي غير توافقي؟»
    ('U1C3', 'U1C3P11'): 'simple',   # «٦. التعريف — النواس الثقلي البسيط»
}


def main():
    pack = json.load(open(PACK, encoding='utf-8'))
    units = json.load(open(UNITS, encoding='utf-8'))
    assert len(units) == 33, f'expected 33 units, got {len(units)}'

    # 1) learningUnits (استبدال كامل — مصدره ملف units نفسه)
    pack['learningUnits'] = units

    # 2) cards — إزالة دخولي السابق ثم حقن الجديد
    pack['cards'] = [c for c in pack['cards'] if not (CARD_ID_BASE <= c['id'] <= CARD_ID_MAX)]
    next_card = CARD_ID_BASE
    for u in units:
        for c in u['cards']:
            pack['cards'].append({
                'id': next_card,
                'unit': 'U1',
                'chapter': u['chapter'],
                'front': c['front'],
                'back': c['back'],
                'formula': c.get('formula'),
            })
            next_card += 1
            assert next_card <= CARD_ID_MAX, 'card id range exhausted'

    # 3) questions — المثال المحلول + القوالب (approved:false حتى الاعتماد)
    pack['questions'] = [q for q in pack['questions'] if not (Q_ID_BASE <= q['id'] <= Q_ID_MAX)]
    next_q = Q_ID_BASE

    def add_q(u, stem, options, correct, solution_steps):
        nonlocal next_q
        pack['questions'].append({
            'id': next_q,
            'unit': 'U1',
            'chapter': u['chapter'],
            'approved': False,  # قرار ٢٤: محجوبة حتى اعتماد الأستاذ
            'stem': stem,
            'options': options,
            'correctIndex': correct,
            'solutionSteps': solution_steps,
            'followThrough': [],
        })
        next_q += 1
        assert next_q <= Q_ID_MAX, 'question id range exhausted'

    for u in units:
        ex = u.get('example')
        if ex and ex.get('kind') == 'mcq':
            add_q(u, ex['stem'], ex['options'], ex['answer'],
                  [ex.get('solution', ex.get('solution_steps', ['—']))])
        for t in u.get('question_templates', []):
            if t.get('kind') != 'mcq':
                continue
            steps = []
            if t.get('solution'):
                steps.append(t['solution'])
            if t.get('note'):
                steps.append(f"النوط: {t['note']}")
            add_q(u, t['stem'], t['options'], t['answer'], steps or ['—'])

    # 4) experimentId — الفلاشات بمواقعها
    u1 = pack['units'][0]
    for (chap, para), exp_id in PLACEMENTS.items():
        ch = next(c for c in u1['chapters'] if c['id'] == chap)
        p = next(p for p in ch['paragraphs'] if p['id'] == para)
        p['experimentId'] = exp_id

    with open(PACK, 'w', encoding='utf-8') as f:
        json.dump(pack, f, ensure_ascii=False, indent=1)

    # تحقق
    pack2 = json.load(open(PACK, encoding='utf-8'))
    exp = [(c['id'], p['id'], p['experimentId'])
           for u in pack2['units'] for c in u['chapters']
           for p in c['paragraphs'] if p.get('experimentId')]
    print(f"learningUnits: {len(pack2['learningUnits'])}")
    print(f"cards: {len(pack2['cards'])} (النواسات: {sum(1 for c in pack2['cards'] if CARD_ID_BASE <= c['id'] <= CARD_ID_MAX)})")
    print(f"questions: {len(pack2['questions'])} (النواسات: {sum(1 for q in pack2['questions'] if Q_ID_BASE <= q['id'] <= Q_ID_MAX)})")
    print("placements:", sorted(exp))


if __name__ == '__main__':
    sys.exit(main())
