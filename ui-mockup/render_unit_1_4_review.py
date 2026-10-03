# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.4: التابع الزمني للمطال (الشكل العام)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
H = 1780
cv = ReviewCanvas(W, H)
d = cv.d
img = cv.img
XR = 2400

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.4 — ", "ar"), ("تابع المطال: الشكل العام", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("وحدة خفيفة: شرح + 3 بطاقات + 3 أسئلة", TXT2, LINE, CARD),
    ("بلا فلاشات — لا أشكال ضمن البلوكات 149–163", TXT2, LINE, CARD),
]:
    tw = text_width(txt, NASKH, 22, True)
    w = tw + 48
    cv.alpha_rect(pr - w, 214, w, 54, bg, radius=27)
    d.rounded_rectangle([pr - w, 214, pr - 1, 267], radius=27, outline=_c4(bc), width=2)
    draw_rtl(img, pr - 24, 214 + 39, txt, 22, tc, bold=True)
    pr -= w + 20

# ============================ الصف الأول ============================
SY, PW, PH = 330, 760, 1350
X1, X2, X3 = XR - PW, XR - 2 * PW - 30, XR - 3 * PW - 60
SUB = "الوحدة 1.4 · النواس المرن"

# ---------- S1: الشرح (الشكل العام + الجدول) ----------
pl, pr = cv.phone(X1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "التوابع الزمنية", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٤", 19, TXT2, LINE, CARD2)
yy = SY + 190
draw_rtl(img, cr, yy, "التابع الزمني للمطال بالشكل العام:", 19, TXT); yy += 44
big = "x = Xmax·cos(ω₀t + φ)"
bw = text_width(big, DEJAVU_SI, 32) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 46, big, 32, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 104
# جدول ثوابت/متغيرات
colw = 350
cv.a_rounded(pl + 16, yy, pr - 16, yy + 288, 14, fill=CARD2, outline=LINE)
cv.draw_flow(cr, yy + 40, [("ثوابت الحركة", "ar")], 18, BRAND, bold=True)
cv.draw_flow(cr - colw, yy + 40, [("متغيرات الحركة", "ar")], 18, BRAND, bold=True)
d.line([(pl + 28, yy + 56), (pr - 28, yy + 56)], fill=_c4(LINE), width=2)
const_rows = [
    [("Xmax (m) — ", "la"), ("سعة الاهتزاز", "ar")],
    [("ω₀ (rad/s) — ", "la"), ("النبض الخاص", "ar")],
    [("φ (rad) — ", "la"), ("الطور الابتدائي", "ar")],
]
var_rows = [
    [("x (m) — ", "la"), ("المطال الخطي", "ar")],
    [("t (s) — ", "la"), ("الزمن", "ar")],
]
for i, segs in enumerate(const_rows):
    cv.draw_flow(cr - 12, yy + 92 + i * 60, segs, 18, TXT2)
for i, segs in enumerate(var_rows):
    cv.draw_flow(cr - colw - 12, yy + 92 + i * 60, segs, 18, TXT2)
d.line([(pl + 16, yy + 142), (pr - 16, yy + 142)], fill=_c4(LINE), width=1)
yy += 328
cv.draw_flow(cr, yy, [("φ (الطور الابتدائي): ", "la"), ("تُحسب من شروط البدء — نعوض شروط البدء في التابع", "ar")], 18, TXT); yy += 52
cv.a_rounded(pl + 16, yy, pr - 16, yy + 128, 14, fill=(45, 212, 167, 16), outline=(45, 212, 167, 100))
cv.draw_flow(cr - 12, yy + 40, [("عند انطلاق الجسم من المطال الأعظمي الموجب: ", "ar")], 18, BRAND)
cv.draw_flow(cr - 12, yy + 88, [("φ = 0 rad ", "la"), ("⟹ ", "la"), ("الشكل المختزل: ", "ar"), ("x = Xmax·cos(ω₀t)", "la")], 18, BRAND, bold=True)
cv.bottom_bar(X1, SY + PH - 108, PW)

# ---------- S2: البطاقات (3) ----------
pl, pr = cv.phone(X2, SY, PW, PH, "بطاقات المراجعة", SUB)
cards = [
    ([("الشكل العام لتابع المطال", "ar")], 300, [
        [("x = Xmax·cos(ω₀t + φ)", "la")],
        [("يسري على أي نواس مرن بغض النظر عن شروط البدء.", "ar")],
    ]),
    ([("ثوابت الحركة", "ar")], 300, [
        [("Xmax (m) · ω₀ (rad/s) · φ (rad)", "la")],
        [("ثابتة طوال الحركة — لا تتغير مع الزمن.", "ar")],
    ]),
    ([("الطور الابتدائي ", "ar"), ("φ", "la")], 300, [
        [("تُحسب من شروط البدء —", "ar")],
        [("نعوض شروط البدء في التابع.", "ar")],
    ]),
]
by = SY + 100
for i, (front, ch, lines) in enumerate(cards):
    cv.card(pl, by, pr - pl, ch, 22, CARD, border=LINE)
    cv.number_badge(pl + 20, by + 20, i + 1, BRAND)
    cv.draw_flow(pr - 24, by + 50, front, 24, TXT, bold=True)
    d.line([(pl + 24, by + 78), (pr - 24, by + 78)], fill=_c4(LINE), width=2)
    yy = by + 130
    for segs in lines:
        cv.draw_flow(pr - 24, yy, segs, 20, TXT2)
        yy += 40
    by += ch + 24
draw_rtl(img, pr, SY + PH - 90, "3 بطاقات — المصطلح + التعريف", 18, TXT2, path=SANS)

# ---------- S3: الاختبار الذاتي (3) ----------
pl, pr = cv.phone(X3, SY, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("في الشكل العام ", "ar"), ("x = Xmax·cos(ω₀t + φ)", "la"), (" —", "ar")],
       [("الطور الابتدائي φ هو:", "ar")] ],
     [[("يحسب من شروط البدء", "ar")], [("ثابت صفراً دوماً", "ar")],
      [("متغير يتغير مع الزمن", "ar")], [("ثابت π/2 دوماً", "ar")]]),
    ([ [("أي مما يلي متغير من متغيرات", "ar")],
       [("الحركة (وليس ثابتاً)؟", "ar")] ],
     [[("المطال الخطي ", "ar"), ("x", "la")], [("سعة الاهتزاز ", "ar"), ("Xmax", "la")],
      [("النبض الخاص ", "ar"), ("ω₀", "la")], [("الطور الابتدائي ", "ar"), ("φ", "la")]]),
    ([ [("إذا بدأ الجسم من المطال الأعظمي الموجب", "ar")],
       [("(", "la"), ("t = 0، x = +Xmax", "la"), (") فإن:", "ar")] ],
     [[("φ = 0 والتابع ", "la"), ("x = Xmax·cos(ω₀t)", "la")], [("φ = π", "la")],
      [("φ = π/2", "la")], [("ω₀ = 0", "la")]]),
]
by = SY + 96
letters = ["أ", "ب", "ج", "د"]
for qi, (stem_lines, opts) in enumerate(qs):
    qh = 276
    cv.card(pl, by, pr - pl, qh, 22, CARD, border=LINE)
    cv.number_badge(pl + 20, by + 20, qi + 1, BRAND2)
    yy = by + 44
    for line in stem_lines:
        cv.draw_flow(pr - 24, yy, line, 19, TXT)
        yy += 30
    yy += 4
    for oi, segs in enumerate(opts[:4]):
        row_h = 40
        correct = (oi == 0)
        cv.a_rounded(pl + 24, yy, pr - 24, yy + row_h - 6, 11,
                     fill=(45, 212, 167, 30) if correct else (28, 43, 71, 120),
                     outline=(45, 212, 167, 140) if correct else None)
        d.ellipse([pl + 36, yy + 5, pl + 64, yy + 33], fill=CARD2, outline=_c4(LINE), width=2)
        lw_ = text_width(letters[oi], NASKH, 16, True)
        draw_rtl(img, pl + 50 + lw_ // 2, yy + 28, letters[oi], 16, TXT2, bold=True)
        opt_color = BRAND if correct else TXT2
        if correct:
            cv.check(pr - 48, yy + 19, 10, BRAND, wdt=4)
        cv.draw_flow(pr - 72, yy + 28, segs, 17, opt_color, bold=correct)
        yy += row_h + 4
    by += qh + 14
cv.a_rounded(pr - 230, SY + PH - 104, pr - 24, SY + PH - 56, 24,
             fill=(45, 212, 167, 26), outline=(45, 212, 167, 120))
cv.refresh(pr - 130, SY + PH - 80, 14, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY + PH - 68, "سؤال جديد", 20, BRAND, bold=True)

# ============================ التسميات ============================
row1 = [
    ([("الشرح — الشكل العام + الثوابت/المتغيرات", "ar")], X1),
    ([("بطاقات المراجعة (3)", "ar")], X2),
    ([("الاختبار الذاتي (3 قوالب)", "ar")], X3),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.4 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.4-review.png")
