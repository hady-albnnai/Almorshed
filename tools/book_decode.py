#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
فكّ ترميز نسخة الكتاب الرسمي الخاصة بصاحب المشروع (sources/book-2026-2027.pdf على main).
⚠️ خرائط ToUnicode لهذه النسخة **مختلفة** عن نسخة أرشيف الإنترنت (جدولها في docs/08).
المرجع الكامل: docs/10-CONFIRM-TEACHER-ITEMS.md §٨

الاستعمال:
    from book_decode import open_book, page_chars, decode_symbol
    doc = open_book('/path/to/book-2026-2027.pdf')
    chars = page_chars(doc, 21)          # [(char, font, size, x, y), ...]
    decode_symbol('C', 'MMCenturyOldGreek')  -> 'Γ'
"""
import pymupdf

# خريطة الترميز المستخرجة تجريبياً بالحبر (docs/10 §٨)
DECODE = {
    ('C', 'MMCenturyOldGreek'): 'Γ',
    ('U', 'MMCenturyOldGreek'): 'Φ',
    ('U', 'MMCenturyOldGreekBold'): 'Φ',
    ('f', 'MMCenturyOldGreekItalic'): 'ε',
    ('f', 'MMCenturyOldGreekBoldItalic'): 'ε',
    ('n', 'MMCenturyOldGreek'): 'μ',
    ('n', 'MMCenturyOldGreekItalic'): 'μ',
    ('r', 'MMCenturyOldGreek'): 'π',
    ('T', 'MMExtra'): 'Δ',          # كتابع فقط (حجم ≤ 9)
    ('h', 'MMCenturyOldGreekItalic'): 'η',
    ('i', 'MMCenturyOldGreekItalic'): 'θ',
    ('~', 'MMCenturyOldGreekItalic'): 'ω',
    ('{', 'MMCenturyOldGreekItalic'): 'φ',
    ('a', 'MMCenturyOldGreekItalic'): 'α',
    ('#', 'MMBinary'): '×',
}

def open_book(path):
    return pymupdf.open(path)

def _short(font):
    return font.split('+')[-1]

def decode_symbol(char, font, size=12.0):
    if char == 'T' and _short(font) == 'MMExtra' and size <= 9:
        return 'Δ'
    return DECODE.get((char, _short(font)))

def page_chars(doc, idx):
    """كل محارف الصفحة: (char, font_الكامل, size, x, y)"""
    out = []
    for b in doc[idx].get_text('rawdict')['blocks']:
        if b['type'] != 0:
            continue
        for l in b['lines']:
            for s in l['spans']:
                for c in s['chars']:
                    out.append((c['c'], s['font'], round(s['size'], 1),
                                round(c['bbox'][0], 1), round(c['bbox'][1], 1)))
    return out

def subscripts_of(doc, idx, base_char, base_min=11.5, sub_max=9.5):
    """كل (القاعدة، التابع، الموضع) لقاعدة معينة في الصفحة — كاشف التوابع المعتمد."""
    chs = page_chars(doc, idx)
    subs = [t for t in chs if t[2] <= sub_max]
    res = []
    for c, f, sz, x, y in chs:
        if c == base_char and sz >= base_min:
            near = sorted([t for t in subs if 0 <= t[3]-x <= 24 and -2 <= t[4]-y <= 9],
                          key=lambda t: t[3])
            run, px = '', x
            for t in near:
                if 0 <= t[3]-px <= 8:
                    run += t[0]
                    px = t[3]
            if run:
                res.append((run, x, y))
    return res
