# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.11: أزمنة المرور في مركز الاهتزاز + السرعة عند زمن المرور + مسألة (1/17)"""
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
cv.draw_flow(XR, 162, [("الوحدة 1.11 — ", "ar"), ("أزمنة المرور في مركز الاهتزاز", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("وصفتا 8 و 9 + مسألة (1/17)", TXT2, LINE, CARD),
    ("4 قوالب أسئلة", TXT2, LINE, CARD),
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
SUB = "الوحدة 1.11 · النواس المرن"

# ---------- S1: 8) أزمنة المرور — حالة خاصة + حالة عامة ----------
pl, pr = cv.phone(XR1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "أزمنة المرور في مركز الاهتزاز", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وصفة 8", 19, TXT2, LINE, CARD2)
yy = SY + 180
cv.draw_flow(cr, yy, [("8) أزمنة المرور في مركز الاهتزاز:", "ar")], 19, TXT, bold=True)
yy += 48
# حالة خاصة
cv.a_rounded(pl + 16, yy, pr - 16, yy + 176, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "أ", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("الحالة الخاصة: الجسم انطلق من أحد المطالين الأعظميين:", "ar")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 72, [("أزمنة المرور = أعداد فردية من ربع الدور:", "ar")], 16, TXT2)
cv.draw_flow(cr - 24, yy + 110, [("t₁ = T₀/4،  t₂ = 3T₀/4،  t₃ = 5T₀/4، ...", "la")], 19, MATHC)
yy += 200
# حالة عامة
cv.a_rounded(pl + 16, yy, pr - 16, yy + 306, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "ب", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("الحالة العامة: الجسم انطلق من أي نقطة:", "ar")], 17, TXT, bold=True)
cv.draw_flow(cr - 46, yy + 70, [("المرور عبر مركز الاهتزاز (", "ar"), ("x = 0", "la"), ("):", "la")], 16, TXT2)
cv.draw_flow(cr - 24, yy + 104, [("0 = Xmax·cos(ω₀t + φ)  ⟹  cos(ω₀t + φ) = 0", "la")], 17, MATHC)
yy2 = yy + 140
big = "ω₀t + φ = π/2 + πK"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy2, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy2, pxc + bw // 2 - 1, yy2 + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy2 + 46, big, 30, MATHC, path=DEJAVU_SI, slant=0.22)
cv.draw_flow(cr - 24, yy2 + 94, [("مرور أول: ", "ar"), ("K = 0", "la"), (" · مرور ثاني: ", "ar"), ("K = 1", "la"), (" · مرور ثالث: ", "ar"), ("K = 2", "la")], 17, TXT2)
yy += 330
cv.a_rounded(pl + 16, yy, pr - 16, yy + 96, 12, fill=(56, 189, 248, 18), outline=(56, 189, 248, 90))
cv.draw_flow(cr - 24, yy + 32, [("مثال سريع: هزازة دورتها ", "ar"), ("T₀ = 4 s", "la"), (" — أزمنة المرور:", "ar")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 70, [("1 s", "la"), (" ثم ", "ar"), ("3 s", "la"), (" ثم ", "ar"), ("5 s", "la")], 18, MATHC)
yy += 122
cv.draw_flow(cr, yy, [("نحل العلاقة نوجد زمن المرور المطلوب", "ar")], 16, TXT2)

# ---------- S2: 9) السرعة عند زمن المرور ----------
pl, pr = cv.phone(XL1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "السرعة عند زمن المرور", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وصفة 9", 19, TXT2, LINE, CARD2)
yy = SY + 180
cv.draw_flow(cr, yy, [("9) السرعة عند زمن مرور في مركز الاهتزاز:", "ar")], 19, TXT, bold=True)
yy += 52
steps = [
    [("نوجد زمن المرور المطلوب (بالوصفة 8)", "ar")],
    [("ثم نعوض في تابع السرعة:", "ar")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 18, TXT)
    yy += 56
big2 = "v = −ω₀Xmax·sin(ω₀t + φ)"
bw2 = text_width(big2, DEJAVU_SI, 28) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw2 // 2, yy, bw2, 64, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw2 // 2, yy, pxc + bw2 // 2 - 1, yy + 63], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw2 // 2 + 32, yy + 44, big2, 28, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 96
cv.draw_flow(cr, yy, [("في مركز الاهتزاز تكون السرعة عظمى:", "ar")], 18, TXT, bold=True)
yy += 40
cv.draw_flow(cr, yy, [("v = ∓ω₀Xmax", "la")], 20, MATHC)
yy += 66
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 46
cv.draw_flow(cr, yy, [("تتمة الوصفين 8 و 9:", "ar")], 19, TXT, bold=True)
yy += 44
cv.a_rounded(pl + 16, yy, pr - 16, yy + 120, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 24, yy + 34, [("وصفة 8: الحالة الخاصة — أزمنة مرور = أعداد فردية من ", "ar"), ("T₀/4", "la")], 17, TXT)
cv.draw_flow(cr - 24, yy + 74, [("وصفة 8: الحالة العامة — ", "ar"), ("ω₀t + φ = π/2 + πK", "la")], 17, TXT)
yy += 144
cv.draw_flow(cr, yy, [("وصفة 9: نعوض زمن المرور في تابع السرعة", "ar")], 17, BRAND, bold=True)

# ============================ الصف الثاني ============================
# ---------- S3: مسألة (1/17) الجزء 1: ثوابت الحركة + T₀ ----------
pl, pr = cv.phone(XR1, SY2, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY2 + 100, "مسألة (1/17) — الجزء 1", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY2 + 100, "ثوابت الحركة", 19, TXT2, LINE, CARD2)
yy = SY2 + 180
cv.a_rounded(pl + 16, yy, pr - 16, yy + 104, 12, fill=CARD2, outline=LINE)
cv.draw_flow(cr - 24, yy + 30, [("هزازة: ", "ar"), ("k = 10 N/m", "la"), (" و ", "ar"), ("x = 0.1cos(πt + π/2)", "la")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 70, [("أوجد ثوابت الحركة و ", "ar"), ("T₀", "la"), (" و ", "ar"), ("m", "la"), (" و ", "ar"), ("v", "la"), (" عند ", "ar"), ("x = 6×10⁻² m", "la"), (" (", "la"), ("v > 0", "la"), (")", "la")], 17, TXT)
yy += 132
cv.draw_flow(cr, yy, [("بالمقارنة مع ", "ar"), ("x = Xmax·cos(ω₀t + φ)", "la"), (":", "la")], 18, TXT, bold=True)
yy += 46
for segs in [
    [("السعة: ", "ar"), ("Xmax = 0.1 = 10⁻¹ m", "la")],
    [("النبض الخاص: ", "ar"), ("ω₀ = π rad/s", "la")],
    [("الطور الابتدائي: ", "ar"), ("φ = π/2 rad", "la")],
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(BRAND2))
    cv.draw_flow(cr - 24, yy, segs, 18, TXT)
    yy += 42
yy += 20
cv.draw_flow(cr, yy, [("الدور الخاص:", "ar")], 18, TXT, bold=True)
yy += 42
big3 = "T₀ = 2π/ω₀ = 2π/π = 2 s"
bw3 = text_width(big3, DEJAVU_SI, 28) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw3 // 2, yy, bw3, 64, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw3 // 2, yy, pxc + bw3 // 2 - 1, yy + 63], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw3 // 2 + 32, yy + 44, big3, 28, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 100
cv.draw_flow(cr, yy, [("لاحظ: جميع الثوابت قُرأت مباشرة من التابع", "ar")], 16, TXT2)

# ---------- S4: مسألة (1/17) الجزء 2: m + v ----------
pl, pr = cv.phone(XL1, SY2, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "مسألة (1/17) — الجزء 2", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.draw_flow(cr, yy, [("الكتلة ", "ar"), ("m = ?", "la")], 19, TXT, bold=True)
yy += 48
steps = [
    [("من ", "ar"), ("ω₀² = k/m", "la"), (" : ", "la"), ("m = k/ω₀² = 10/π² ≈ 1 kg", "la")],
    [("طريقة ثانية من ", "ar"), ("T₀² = 40m/k", "la"), (": ", "la"), ("m = T₀²·k/40 = (4×10)/40 = 1 kg", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 17, TXT)
    yy += 52
yy += 24
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 46
cv.draw_flow(cr, yy, [("السرعة ", "ar"), ("v = ?", "la"), (" عند ", "ar"), ("x = 6×10⁻² m", "la"), (" و ", "ar"), ("v > 0", "la"), (":", "la")], 19, TXT, bold=True)
yy += 48
steps2 = [
    [("v = ω₀√(X²max − x²)", "la")],
    [(":  ", "la"), ("= π√(10⁻² − 36×10⁻⁴)", "la")],
    [(":  ", "la"), ("= π√(100×10⁻⁴ − 36×10⁻⁴)", "la")],
    [(":  ", "la"), ("= π√(64×10⁻⁴) = 8π×10⁻²", "la")],
]
for i, segs in enumerate(steps2):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 17, MATHC)
    yy += 48
ans = "v ≈ 0.25 m/s"
bw4 = text_width(ans, DEJAVU_SI, 26) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw4 // 2, yy + 8, bw4, 60, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw4 // 2, yy + 8, pxc + bw4 // 2 - 1, yy + 67], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw4 // 2 + 32, yy + 46, ans, 26, BRAND, path=DEJAVU_SI, slant=0.22)

# ============================ الصف الثالث ============================
# ---------- S5: مسألة (1/17) الجزء 3: بدء الزمن + إضافي ----------
pl, pr = cv.phone(XR1, SY3, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cv.pill_r(cr, SY3 + 100, "مسألة (1/17) — الجزء 3", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY3 + 180
cv.draw_flow(cr, yy, [("4) بدء الزمن ", "ar"), ("t = 0", "la"), (":", "la")], 19, TXT, bold=True)
yy += 50
cv.draw_flow(cr, yy, [("الموضع: ", "ar"), ("x = 0.1cos(π/2) = 0", "la"), (" (مركز الاهتزاز)", "ar")], 18, TXT)
yy += 40
cv.draw_flow(cr, yy, [("الجهة: ", "ar"), ("v = −ω₀Xmax·sin(π/2) < 0", "la")], 18, TXT)
yy += 34
cv.draw_flow(cr, yy, [("الجسم يتحرك بالاتجاه السالب", "ar")], 17, BRAND, bold=True)
yy += 56
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 46
cv.draw_flow(cr, yy, [("إضافي: بين موضع وجهة الحركة في اللحظة ", "ar"), ("t = 1 s", "la"), (":", "la")], 18, TXT, bold=True)
yy += 52
steps3 = [
    [("الموضع: ", "ar"), ("x = 0.1cos(π + π/2) = 0.1cos(3π/2) = 0", "la"), (" (مركز)", "ar")],
    [("الجهة: ", "ar"), ("v = −π·0.1·sin(3π/2) = +0.1π > 0", "la")],
]
for i, segs in enumerate(steps3):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 17, TXT)
    yy += 50
cv.draw_flow(cr, yy, [("في اللحظة ", "ar"), ("t = 1 s", "la"), (" الجسم يتحرك بالاتجاه الموجب", "ar")], 17, BRAND, bold=True)
yy += 40
cv.draw_flow(cr, yy, [("لاحظ: كل نصف دورة يعبر المركز مرة واحدة", "ar")], 15, TXT2)

# ---------- S6: الأسئلة ----------
pcx = XL1
pl, pr = cv.phone(pcx, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("انطلق الجسم من المطال الأعظمي الموجب — أول زمن مرور في مركز الاهتزاز:", "ar")] ],
     [[("t = T₀/4", "la")], [("t = T₀/2", "la")], [("t = 3T₀/4", "la")], [("t = T₀", "la")]]),
    ([ [("أزمنة المرور في مركز الاهتزاز (عند الانطلاق من المطال الأعظمي):", "ar")] ],
     [[("أعداد فردية من ربع الدور", "ar")], [("أعداد زوجية من ربع الدور", "ar")], [("مضاعفات ", "ar"), ("T₀/2", "la")], [("كل اللحظات", "ar")]]),
    ([ [("الحالة العامة — شرط المرور عبر مركز الاهتزاز:", "ar")] ],
     [[("ω₀t + φ = π/2 + πK", "la")], [("ω₀t + φ = πK", "la")], [("ω₀t + φ = π/2 فقط", "la")], [("ω₀t + φ = 0", "la")]]),
    ([ [("هزازة دورتها ", "ar"), ("T₀ = 0.8 s", "la"), (" انطلقت من المطال الأعظمي — ثالث زمن مرور في المركز (بالثواني):", "ar")] ],
     [[("1 s", "la")], [("0.5 s", "la")], [("1.5 s", "la")], [("2 s", "la")]]),
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
    ([("أزمنة المرور: حالة خاصة + حالة عامة", "ar")], XR1),
    ([("السرعة عند زمن المرور (وصفة 9)", "ar")], XL1),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([("مسألة (1/17) — ثوابت الحركة و T₀", "ar")], XR1),
    ([("مسألة (1/17) — الكتلة و السرعة", "ar")], XL1),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
row3 = [
    ([("مسألة (1/17) — بدء الزمن + إضافي", "ar")], XR1),
    ([("الاختبار الذاتي (4 قوالب)", "ar")], XL1),
]
for segs, x in row3:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY3 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY3 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.11 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.11-review.png")
