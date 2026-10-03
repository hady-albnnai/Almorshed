# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.5: الشكل المختزل + س4 (المنحنى + القيم)"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
H = 3320
cv = ReviewCanvas(W, H)
d = cv.d
img = cv.img
XR = 2400

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.5 — ", "ar"), ("الشكل المختزل + س4", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("الجدول F0040–F0042 من النوط — المنحنى مرسوم", TXT2, LINE, CARD),
    ("شرح + 3 بطاقات + مثال محلول + 4 أسئلة", TXT2, LINE, CARD),
]:
    tw = text_width(txt, NASKH, 22, True)
    w = tw + 48
    cv.alpha_rect(pr - w, 214, w, 54, bg, radius=27)
    d.rounded_rectangle([pr - w, 214, pr - 1, 267], radius=27, outline=_c4(bc), width=2)
    draw_rtl(img, pr - 24, 214 + 39, txt, 22, tc, bold=True)
    pr -= w + 20

# ============================ الصف الأول ============================
SY, PW, PH = 330, 760, 1350
XR1 = XR - PW
XL1 = XR - 2 * PW - 30
SY2 = 1860
SUB = "الوحدة 1.5 · النواس المرن"

# ---------- S1: الشرح (الاستنتاج + أعظمى/معدوم) ----------
pl, pr = cv.phone(XR1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "الشكل المختزل", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٥", 19, TXT2, LINE, CARD2)
yy = SY + 180
cv.draw_flow(cr, yy, [("س4) انطلاقا من تابع المطال بالشكل العام — ", "ar")], 18, TXT)
cv.draw_flow(cr, yy + 30, [("بفرض مبدأ الزمن عندما كان الجسم في المطال الأعظمي الموجب:", "ar")], 18, BRAND, bold=True)
yy += 80
steps = [
    [("نعوض ", "ar"), ("t = 0:   Xmax = Xmax·cosφ", "la")],
    [("إذن:  ", "ar"), ("cosφ = 1  ⟹  φ = 0 rad", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 52
big = "x = Xmax·cos(ω₀t)"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy + 6, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy + 6, pxc + bw // 2 - 1, yy + 71], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 48, big, 30, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 90
draw_rtl(img, cr, yy, "الشكل المختزل — ينطبق عندما ينطلق الجسم من المطال الأعظمي الموجب", 18, TXT2)
yy += 56
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 44
cv.number_badge(cr - 36, yy - 26, "a", BRAND2)
cv.draw_flow(cr - 52, yy, [("أعظمى: ", "ar"), ("في الوضعين الجانبيين ", "ar"), ("x = ±Xmax", "la")], 18, TXT); yy += 48
cv.number_badge(cr - 36, yy - 26, "b", BRAND2)
cv.draw_flow(cr - 52, yy, [("معدومة: ", "ar"), ("في مركز الاهتزاز ", "ar"), ("x = 0", "la")], 18, TXT); yy += 60
cv.a_rounded(pl + 16, yy, pr - 16, yy + 84, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 34, [("خلال كل دور: المطال يصفر مرتين ", "ar"), ("3T₀/4)", "la"), ("،", "ar"), ("(t = T₀/4", "la")], 17, TXT2)
cv.draw_flow(cr - 12, yy + 62, [("ويعبر أقصى القيمة مرتين ", "ar"), ("T₀/2)", "la"), ("،", "ar"), ("(t = 0", "la")], 17, TXT2)

# ---------- S2: المنحنى x–t + المعادلة ----------
pl, pr = cv.phone(XL1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "الخط البياني خلال دور واحد", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
# منطقة الرسم
gx0, gx1 = pl + 90, pr - 60
gy_mid = SY + 400
amp = 150
d.line([(gx0 - 20, gy_mid), (gx1 + 30, gy_mid)], fill=_c4(TXT2), width=3)
d.polygon([(gx1 + 44, gy_mid), (gx1 + 26, gy_mid - 9), (gx1 + 26, gy_mid + 9)], fill=_c4(TXT2))
d.line([(gx0 - 20, gy_mid + amp + 40), (gx0 - 20, gy_mid - amp - 40)], fill=_c4(TXT2), width=3)
d.polygon([(gx0 - 20, gy_mid - amp - 52), (gx0 - 29, gy_mid - amp - 34), (gx0 - 11, gy_mid - amp - 34)], fill=_c4(TXT2))
# الشبكة العمودية + التسميات
marks = [(0.0, "0"), (0.25, "T₀/4"), (0.5, "T₀/2"), (0.75, "3T₀/4"), (1.0, "T₀")]
for frac, lab in marks:
    xx = gx0 + int((gx1 - gx0) * frac)
    d.line([(xx, gy_mid - amp - 20), (xx, gy_mid + amp + 20)], fill=_c4(LINE), width=2)
    lw_ = text_width(lab, DEJAVU, 20)
    draw_ltr(img, xx - lw_ // 2, gy_mid + amp + 52, lab, 20, TXT2, path=DEJAVU)
# تسميات المحور الرأسي
for yyv, lab in [(gy_mid - amp, "Xmax"), (gy_mid, "0"), (gy_mid + amp, "-Xmax")]:
    draw_ltr(img, gx0 - 90, yyv - 12, lab, 20, TXT2, path=DEJAVU)
    d.line([(gx0 - 20, yyv), (gx0, yyv)], fill=_c4(TXT2), width=2)
# المنحنى: x = Xmax·cos(2π t/T0)
pts = []
N = 240
for i in range(N + 1):
    t = i / N
    xx = gx0 + (gx1 - gx0) * t
    yy_ = gy_mid - amp * math.cos(2 * math.pi * t)
    pts.append((xx, yy_))
d.line(pts, fill=_c4(BRAND2), width=6, joint="curve")
# نقاط رئيسية
for frac, val in [(0.0, -1), (0.25, 0), (0.5, 1), (0.75, 0), (1.0, -1)]:
    xx = gx0 + int((gx1 - gx0) * frac)
    yy_ = gy_mid + amp * val
    d.ellipse([xx - 9, yy_ - 9, xx + 9, yy_ + 9], fill=_c4(GOLD), outline=_c4(BG2), width=3)
yy = SY + 700
cv.a_rounded(pl + 16, yy, pr - 16, yy + 120, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 36, [("من الجدول: ", "ar"), ("cos(0)=1 · cos(π/2)=0 · cos(π)=−1 · cos(3π/2)=0 · cos(2π)=1", "la")], 16, TXT2)
cv.draw_flow(cr - 12, yy + 78, [
    ("إذن: عند ", "ar"), ("t = 0", "la"), (" المطال ", "ar"), ("Xmax", "la"),
    (" · عند ", "ar"), ("T₀/4", "la"), (" صفر · عند ", "ar"), ("T₀/2", "la"),
    (" سالب ", "ar"), ("Xmax", "la"), (" · عند ", "ar"), ("3T₀/4", "la"),
    (" صفر · عند ", "ar"), ("T₀", "la"), (" يعود ", "ar"), ("Xmax", "la"),
], 17, TXT)
yy += 160
big2 = "x = Xmax·cos( (2π/T₀)·t )"
bw2 = text_width(big2, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw2 // 2, yy, bw2, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw2 // 2, yy, pxc + bw2 // 2 - 1, yy + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw2 // 2 + 32, yy + 46, big2, 30, MATHC, path=DEJAVU_SI, slant=0.22)

# ============================ الصف الثاني ============================
# ---------- S3: المثال المحلول ----------
pl, pr = cv.phone(XR1, SY2, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "من نوط الأستاذ", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.a_rounded(pl + 16, yy, pr - 16, yy + 130, 14, fill=CARD2, outline=LINE)
cv.draw_flow(cr, yy + 40, [("للتابع: ", "ar"), ("x = Xmax·cos( (2π/T₀)·t )", "la")], 19, TXT)
cv.draw_flow(cr, yy + 88, [("أوجد قيمة المطال عند ", "ar"), ("t = T₀/2", "la"), (" وعند ", "ar"), ("t = 5T₀/4", "la")], 19, TXT)
yy += 180
steps = [
    [("نعوض ", "ar"), ("t = T₀/2:  ", "la"), ("x = Xmax·cos(π)", "la")],
    [("cos(π) = −1:  ", "la"), ("x = −Xmax", "la")],
    [("نعوض ", "ar"), ("t = 5T₀/4:  ", "la"), ("x = Xmax·cos(5π/2)", "la")],
    [("5π/2 = 2π + π/2:  ", "la"), ("cos(5π/2) = 0 ⟹ x = 0", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 52
yy += 14
ans = "x(T₀/2) = −Xmax   ·   x(5T₀/4) = 0"
bw3 = text_width(ans, DEJAVU_SI, 28) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw3 // 2, yy, bw3, 66, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw3 // 2, yy, pxc + bw3 // 2 - 1, yy + 65], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw3 // 2 + 32, yy + 46, ans, 28, BRAND, path=DEJAVU_SI, slant=0.22)

# ---------- S4: الاختبار الذاتي (4) ----------
pl, pr = cv.phone(XL1, SY2, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("ينطلق الجسم من المطال الأعظمي الموجب —", "ar")],
       [("الطور الابتدائي ", "ar"), ("φ:", "la")] ],
     [[("0 rad", "la"), ("والتابع ", "ar"), ("x = Xmax·cos(ω₀t)", "la")], [("π rad", "la")],
      [("π/2 rad", "la")], [("3π/2 rad", "la")]]),
    ([ [("خلال دور واحد — متى ينعدم", "ar")],
       [("المطال؟", "ar")] ],
     [[("عند ", "ar"), ("t = T₀/4", "la"), ("و ", "ar"), ("t = 3T₀/4", "la"), (" (في المركز)", "ar")],
      [("عند ", "ar"), ("t = 0", "la"), ("و ", "ar"), ("t = T₀", "la")], [("عند ", "ar"), ("t = T₀/2", "la"), (" فقط", "ar")],
      [("لا ينعدم أبداً", "ar")]]),
    ([ [("نواس سعة اهتزازه ", "ar"), ("Xmax = 10 cm", "la"), (" —", "ar")],
       [("المطال عند ", "ar"), ("t = T₀/2", "la"), ("؟", "ar")] ],
     [[("−10 cm", "la")], [("10 cm", "la")], [("0", "la")], [("5 cm", "la")]]),
    ([ [("لتابع المطال ", "ar"), ("x = Xmax·cos(ω₀t)", "la"), (" —", "ar")],
       [("قيمة المطال عند ", "ar"), ("t = 5T₀/4", "la"), (":", "la")] ],
     [[("x = 0", "la")], [("x = Xmax", "la")], [("x = −Xmax", "la")], [("x = Xmax/2", "la")]]),
]
by = SY2 + 96
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
cv.a_rounded(pr - 230, SY2 + PH - 104, pr - 24, SY2 + PH - 56, 24,
             fill=(45, 212, 167, 26), outline=(45, 212, 167, 120))
cv.refresh(pr - 130, SY2 + PH - 80, 14, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY2 + PH - 68, "سؤال جديد", 20, BRAND, bold=True)

# ============================ التسميات ============================
row1 = [
    ([("الشرح — الاستنتاج + أعظمى/معدوم", "ar")], XR1),
    ([("المنحنى ", "ar"), ("x–t", "la"), (" خلال دور واحد", "ar")], XL1),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([("المثال المحلول (س4 — القيم)", "ar")], XR1),
    ([("الاختبار الذاتي (4 قوالب)", "ar")], XL1),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY2 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.5 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.5-review.png")
