#!/usr/bin/env python3
"""يولّد صفحة «مراجعة فقرة-فقرة» لنوطة النواسات من مخرجات NHTML-1.

القراءة من:  content/text.json · content/equations.json · content/images.json
             assets/images/* (تضمين base64)
الإخراج إلى: review/index.html (ملف واحد مستقل — يعمل بلا إنترنت)

الهدف (قرار المالك 2026-10-01): كل فقرة تُعرض للمالك ← موافقة الأستاذ ← اعتماد.
القرارات تُصدَّر JSON يُسلَّم للخط الأنبوبي (مرحلة A) ليُعلَّم approved:true.
"""
import base64
import json
import os
import re
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # rebuild/nawwasat
OUT = os.path.join(BASE, 'review', 'index.html')
TPL = os.path.join(BASE, 'review', 'template.html')

# حدود الأقسام — مقيسة من النصوص (عناوين الأقسام في المتن، بلا Heading Styles):
# [710] نواس الفتل غير متخامد · [1115] أولاّ: النواس الثقلي المركب · [1205] ثانياً: النواس الثقلي البسيط
SECTIONS = [
    (0, 'النواس المرن (غير المتخامد)'),
    (710, 'نواس الفتل (غير متخامد)'),
    (1115, 'النواس الثقلي المركب'),
    (1205, 'النواس الثقلي البسيط + المواقت'),
]
SRC_SHA = '39dcae28ec74ad26520823b6057faeeefe9981ddd3c86a9f78244c27afd35d50'
SRC_NAME = 'notes/النواسات م_101932-r23-all-absolute-value-bars-green.docx'

ANN = re.compile(r'«[^»]*»')  # سطور الجرد «معادلات:…»/«رسوم:…»/«مربع نصي …» — تُعرض كشارات لا نصاً


def sec_index(i: int) -> int:
    idx = 0
    for n, (start, _name) in enumerate(SECTIONS):
        if i >= start:
            idx = n
    return idx


def main() -> None:
    txt = json.load(open(os.path.join(BASE, 'content', 'text.json'), encoding='utf-8'))
    blocks = txt if isinstance(txt, list) else txt.get('blocks', txt.get('content', []))
    eqs = json.load(open(os.path.join(BASE, 'content', 'equations.json'), encoding='utf-8'))
    eq_items = eqs if isinstance(eqs, list) else eqs.get('equations', eqs.get('items', []))
    imgs = json.load(open(os.path.join(BASE, 'content', 'images.json'), encoding='utf-8'))
    img_items = imgs if isinstance(imgs, list) else imgs.get('images', [])

    fig2file = {}
    for im in img_items:
        for f in im.get('figures') or []:
            fig2file[f] = im.get('file')

    out_blocks = []
    n_empty = 0
    n_imgs = 0
    n_vec = 0
    for b in blocks:
        i = int(b['i'])
        raw = b.get('text') or ''
        clean = ANN.sub('', raw).strip()
        twocol = bool(re.search(r'( {6,}|\t{2,})', raw)) and len(clean) > 24
        figs = b.get('figs') or []
        imgs_b64 = []
        for f in figs:
            fn = fig2file.get(f)
            if fn and os.path.exists(os.path.join(BASE, fn)):
                p = os.path.join(BASE, fn)
                data = base64.b64encode(open(p, 'rb').read()).decode()
                fmt = 'png' if p.lower().endswith('.png') else 'jpeg'
                imgs_b64.append({'f': f, 'u': f'data:image/{fmt};base64,{data}'})
                n_imgs += 1
            else:
                imgs_b64.append({'f': f, 'u': None})  # شكل متجهي (أسهم/محاور) — بلا raster
                n_vec += 1
        is_empty = (not clean) and not figs and not (b.get('eqs') or [])
        if is_empty:
            n_empty += 1
        out_blocks.append({
            'i': i,
            'sec': sec_index(i),
            'tb': bool(b.get('in_textbox_of')),
            'tbl': bool(b.get('in_table')),
            'two': twocol,
            't': clean,
            'neq': len(b.get('eqs') or []),
            'figs': figs,
            'imgs': imgs_b64,
            'e': is_empty,
        })

    data = {
        'source': SRC_NAME,
        'source_sha256': SRC_SHA,
        'sections': [name for _s, name in SECTIONS],
        'blocks': out_blocks,
    }
    payload = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')

    tpl = open(TPL, encoding='utf-8').read()
    if '__DATA__' not in tpl:
        sys.exit('template.html بلا علامة __DATA__')
    open(OUT, 'w', encoding='utf-8').write(tpl.replace('__DATA__', payload))

    # ملخص
    per_sec = [0, 0, 0, 0]
    for b in out_blocks:
        per_sec[b['sec']] += 1
    print(f'blocks: {len(out_blocks)} (فارغة {n_empty})')
    for n, (s, name) in enumerate(SECTIONS):
        print(f'  قسم {n}: {name} — {per_sec[n]} فقرة (من block {s})')
    print(f'صور مضمّنة: {n_imgs} · أشكال متجهية (شارة بلا صورة): {n_vec}')
    print(f'المخرجات: {OUT} — {os.path.getsize(OUT) // 1024} KB')


if __name__ == '__main__':
    main()
