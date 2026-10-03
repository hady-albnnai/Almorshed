# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.10: قوة الارجاع والتسارع والسرعة + العظمى (وصفة 7)"""
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
cv.draw_flow(XR, 162, [("الوحدة 1.10 — ", "ar"), ("قوة الارجاع والتسارع والسرعة", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("وصفة 7: حسب المعطى (x أو t) + العظمى", TXT2, LINE, CARD),
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
SUB = "الوحدة 1.10 · النواس المرن"

# ---------- S1: الوصفة 7 (عند x / عند t) ----------
pl, pr = cv.phone(XR1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "حسب المعطى: x أو t", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وصفة 7", 19, TXT2, LINE, CARD2)
yy = SY + 180
cv.draw_flow(cr, yy, [("7) قوة الارجاع والتسارع والسرعة:", "ar")], 19, TXT, bold=True)
yy += 40
cv.draw_flow(cr, yy, [("عندما يذكر شدة أو طويلة: المقدار دوماً موجب (بالقيمة المطلقة)", "ar")], 17, BRAND)
yy += 52
cv.draw_flow(cr, yy, [("عند ", "ar"), ("x", "la"), (" معلومة:", "ar")], 18, BRAND, bold=True)
yy += 40
for segs in [
    [("F = −k·x", "la"), ("     (N)", "la")],
    [("a = −ω₀²·x", "la"), ("     (m·s⁻²)", "la")],
    [("v = ω₀√(X²max − x²)", "la"), ("     (m·s⁻¹)", "la")],
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(BRAND2))
    cv.draw_flow(cr - 24, yy, segs, 18, TXT)
    yy += 44
yy += 14
cv.draw_flow(cr, yy, [("عند ", "ar"), ("t", "la"), (" معلومة:", "ar")], 18, BRAND, bold=True)
yy += 40
for segs in [
    [("F = −kXmax·cos(ω₀t + φ)", "la")],
    [("a = −ω₀²Xmax·cos(ω₀t + φ)", "la")],
    [("v = −ω₀Xmax·sin(ω₀t + φ)", "la")],
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(GOLD))
    cv.draw_flow(cr - 24, yy, segs, 18, TXT)
    yy += 44

# ---------- S2: العظمى + الجدول المجمّع ----------
pl, pr = cv.phone(XL1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "العظمى + الجدول المجمّع", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY + 180
cv.draw_flow(cr, yy, [("والعظمى:", "ar")], 19, TXT, bold=True)
yy += 40
for segs in [
    [("Fmax = ∓kXmax", "la")],
    [("amax = ∓ω₀²Xmax", "la")],
    [("vmax = ∓ω₀Xmax", "la")],
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(GOLD))
    cv.draw_flow(cr - 24, yy, segs, 18, TXT)
    yy += 42
yy += 16
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 42
cv.draw_flow(cr, yy, [("الجدول المجمّع:", "ar")], 19, TXT, bold=True)
yy += 30
# جدول: صفوف F, a, v × أعمدة (عند x معلومة | عند t معلومة | العظمى)
tab_l, tab_r = pl + 18, pr - 18
col_w = (tab_r - tab_l) // 3
row_h = 74
tab_top = yy + 6
heads = ["عند x معلومة", "عند t معلومة", "العظمى"]
rows = [
    ("F", ["F = −k·x", "F = −kXmax·cos(ω₀t+φ)", "∓kXmax"]),
    ("a", ["a = −ω₀²·x", "a = −ω₀²Xmax·cos(ω₀t+φ)", "∓ω₀²Xmax"]),
    ("v", ["ω₀√(X²max − x²)", "−ω₀Xmax·sin(ω₀t+φ)", "∓ω₀Xmax"]),
]
# رأس الجدول
cv.alpha_rect(tab_l, tab_top, tab_r - tab_l, row_h, CARD2, radius=0)
for ci, h in enumerate(heads):
    cx0 = tab_l + ci * col_w
    hw_ = text_width(h, NASKH, 15, True)
    draw_rtl(img, cx0 + col_w - hw_ // 2 - 8, tab_top + 34, h, 15, BRAND, bold=True)
for ri, (lab, vals) in enumerate(rows):
    ry = tab_top + row_h + ri * row_h
    fill = CARD if ri % 2 == 0 else CARD2
    cv.alpha_rect(tab_l, ry, tab_r - tab_l, row_h - 2, fill, radius=0)
    draw_rtl(img, tab_l + 26, ry + 44, lab, 18, TXT, bold=True)
    for ci, val in enumerate(vals):
        cx0 = tab_l + ci * col_w + 44
        vw_ = text_width(val, DEJAVU, 15)
        draw_ltr(img, cx0 + (col_w - 44 - vw_) // 2, ry + 42, val, 15, TXT)
tab_bot = tab_top + row_h + 3 * row_h
for ci in range(4):
    xx = tab_l + ci * col_w
    d.line([(xx, tab_top), (xx, tab_bot)], fill=_c4(LINE), width=2)
for ri in range(4):
    yy_ = tab_top + ri * row_h
    d.line([(tab_l, yy_), (tab_r, yy_)], fill=_c4(LINE), width=2)
d.rectangle([tab_l, tab_top, tab_r, tab_bot], outline=_c4(LINE), width=2)
yy = tab_bot + 24
cv.draw_flow(cr - 12, yy, [("الشدة (إذا طُلب المقدار): القيمة المطلقة — دوماً موجبة", "ar")], 17, TXT2)

# ============================ الصف الثاني ============================
# ---------- S3: المثال المحلول ----------
pl, pr = cv.phone(XR1, SY2, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "من وصفة النوط", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.a_rounded(pl + 16, yy - 16, pr - 16, yy + 52, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 12, yy + 16, [
    ("هزازة بثابت صلابة ", "ar"), ("k = 20 N/m", "la"), (" — قوة الارجاع عند ", "ar"), ("x = 0.05 m", "la"),
], 18, TXT, bold=True)
yy += 92
steps = [
    [("عند ", "ar"), ("x", "la"), (" معلومة: ", "ar"), ("F = −k·x", "la")],
    [("نعوض ", "ar"), ("k = 20 N/m", "la"), (" و ", "ar"), ("x = 0.05 m", "la"), (": ", "la"), ("F = −20 × 0.05", "la")],
    [("F = −1 N", "la")],
    [("الشدة (إذا طُلب المقدار): ", "ar"), ("|F| = 1 N", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 18, TXT)
    yy += 56
ans = "F = −1 N"
bw3 = text_width(ans, DEJAVU_SI, 26) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw3 // 2, yy + 8, bw3, 64, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw3 // 2, yy + 8, pxc + bw3 // 2 - 1, yy + 71], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw3 // 2 + 32, yy + 48, ans, 26, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 108
draw_rtl(img, cr, yy, "الاتجاه: نحو مركز الاهتزاز دوماً (قوة ارجاع)", 18, BRAND)

# ---------- S4: الأسئلة ----------
pcx = XL1
pl, pr = cv.phone(pcx, SY2, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("عندما يكون المطال ", "ar"), ("x", "la"), (" معلوماً — قوة الارجاع:", "ar")] ],
     [[("F = −k·x", "la")], [("F = k·x", "la")], [("F = −k·x²", "la")], [("F = k/x", "la")]]),
    ([ [("عندما يكون المطال ", "ar"), ("x", "la"), (" معلوماً — التسارع:", "ar")] ],
     [[("a = −ω₀²·x", "la")], [("a = ω₀²·x", "la")], [("a = −ω₀·x", "la")], [("a = −2ω₀²·x", "la")]]),
    ([ [("السرعة العظمى لهزازة سعتها ", "ar"), ("Xmax", "la"), (" و نبضها الخاص ", "ar"), ("ω₀", "la"), (":", "la")] ],
     [[("vmax = ω₀·Xmax", "la")], [("vmax = ω₀²·Xmax", "la")], [("vmax = Xmax/ω₀", "la")], [("vmax = 2ω₀·Xmax", "la")]]),
    ([ [("هزازة ثابت صلابة نابضها ", "ar"), ("k = 20 N/m", "la"), (" وسعتها ", "ar"), ("Xmax = 10 cm", "la")],
       [("شدة قوة الارجاع العظمى؟", "ar")] ],
     [[("2 N", "la")], [("1 N", "la")], [("4 N", "la")], [("0.5 N", "la")]]),
]
by = SY2 + 96
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
    ([( "عند x معلومة / عند t معلومة (6 علاقات)", "ar")], XR1),
    ([( "العظمى + الجدول المجمّع", "ar")], XL1),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([( "مثال محلول (قوة الارجاع)", "ar")], XR1),
    ([( "الاختبار الذاتي (4 قوالب)", "ar")], XL1),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY2 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.10 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.10-review.png")
