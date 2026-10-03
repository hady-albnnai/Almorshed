# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.7: التابع الزمني للتسارع + أعظمي/معدوم + س6 (منحنى + جدول + مثال)"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
H = 4940
cv = ReviewCanvas(W, H)
d = cv.d
img = cv.img
XR = 2400

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.7 — ", "ar"), ("التابع الزمني للتسارع + س6", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("الجدول + اللحظات من النوط — المنحنى مرسوم", TXT2, LINE, CARD),
    ("شرح + 4 بطاقات + مثال محلول + 4 أسئلة", TXT2, LINE, CARD),
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
SY3 = 3390
SUB = "الوحدة 1.7 · النواس المرن"

# ---------- S1: الشرح (س6 + الاستنتاج) ----------
pl, pr = cv.phone(XR1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "استنتاج تابع التسارع", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٧", 19, TXT2, LINE, CARD2)
yy = SY + 180
cv.draw_flow(cr, yy, [("س6) في النواس الغير متخامد انطلاقا من تابع المطال", "ar")], 18, TXT)
yy += 30
cv.draw_flow(cr, yy, [("في الشكل المختزل المطلوب:", "ar")], 18, TXT)
yy += 40
for btxt in [
    "استنتج تابع التسارع",
    "بين متى يكون التسارع أعظمي ومتى ينعدم",
    "ارسم الخط البياني لتغيرات التسارع بدلالة الزمن خلال دور واحد",
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(BRAND2))
    cv.draw_flow(cr - 24, yy, [(btxt, "ar")], 17, TXT2)
    yy += 32
cv.draw_flow(cr - 24, yy, [
    ("أوجد قيمة التسارع في اللحظة ", "ar"), ("t = 3T₀/2", "la"),
], 17, TXT2)
yy += 56
steps = [
    [("نبدأ من: ", "ar"), ("x = Xmax·cos(ω₀t)   (1)", "la")],
    [("المشتقة الأولى: ", "ar"), ("v = dx/dt = −ω₀·Xmax·sin(ω₀t)   (2)", "la")],
    [("المشتقة الثانية: ", "ar"), ("a = dv/dt = −ω₀²·Xmax·cos(ω₀t)   (3)", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 18, TXT)
    yy += 54
big = "a = −ω₀²·Xmax·cos(ω₀t) = −ω₀²·x"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy + 8, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy + 8, pxc + bw // 2 - 1, yy + 73], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 50, big, 30, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 104
draw_rtl(img, cr, yy, "التسارع يتناسب طردا مع المطال ويعاكسه بالإشارة —", 18, TXT2)
cv.draw_flow(cr, yy + 30, [
    ("ويتجه دوما إلى مركز الاهتزاز (وجهة ", "ar"), ("F = m·a", "la"), (" هي جهته)", "ar"),
], 18, TXT2)

# ---------- S2: بطاقتا الأعظمي/المعدوم + جدول القيم + اللحظات ----------
pl, pr = cv.phone(XL1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "أعظمي/معدوم + جدول + اللحظات", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY + 176
cv.a_rounded(pl + 16, yy, pr - 16, yy + 112, 14, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 16, "a", BRAND2)
cv.draw_flow(cr - 46, yy + 36, [("التسارع أعظمي: ", "ar"), ("في المطالين الأعظميين", "ar")], 19, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 82, [("a_max = |±ω₀²·Xmax|", "la"), ("    ⇐    ", "la"), ("x = ∓Xmax", "la")], 20, MATHC)
yy += 134
cv.a_rounded(pl + 16, yy, pr - 16, yy + 112, 14, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 16, "b", BRAND2)
cv.draw_flow(cr - 46, yy + 36, [("التسارع معدوم: ", "ar"), ("في مركز الاهتزاز", "ar")], 19, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 82, [("a = 0", "la"), ("    ⇐    ", "la"), ("x = 0", "la")], 20, MATHC)
yy += 142
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 40
cv.draw_flow(cr, yy, [("جدول القيم خلال دور واحد:", "ar")], 19, TXT, bold=True)
yy += 28
tab_l, tab_r = pl + 24, pr - 24
lab_w = 150
n_cols = 5
col_w = (tab_r - tab_l - lab_w) // n_cols
row_h = 50
tab_top = yy + 6
rows = [
    ("t",       ["0", "T₀/4", "T₀/2", "3T₀/4", "T₀"]),
    ("θ",       ["0", "π/2", "π", "3π/2", "2π"]),
    ("cos θ",   ["1", "0", "−1", "0", "1"]),
    ("a",       ["−ω₀²Xmax", "0", "+ω₀²Xmax", "0", "−ω₀²Xmax"]),
]
for ri, (lab, vals) in enumerate(rows):
    ry = tab_top + ri * row_h
    fill = CARD2 if ri % 2 == 0 else CARD
    cv.alpha_rect(tab_l, ry, tab_r - tab_l, row_h - 4, fill, radius=0)
    lw_ = text_width(lab, DEJAVU, 16)
    draw_ltr(img, tab_l + 18, ry + 28, lab, 16, TXT2, path=DEJAVU, bold=(lab == "a"))
    d.line([(tab_l + lab_w, ry), (tab_l + lab_w, ry + row_h - 4)], fill=_c4(LINE), width=2)
    for ci, val in enumerate(vals):
        cx0 = tab_l + lab_w + ci * col_w
        vw_ = text_width(val, DEJAVU, 16)
        vc = BRAND if (ri == 3 and val in ("−ω₀²Xmax", "+ω₀²Xmax")) else TXT
        draw_ltr(img, cx0 + (col_w - vw_) // 2, ry + 28, val, 16, vc, path=DEJAVU, bold=(ri == 3))
tab_bot = tab_top + 4 * row_h
d.rectangle([tab_l, tab_top, tab_r, tab_bot - 4], outline=_c4(LINE), width=2)
yy = tab_bot + 18
cv.draw_flow(cr, yy, [("اللحظات التي يكون فيها التسارع:", "ar")], 17, TXT, bold=True)
yy += 30
for segs in [
    [("أعظمي موجب: ", "ar"), ("t = T₀/2", "la")],
    [("أعظمي سالب: ", "ar"), ("t = 0", "la"), (" و ", "ar"), ("t = T₀", "la")],
    [("معدوم: ", "ar"), ("t = T₀/4", "la"), (" و ", "ar"), ("t = 3T₀/4", "la")],
]:
    d.ellipse([cr - 10, yy - 13, cr - 2, yy - 5], fill=_c4(GOLD))
    cv.draw_flow(cr - 24, yy, segs, 16, TXT2)
    yy += 30

# ============================ الصف الثاني ============================
# ---------- S3: منحنى a–t ----------
pl, pr = cv.phone(XR1, SY2, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "الخط البياني خلال دور واحد", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
gx0, gx1 = pl + 90, pr - 60
gy_mid = SY2 + 400
amp = 150
d.line([(gx0 - 20, gy_mid), (gx1 + 30, gy_mid)], fill=_c4(TXT2), width=3)
d.polygon([(gx1 + 44, gy_mid), (gx1 + 26, gy_mid - 9), (gx1 + 26, gy_mid + 9)], fill=_c4(TXT2))
d.line([(gx0 - 20, gy_mid + amp + 40), (gx0 - 20, gy_mid - amp - 40)], fill=_c4(TXT2), width=3)
d.polygon([(gx0 - 20, gy_mid - amp - 52), (gx0 - 29, gy_mid - amp - 34), (gx0 - 11, gy_mid - amp - 34)], fill=_c4(TXT2))
marks = [(0.0, "0"), (0.25, "T₀/4"), (0.5, "T₀/2"), (0.75, "3T₀/4"), (1.0, "T₀")]
for frac, lab in marks:
    xx = gx0 + int((gx1 - gx0) * frac)
    d.line([(xx, gy_mid - amp - 20), (xx, gy_mid + amp + 20)], fill=_c4(LINE), width=2)
    lw_ = text_width(lab, DEJAVU, 20)
    draw_ltr(img, xx - lw_ // 2, gy_mid + amp + 52, lab, 20, TXT2, path=DEJAVU)
for yyv, lab in [(gy_mid - amp, "+ω₀²Xmax"), (gy_mid, "0"), (gy_mid + amp, "−ω₀²Xmax")]:
    draw_ltr(img, gx0 - 96, yyv - 12, lab, 17, TXT2, path=DEJAVU)
    d.line([(gx0 - 20, yyv), (gx0, yyv)], fill=_c4(TXT2), width=2)
# المنحنى: a = −ω₀²Xmax·cos(2π t/T₀)
pts = []
N = 240
for i in range(N + 1):
    t = i / N
    xx = gx0 + (gx1 - gx0) * t
    yy_ = gy_mid + amp * math.cos(2 * math.pi * t)
    pts.append((xx, yy_))
d.line(pts, fill=_c4(BRAND2), width=6, joint="curve")
for frac, val in [(0.0, 1), (0.25, 0), (0.5, -1), (0.75, 0), (1.0, 1)]:
    xx = gx0 + int((gx1 - gx0) * frac)
    yy_ = gy_mid + amp * val
    d.ellipse([xx - 9, yy_ - 9, xx + 9, yy_ + 9], fill=_c4(GOLD), outline=_c4(BG2), width=3)
yy = SY2 + 700
cv.a_rounded(pl + 16, yy, pr - 16, yy + 120, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 36, [("من حدود جيب التمام: ", "ar"), ("cos(0)=1 · cos(π/2)=0 · cos(π)=−1 · cos(3π/2)=0 · cos(2π)=1", "la")], 16, TXT2)
cv.draw_flow(cr - 12, yy + 78, [
    ("إذن: ", "ar"), ("0 → −ω₀²Xmax · T₀/4 → 0 · T₀/2 → +ω₀²Xmax · 3T₀/4 → 0 · T₀ → −ω₀²Xmax", "la"),
], 16, TXT)
yy += 160
big2 = "a = −ω₀²·Xmax·cos( (2π/T₀)·t )"
bw2 = text_width(big2, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw2 // 2, yy, bw2, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw2 // 2, yy, pxc + bw2 // 2 - 1, yy + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw2 // 2 + 32, yy + 46, big2, 30, MATHC, path=DEJAVU_SI, slant=0.22)

# ---------- S4: المثال المحلول (س4 من س6) ----------
pl, pr = cv.phone(XL1, SY2, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "من نوطة الأستاذ", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.a_rounded(pl + 16, yy - 16, pr - 16, yy + 66, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 12, [("للتابع: ", "ar"), ("a = −ω₀²·Xmax·cos( (2π/T₀)·t )", "la")], 18, TXT)
cv.draw_flow(cr - 12, yy + 48, [("أوجد قيمة التسارع في اللحظة ", "ar"), ("t = 3T₀/2", "la")], 18, BRAND, bold=True)
yy += 100
steps = [
    [("نعوض ", "ar"), ("t = 3T₀/2:  ", "la"), ("a = −ω₀²·Xmax·cos( (2π/T₀)·(3T₀/2) )", "la")],
    [("(2π/T₀)·(3T₀/2) = 3π:  ", "la"), ("a = −ω₀²·Xmax·cos(3π)", "la")],
    [("cos(3π) = −1:  ", "la"), ("a = +ω₀²·Xmax", "la")],
    [("الجسم عند ", "ar"), ("x = −Xmax", "la"), (": التسارع موجب — متجه إلى مركز الاهتزاز", "ar")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 17, TXT)
    yy += 50
yy += 10
ans = "a(3T₀/2) = +ω₀²Xmax"
bw3 = text_width(ans, DEJAVU_SI, 26) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw3 // 2, yy, bw3, 64, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw3 // 2, yy, pxc + bw3 // 2 - 1, yy + 63], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw3 // 2 + 32, yy + 44, ans, 26, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 96
draw_rtl(img, cr, yy, "نحو مركز الاهتزاز — الجسم في المطال الأعظمي السالب", 18, BRAND)

# ============================ الصف الثالث: S5 الأسئلة ============================
pcx = (W - PW) // 2
pl, pr = cv.phone(pcx, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("من تابع المطال ", "ar"), ("x = Xmax·cos(ω₀t)", "la"), (" — تابع التسارع:", "ar")] ],
     [[("a = −ω₀²·Xmax·cos(ω₀t)", "la")], [("a = +ω₀²·Xmax·cos(ω₀t)", "la")],
      [("a = −ω₀²·Xmax·sin(ω₀t)", "la")], [("a = −2ω₀²·Xmax·cos(ω₀t)", "la")]]),
    ([ [("التسارع يكون أعظمي:", "ar")] ],
     [[("في المطالين الأعظميين ", "ar"), ("(x = ±Xmax)", "la")], [("في مركز الاهتزاز ", "ar"), ("(x = 0)", "la")],
      [("عند اللحظة ", "ar"), ("t = T₀/4", "la"), (" فقط", "ar")], [("لا يكون أعظمي أبداً", "ar")]]),
    ([ [("نواس سعة اهتزازه ", "ar"), ("Xmax = 10 cm", "la"), (" و تردده الزاوي ", "ar"), ("ω₀ = 2 rad/s", "la")],
       [("شدة التسارع الأعظمي (في المطال الأعظمي)؟", "ar")] ],
     [[("40 cm/s²", "la")], [("20 cm/s²", "la")], [("10 cm/s²", "la")], [("80 cm/s²", "la")]]),
    ([ [("في اللحظة ", "ar"), ("t = 3T₀/2", "la"), (" المطال ", "ar"), ("x = −Xmax", "la")],
       [("اتجاه التسارع:", "ar")] ],
     [[("نحو مركز الاهتزاز (التجاه الموجب)", "ar")], [("بعيدا عن المركز (التجاه السالب)", "ar")],
      [("معدوم — الجسم ساكن", "ar")], [("في اتجاه السرعة", "ar")]]),
]
by = SY3 + 96
letters = ["أ", "ب", "ج", "د"]
for qi, (stem_lines, opts) in enumerate(qs):
    qh = 272
    cv.card(pl, by, pr - pl, qh, 22, CARD, border=LINE)
    cv.number_badge(pl + 20, by + 20, qi + 1, BRAND2)
    yy = by + 44
    for line in stem_lines:
        cv.draw_flow(pr - 24, yy, line, 18, TXT)
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
        cv.draw_flow(pr - 76, yy + 28, segs, 16, opt_color)
        yy += row_h
    by += qh + 14
zr = pr - 24
zw = 300
cv.alpha_rect(zr - zw, by + 6, zw, 64, (45, 212, 167, 26), radius=32)
d.rounded_rectangle([zr - zw, by + 6, zr - 1, by + 69], radius=32, outline=(45, 212, 167, 140), width=2)
cv.refresh(zr - 40, by + 38, 14, BRAND)
cv.draw_flow(zr - 64, by + 46, [("سؤال متجدد", "ar")], 20, BRAND, bold=True)

# ============================ التسميات السفلية ============================
row1 = [
    ([( "س6 + الاستنتاج (3 خطوات + النتيجة)", "ar")], XR1),
    ([( "أعظمي/معدوم + جدول القيم + اللحظات", "ar")], XL1),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([( "منحنى ", "ar"), ("a–t", "la"), (" خلال دور واحد", "ar")], XR1),
    ([( "مثال محلول (قيمة التسارع عند ", "ar"), ("3T₀/2", "la"), (")", "ar")], XL1),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
row3 = [
    ([( "الاختبار الذاتي (4 قوالب)", "ar")], pcx),
]
for segs, x in row3:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY3 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY3 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.7 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.7-review.png")
