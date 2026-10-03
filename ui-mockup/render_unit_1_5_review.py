# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.5: الشكل المختزل + المطال أعظمي/معدوم + س4"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
H = 3390
cv = ReviewCanvas(W, H)
d = cv.d
img = cv.img
XR = 2400

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.5 — ", "ar"), ("الشكل المختزل + المطال أعظمي/معدوم", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("فلاشات النوط: F0039–F0047 (جدول θ/cos + الخط البياني)", TXT2, LINE, CARD),
    ("شرح ② + 3 بطاقات + 4 أسئلة", TXT2, LINE, CARD),
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
SY2 = 1860
SUB = "الوحدة 1.5 · النواس المرن"

# ---------- S1: الشرح ① (استنتاج الشكل المختزل) ----------
pl, pr = cv.phone(X1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "تابع المطال", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٥", 19, TXT2, LINE, CARD2)
yy = SY + 190
draw_rtl(img, cr, yy, "س4) انطلاقا من تابع المطال بالشكل العام:", 19, TXT); yy += 34
draw_rtl(img, cr, yy, "استنتج تابع المطال بالشكل المختزل", 19, BRAND, bold=True); yy += 50
steps = [
    [("الشكل العام:  ", "ar"), ("x = Xmax·cos(ω₀t + φ)", "la")],
    [("بفرض ", "ar"), ("t = 0", "la"), (" عند المطال الأعظمي الموجب:  ", "ar"), ("x = +Xmax", "la")],
    [("نعوّض:  ", "ar"), ("Xmax = Xmax·cosφ  ⟹  cosφ = 1", "la")],
    [("إذن:  ", "ar"), ("φ = 0 rad", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 52
yy += 10
big = "x = Xmax·cos(ω₀t)"
bw = text_width(big, DEJAVU_SI, 34) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 70, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 69], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 50, big, 34, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 96
cv.draw_flow(cr, yy, [("الشكل المختزل — ", "ar"), ("(يبدأ الجسم من الوضع الجانبي الموجب)", "ar")], 18, TXT2)
cv.bottom_bar(X1, SY + PH - 108, PW)

# ---------- S2: الشرح ② (أعظمي/معدوم + الخط البياني) ----------
pl, pr = cv.phone(X2, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "أعظمي / معدوم + الخط البياني", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY + 172
cv.draw_flow(cr, yy, [("المطال أعظمي: ", "ar"), ("في الوضعين الجانبيين  ", "ar"), ("x = ±Xmax", "la")], 19, TXT); yy += 38
cv.draw_flow(cr, yy, [("المطال معدوم: ", "ar"), ("في مركز الاهتزاز  ", "ar"), ("x = 0", "la")], 19, TXT); yy += 56
# الإطار
gx0, gx1 = pl + 70, pr - 40
gy0, gy1 = yy, yy + 380
cv.a_rounded(gx0, gy0, gx1, gy1, 14, fill=(8, 14, 26), outline=(44, 63, 99))
# المحاور
cx_axis = gx0 + 60
cy_mid = (gy0 + gy1) // 2
amp = 130
d.line([(cx_axis, gy0 + 24), (cx_axis, gy1 - 24)], fill=_c4(TXT2), width=3)          # محور x
d.line([(cx_axis - 20, cy_mid), (gx1 - 24, cy_mid)], fill=_c4(TXT2), width=3)      # محور t
d.polygon([(cx_axis, gy0 + 16), (cx_axis - 7, gy0 + 30), (cx_axis + 7, gy0 + 30)], fill=_c4(TXT2))
d.polygon([(gx1 - 16, cy_mid), (gx1 - 30, cy_mid - 7), (gx1 - 30, cy_mid + 7)], fill=_c4(TXT2))
# منحنى cos خلال دور
t0x, t1x = cx_axis + 30, gx1 - 60
pts = []
for i in range(121):
    tt = i / 120.0
    tx = t0x + (t1x - t0x) * tt
    ty = cy_mid - amp * math.cos(2 * math.pi * tt)
    pts.append((tx, ty))
d.line(pts, fill=_c4(BRAND), width=5, joint="curve")
# دوالب t
for f, lab in [(0.25, "T₀/4"), (0.5, "T₀/2"), (0.75, "3T₀/4"), (1.0, "T₀")]:
    tx = t0x + (t1x - t0x) * f
    d.line([(tx, cy_mid - 6), (tx, cy_mid + 6)], fill=_c4(TXT2), width=3)
    lw = text_width(lab, DEJAVU, 16)
    draw_ltr(img, int(tx - lw // 2), cy_mid + 26, lab, 16, TXT2, path=DEJAVU)
# تسميات المحور الرأسي
draw_ltr(img, cx_axis - 92, cy_mid - amp - 6, "Xmax", 16, TXT2, path=DEJAVU)
draw_ltr(img, cx_axis - 104, cy_mid + amp - 14, "-Xmax", 16, TXT2, path=DEJAVU)
draw_ltr(img, t0x - 24, cy_mid - 26, "x", 18, BRAND2, path=DEJAVU_SI, slant=0.22)
draw_ltr(img, gx1 - 40, cy_mid + 10, "t", 18, BRAND2, path=DEJAVU_SI, slant=0.22)
# نقطة T₀/2 (أدنى)
txh = t0x + (t1x - t0x) * 0.5
d.ellipse([txh - 7, cy_mid + amp - 7, txh + 7, cy_mid + amp + 7], fill=_c4(GOLD))
yy = gy1 + 44
big = "x = Xmax·cos((2π/T₀)·t)"
bw = text_width(big, DEJAVU_SI, 26) + 40
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 54, (56, 189, 248, 22), radius=12)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 53], radius=12, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 20, yy + 38, big, 26, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 76
cv.draw_flow(cr, yy, [("أما من الجدول أو بيانياً أو حسابياً:", "ar")], 18, TXT2); yy += 40
cv.draw_flow(cr, yy, [("t = T₀/2  ⟹  x = Xmax·cos(π) = -Xmax", "la")], 19, TXT); yy += 40
cv.draw_flow(cr, yy, [("t = 5T₀/4  ⟹  x = Xmax·cos(5π/2) = Xmax·cos(2π + π/2) = 0", "la")], 19, TXT)

# ---------- S3: البطاقات (3) ----------
pl, pr = cv.phone(X3, SY, PW, PH, "بطاقات المراجعة", SUB)
cards = [
    ([("الشكل المختزل لتابع المطال", "ar")], 300, [
        [("x = Xmax·cos(ω₀t)", "la")],
        [("يُستنتج عندما يبدأ الجسم من المطال الأعظمي الموجب (φ = 0 rad).", "ar")],
    ]),
    ([("متى يكون المطال أعظمي؟", "ar")], 300, [
        [("في الوضعين الجانبيين:  ", "ar"), ("x = ±Xmax", "la")],
    ]),
    ([("متى ينعدم المطال؟", "ar")], 300, [
        [("في مركز الاهتزاز:  ", "ar"), ("x = 0", "la")],
        [("عند t = T₀/4 و 3T₀/4 من كل دور.", "ar")],
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

# ============================ الصف الثاني ============================
# ---------- S4: الاختبار الذاتي (4) ----------
pl, pr = cv.phone(X2, SY2, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("بفرض مبدأ الزمن عند المطال الأعظمي الموجب —", "ar")],
       [("الطور الابتدائي φ يساوي:", "ar")] ],
     [[("0 rad", "la")], [("π/2", "la")], [("π", "la")], [("π/4", "la")]]),
    ([ [("في التابع المختزل — المطال يكون أعظمي", "ar")],
       [("عندما:", "ar")] ],
     [[("cos(ω₀t) = ±1", "la"), (" — في الوضعين الجانبيين", "ar")],
      [("cos(ω₀t) = 0", "la"), (" — في المركز", "ar")],
      [("الجسم في مركز الاهتزاز", "ar")],
      [("ω₀t = π/2", "la"), (" فقط", "ar")]]),
    ([ [("قيمة المطال في اللحظة ", "ar"), ("t = T₀/2", "la"), (" هي:", "ar")] ],
     [[("-Xmax", "la")], [("+Xmax", "la")], [("0", "la")], [("Xmax/2", "la")]]),
    ([ [("قيمة المطال في اللحظة ", "ar"), ("t = 5T₀/4", "la"), (" تساوي:", "ar")] ],
     [[("0", "la")], [("Xmax", "la")], [("-Xmax", "la")], [("Xmax/2", "la")]]),
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
    ([("الشرح 1 — استنتاج الشكل المختزل", "ar")], X1),
    ([("الشرح 2 — أعظمي/معدوم + الخط البياني", "ar")], X2),
    ([("بطاقات المراجعة (3)", "ar")], X3),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
segs = [("الاختبار الذاتي (4 قوالب)", "ar")]
w = cv.flow_width(segs, 23, True)
cv.draw_flow(X2 + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY2 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.5 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.5-review.png")
