# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.8: الطاقة الكلية (الميكانيكية) + س7 (استنتاج + مخطط E–x + مسألة)"""
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
cv.draw_flow(XR, 162, [("الوحدة 1.8 — ", "ar"), ("الطاقة الكلية (الميكانيكية) + س7", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("الاستنتاج + المخطط + المسألة من النوط", TXT2, LINE, CARD),
    ("شرح + 4 بطاقات + مسألة محلولة + 4 أسئلة", TXT2, LINE, CARD),
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
SUB = "الوحدة 1.8 · النواس المرن"

# ---------- S1: الشرح (س7 + الاستنتاج) ----------
pl, pr = cv.phone(XR1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "استنتاج الطاقة الكلية", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٨", 19, TXT2, LINE, CARD2)
yy = SY + 176
cv.draw_flow(cr, yy, [("س7) في النواس المرن الغير متخامد المطلوب:", "ar")], 18, TXT)
yy += 38
for btxt in [
    "استنتج علاقة الطاقة الكلية",
    "حدد شكل الطاقة في كل من: مركز الاهتزاز / المطالين الأعظميين",
    "ارسم الخط البياني لتغيرات الطاقة المرونية بدلالة المطال",
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(BRAND2))
    cv.draw_flow(cr - 24, yy, [(btxt, "ar")], 17, TXT2)
    yy += 32
yy += 24
steps = [
    [("الطاقة الكلية: ", "ar"), ("E = Ek + Ep = ½mv² + ½kx²", "la")],
    [("لكن ", "ar"), ("ω₀² = k/m ⟹ mω₀² = k", "la")],
    [("بعد التعويض: ", "ar"), ("E = ½kX²max[sin²(ω₀t+φ) + cos²(ω₀t+φ)]", "la")],
    [("وبما أن ", "ar"), ("sin²(ω₀t+φ) + cos²(ω₀t+φ) = 1", "la"), (":", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 18, TXT)
    yy += 54
big = "E = ½·k·X²max = constant"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy + 8, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy + 8, pxc + bw // 2 - 1, yy + 73], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 50, big, 30, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 104
draw_rtl(img, cr, yy, "الطاقة الكلية لا تعتمد على الزمن — تتبادل بين حركية ومرونية", 18, TXT2)

# ---------- S2: بطاقتا الشكل + مخطط E–x ----------
pl, pr = cv.phone(XL1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "شكل الطاقة + المخطط E–x", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY + 172
cv.a_rounded(pl + 16, yy, pr - 16, yy + 104, 14, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "a", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("في مركز الاهتزاز ", "ar"), ("(x = 0)", "la"), (":", "la")], 18, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 76, [("E = Ek", "la"), (" فقط — ", "ar"), ("Ep = 0", "la")], 18, MATHC)
yy += 126
cv.a_rounded(pl + 16, yy, pr - 16, yy + 104, 14, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "b", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("في المطالين الأعظميين ", "ar"), ("(x = ±Xmax)", "la"), (":", "la")], 18, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 76, [("E = Ep", "la"), (" فقط — ", "ar"), ("Ek = 0 (v = 0)", "la")], 18, MATHC)
yy += 134
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
# مخطط الطاقة بدلالة المطال
cx = (pl + pr) // 2
half = 280
gy_bot = SY + 960
Eh = 330
gy_E = gy_bot - Eh
# محاور
d.line([(cx - half - 30, gy_bot), (cx + half + 30, gy_bot)], fill=_c4(TXT2), width=3)
d.polygon([(cx + half + 44, gy_bot), (cx + half + 26, gy_bot - 9), (cx + half + 26, gy_bot + 9)], fill=_c4(TXT2))
d.line([(cx - half - 30, gy_bot + 20), (cx - half - 30, gy_bot - Eh - 40)], fill=_c4(TXT2), width=3)
d.polygon([(cx - half - 30, gy_bot - Eh - 52), (cx - half - 39, gy_bot - Eh - 34), (cx - half - 21, gy_bot - Eh - 34)], fill=_c4(TXT2))
# E = ثابت
d.line([(cx - half, gy_E), (cx + half, gy_E)], fill=_c4(BRAND), width=4)
draw_ltr(img, cx + half - 60, gy_E - 30, "E = const", 17, BRAND, path=DEJAVU, bold=True)
# المنحنيات: Ep = E·(x/Xmax)²  و  Ek = E·(1 − (x/Xmax)²)
N = 140
pts_ep, pts_ek = [], []
for i in range(N + 1):
    u = -1 + 2 * i / N
    xx = cx + half * u
    yep = gy_bot - Eh * u * u
    yek = gy_bot - Eh * (1 - u * u)
    pts_ep.append((xx, yep))
    pts_ek.append((xx, yek))
d.line(pts_ep, fill=_c4(BRAND2), width=5, joint="curve")
d.line(pts_ek, fill=_c4(GOLD), width=5, joint="curve")
# تسميات
draw_ltr(img, cx - half + 4, gy_bot - Eh + 26, "Ep", 19, BRAND2, path=DEJAVU, bold=True)
draw_ltr(img, cx + half - 40, gy_bot - Eh + 26, "Ep", 19, BRAND2, path=DEJAVU, bold=True)
draw_ltr(img, cx + 14, gy_bot - Eh + 44, "Ek", 19, GOLD, path=DEJAVU, bold=True)
# تسميات المحور الأفقي
for xx, lab in [(cx - half, "−Xmax"), (cx, "0"), (cx + half, "+Xmax")]:
    lw_ = text_width(lab, DEJAVU, 19)
    draw_ltr(img, xx - lw_ // 2, gy_bot + 14, lab, 19, TXT2, path=DEJAVU)
    d.line([(xx, gy_bot), (xx, gy_bot + 8)], fill=_c4(TXT2), width=2)
# تسميات المحور الرأسي
draw_ltr(img, cx - half - 74, gy_bot - 12, "E", 19, TXT2, path=DEJAVU)
# نقاط التقاء
for u in (-1, 0, 1):
    xx = cx + half * u
    d.ellipse([xx - 8, gy_E - 8, xx + 8, gy_E + 8], fill=_c4(BRAND), outline=_c4(BG2), width=3)
yy = gy_bot + 60
cv.draw_flow(cr - 12, yy, [("عند ", "ar"), ("x = 0", "la"), (": ", "la"), ("Ek = E", "la"), (" · عند ", "ar"), ("x = ±Xmax", "la"), (": ", "la"), ("Ep = E", "la")], 16, TXT2)

# ============================ الصف الثاني ============================
# ---------- S3: علاقة السرعة بالمطال ----------
pl, pr = cv.phone(XR1, SY2, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY2 + 100, "علاقة السرعة بالمطال", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY2 + 100, "ثانياً", 19, TXT2, LINE, CARD2)
yy = SY2 + 190
cv.a_rounded(pl + 16, yy - 16, pr - 16, yy + 52, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 16, [("الطاقة الحركية: ", "ar"), ("Ek = E − Ep", "la")], 19, TXT, bold=True)
yy += 76
steps = [
    [("Ek = ½mv² = ½kX²max − ½kx²", "la")],
    [("mv² = k[X²max − x²]", "la"), ("    ⟹    ", "la"), ("v² = (k/m)·[X²max − x²]", "la")],
    [("وبما أن ", "ar"), ("k/m = ω₀²", "la"), (":", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 18, TXT)
    yy += 56
big2 = "v = ω₀·√(X²max − x²)"
bw2 = text_width(big2, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw2 // 2, yy + 6, bw2, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw2 // 2, yy + 6, pxc + bw2 // 2 - 1, yy + 71], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw2 // 2 + 32, yy + 48, big2, 30, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 104
draw_rtl(img, cr, yy, "السرعة عظمى في المركز ومعدومة في المطالين الأعظميين", 18, TXT2)

# ---------- S4: المسألة المحلولة (المقارنة xA/xB) ----------
pl, pr = cv.phone(XL1, SY2, PW, PH, "مسألة محلولة", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "من نوطة الأستاذ", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.a_rounded(pl + 16, yy - 16, pr - 16, yy + 52, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 16, [
    ("المقارنة بين Ek عند ", "ar"), ("x_A = −Xmax/2", "la"), (" و ", "ar"), ("x_B = Xmax/√2", "la"),
], 18, TXT, bold=True)
yy += 84
steps = [
    [("عند ", "ar"), ("x_A:  ", "la"), ("EkA = ½k[X²max − X²max/4]", "la")],
    [("EkA = ½kX²max(1 − 1/4) = ¾E", "la")],
    [("عند ", "ar"), ("x_B:  ", "la"), ("EkB = ½k[X²max − X²max/2]", "la")],
    [("EkB = ½kX²max(1 − 1/2) = ½E", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 17, TXT)
    yy += 50
yy += 8
ans = "EkA = ¾E   >   EkB = ½E"
bw3 = text_width(ans, DEJAVU_SI, 26) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw3 // 2, yy, bw3, 64, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw3 // 2, yy, pxc + bw3 // 2 - 1, yy + 63], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw3 // 2 + 32, yy + 44, ans, 26, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 96
draw_rtl(img, cr, yy, "تستنتج: كلما زاد المطال x قلت الطاقة الحركية Ek وبالعكس", 18, BRAND)

# ============================ الصف الثالث: S5 الأسئلة ============================
pcx = (W - PW) // 2
pl, pr = cv.phone(pcx, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("هزازة توافقية ثوابت نوابها ", "ar"), ("k = 4 N/m", "la"), (" وسعتها ", "ar"), ("Xmax = 10 cm", "la")],
       [("الطاقة الكلية بالميلي جول (mJ)؟", "ar")] ],
     [[("20 mJ", "la")], [("10 mJ", "la")], [("40 mJ", "la")], [("4 mJ", "la")]]),
    ([ [("في مركز الاهتزاز ", "ar"), ("(x = 0)", "la"), (" الطاقة الكلية E:", "ar")] ],
     [[("حركية فقط ", "ar"), ("(Ek = E و Ep = 0)", "la")], [("مرونية فقط ", "ar"), ("(Ep = E و Ek = 0)", "la")],
      [("نصف حركية ونصف مرونية", "ar")], [("معدومة", "ar")]]),
    ([ [("في المطالين الأعظميين ", "ar"), ("(x = ±Xmax)", "la"), (" الطاقة الكلية E:", "ar")] ],
     [[("مرونية فقط ", "ar"), ("(Ep = E و Ek = 0)", "la")], [("حركية فقط ", "ar"), ("(Ek = E و Ep = 0)", "la")],
      [("نصف حركية ونصف مرونية", "ar")], [("تكون السرعة عظمى", "ar")]]),
    ([ [("في نقطة مطالها ", "ar"), ("x = Xmax/√3", "la"), (" — الطاقة الحركية:", "ar")] ],
     [[("Ek = ¾E", "la")], [("Ek = ⅓E", "la")], [("Ek = ⅔E", "la")], [("Ek = ½E", "la")]]),
]
corrects = [0, 0, 0, 2]
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
        correct = (oi == corrects[qi])
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
    ([( "س7 + استنتاج الطاقة الكلية (4 خطوات)", "ar")], XR1),
    ([( "شكل الطاقة + المخطط E–x", "ar")], XL1),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([( "علاقة السرعة بالمطال", "ar")], XR1),
    ([( "مسألة محلولة (مقارنة xA / xB)", "ar")], XL1),
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
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.8 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.8-review.png")
