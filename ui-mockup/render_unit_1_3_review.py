# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.3: الدراسة التحريكية (شرح ×3 + تجربة + بطاقات + مثال + أسئلة)"""
import os, sys
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
cv.draw_flow(XR, 162, [("الوحدة 1.3 — ", "ar"), ("الدراسة التحريكية", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("معادلة الحركة: الملاحظة ثم البرهان", TXT2, LINE, CARD),
    ("وحدة ثقيلة: شرح ③ + تجربة + 4 بطاقات + مثال + 4 أسئلة", TXT2, LINE, CARD),
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
SY3 = 3390
SUB = "الوحدة 1.3 · النواس المرن"

# ---------- S1: الشرح ① (س3 + المعادلة) ----------
pl, pr = cv.phone(X1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "الدراسة التحريكية", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٣", 19, TXT2, LINE, CARD2)
yy = SY + 192
draw_rtl(img, cr, yy, "س3) في النواس المرن الغير متخامد انطلاقا من العلاقة المعبرة عن قوة الارجاع:", 19, TXT); yy += 34
draw_rtl(img, cr, yy, "المطلوب: أثبت أن طبيعة الحركة جيبية توافقية بسيطة + استنتج الدور الخاص", 19, BRAND, bold=True); yy += 52
steps = [
    [("قوة الارجاع:  ", "ar"), ("F = -Kx", "la")],
    [("قانون نيوتن:  ", "ar"), ("m·ẍ = -Kx", "la")],
    [("نقتسم على m:  ", "ar"), ("ẍ = -(K/m)·x", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 52
yy += 8
draw_rtl(img, cr, yy, "معادلة تفاضلية من المرتبة الثانية — تقبل حلا جيبيا من الشكل:", 18, TXT2); yy += 54
big = "x = Xmax·cos(ω0t + φ)"
bw = text_width(big, DEJAVU_SI, 32) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 46, big, 32, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 110
cv.draw_flow(cr, yy, [("حيث ", "ar"), ("ω₀", "la"), (" هو النبض الخاص — نجده بالمقارنة (الشاشة التالية)", "ar")], 17, TXT2)
cv.bottom_bar(X1, SY + PH - 108, PW)

# ---------- S2: الشرح ② (المقارنة → ω0) ----------
pl, pr = cv.phone(X2, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "البرهان — متل ما بالنوط", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
steps = [
    [("السرعة:  ", "ar"), ("v = -ω0·Xmax·sin(ω0t + φ)", "la")],
    [("العجلة:  ", "ar"), ("a = -ω0²·Xmax·cos(ω0t + φ)", "la")],
    [("أي:  ", "ar"), ("a = -ω0²·x", "la")],
    [("بالمقارنة مع ẍ = -(K/m)·x:  ", "ar"), ("ω0² = K/m", "la")],
]
yy = SY + 170
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 52
yy += 8
big = "ω0 = √(K/m) > 0"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 64, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 63], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 45, big, 30, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 106
cv.draw_flow(cr, yy, [("وهذا محقق لأن m و K موجبان دوماً — ", "ar")], 18, TXT2); yy += 44
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 40
draw_rtl(img, cr, yy, "نتيجة: حركة النواس المرن حركة جيبية انسحابية توافقية بسيطة", 19, BRAND, bold=True)

# ---------- S3: الشرح ③ (الدور الخاص T0 + ملاحظاته) ----------
pl, pr = cv.phone(X3, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "الدور الخاص", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
_twT = text_width("T₀", DEJAVU_SI, 20)
_pwT = _twT + 44
cv.alpha_rect(cr - _pwT, SY + 100, _pwT, 48, CARD2, radius=24)
d.rounded_rectangle([cr - _pwT, SY + 100, cr - 1, SY + 147], radius=24, outline=_c4(LINE), width=2)
draw_ltr(img, cr - _twT - 22, SY + 136, "T₀", 20, MATHC, path=DEJAVU_SI, slant=0.22)
yy = SY + 190
cv.math_line(cr, yy, "T₀ = 2π/ω₀ = 2π/√(K/m)", 24); yy += 58
big = "T₀ = 2π·√(m/K)"
bw = text_width(big, DEJAVU_SI, 32) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 46, big, 32, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 112
notes = [
    [("T₀: ", "la"), ("الدور الخاص للنواس المرن (s)", "ar")],
    [("m: ", "la"), ("كتلة الجسم (kg)", "ar")],
    [("K: ", "la"), ("ثابت صلابة النابض ", "ar"), ("(N·m⁻¹)", "la")],
]
for segs in notes:
    cv.draw_flow(cr, yy, segs, 18, TXT2); yy += 34
yy += 14
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 38
cv.draw_flow(cr, yy, [("ملاحظات ", "ar"), ("T₀", "la"), (":", "ar")], 19, TXT, bold=True); yy += 40
obs = [
    [("• لا يتعلق بسعة الاهتزاز ", "ar"), ("Xmax", "la")],
    [("• لا يتعلق بـ g", "ar"), (" — أي لا يتعلق بالارتفاع", "ar")],
    [("• يتناسب طردا مع الجذر التربيعي للكتلة ", "ar"), ("(√m)", "la")],
    [("• يتناسب عكسا مع الجذر التربيعي للصلابة ", "ar"), ("(1/√K)", "la")],
]
for segs in obs:
    cv.draw_flow(cr, yy, segs, 18, TXT2); yy += 36

# ============================ الصف الثاني ============================
# ---------- S4: التجربة (تنبؤ + محاكاة) ----------
pl, pr = cv.phone(X3, SY2, PW, PH, "التجربة", SUB)
cx = (pl + pr) // 2
cv.a_rounded(pl, SY2 + 96, pr, SY2 + 160, 16, fill=(56, 189, 248, 20), outline=(56, 189, 248, 90))
pred = "تنبأ: إذا ضاعفنا الكتلة، الدور الخاص؟"
draw_rtl(img, pr - 18, SY2 + 136, pred, 17, BRAND2, bold=True)
chx = pl + 12
for label in ["لا يتغير", "×2", "×√2"]:
    if label == "لا يتغير":
        twc = text_width(label, NASKH, 17, True)
    else:
        twc = text_width(label, DEJAVU, 17, True)
    wch = twc + 44
    d.rounded_rectangle([chx, SY2 + 110, chx + wch, SY2 + 146], radius=12, fill=_c4(CARD2), outline=_c4(LINE), width=2)
    if label == "لا يتغير":
        draw_rtl(img, chx + wch - 22, SY2 + 136, label, 17, TXT2, path=NASKH, bold=True)
    else:
        draw_ltr(img, chx + 22, SY2 + 136, label, 17, TXT2, path=DEJAVU, bold=True)
    chx += wch + 12
sim_y = SY2 + 190
chw, chx = 148, pl + 12
cv.card(pl + 16, sim_y, pr - pl - 32, 430, 18, (8, 14, 26), border=(44, 63, 99))
cv.ceiling(cx - 130, sim_y + 50, 260, (148, 163, 184))
cv.spring(cx, sim_y + 50, sim_y + 250, 7, 34, (148, 163, 184))
d.ellipse([cx - 42, sim_y + 250, cx + 42, sim_y + 334], fill=_c4(GOLD))
cv.arrow_l(cx - 120, sim_y + 300, 40, BRAND, wdt=5)
draw_ltr(img, cx - 160, sim_y + 270, "F", 24, BRAND, path=DEJAVU_SI, slant=0.22)
vx = cx + 90
d.line([(vx, sim_y + 110), (vx, sim_y + 220)], fill=_c4(BRAND2), width=4)
d.polygon([(vx, sim_y + 100), (vx - 8, sim_y + 116), (vx + 8, sim_y + 116)], fill=_c4(BRAND2))
d.polygon([(vx, sim_y + 230), (vx - 8, sim_y + 214), (vx + 8, sim_y + 214)], fill=_c4(BRAND2))
draw_ltr(img, cx + 104, sim_y + 175, "x", 22, BRAND2, path=DEJAVU_SI, slant=0.22)
readout = "m = 1 kg · K = 4 N/m · T0 = π ≈ 3.14 s"
rw = text_width(readout, DEJAVU, 17, True)
d.rounded_rectangle([cx - rw // 2 - 24, sim_y + 358, cx + rw // 2 + 24, sim_y + 396], radius=12, fill=_c4(CARD2), outline=_c4(LINE), width=2)
draw_ltr(img, cx - rw // 2, sim_y + 384, readout, 17, TXT, path=DEJAVU, bold=True)
for i, (lbl, val) in enumerate([("الكتلة m", "0.5 — 4 kg"), ("ثابت الصلابة K", "1 — 16 N/m")]):
    sly = sim_y + 470 + i * 64
    d.rounded_rectangle([pl + 50, sly, pr - 50, sly + 12], radius=6, fill=CARD2)
    frac = 0.5 if i == 0 else 0.33
    d.rounded_rectangle([pl + 50, sly, pl + 50 + int((pr - pl - 100) * frac), sly + 12], radius=6, fill=_c4(BRAND))
    d.ellipse([pl + 50 + int((pr - pl - 100) * frac) - 12, sly - 12, pl + 50 + int((pr - pl - 100) * frac) + 12, sly + 24], fill=_c4(BRAND))
    draw_rtl(img, pr - 50, sly + 46, lbl, 17, TXT2, path=SANS)
    draw_ltr(img, pl + 50, sly + 46, val, 16, TXT2, path=DEJAVU)
by = sim_y + 620
cv.alpha_rect(pl + 30, by, pr - pl - 60, 74, (45, 212, 167, 200), radius=20)
d.polygon([(pl + (pr - pl) // 2 - 40, by + 26), (pl + (pr - pl) // 2 - 40, by + 48), (pl + (pr - pl) // 2 - 20, by + 37)], fill=_c4(DARKBTN))
draw_rtl(img, pr - 70, by + 48, "تشغيل", 22, DARKBTN, bold=True)

# ---------- S5: البطاقات (4) ----------
pl, pr = cv.phone(X2, SY2, PW, PH, "بطاقات المراجعة", SUB)
cards = [
    ([("النبض الخاص ", "ar"), ("ω₀", "la")], 225, [
        [("ω₀ = √(K/m) > 0 — ", "la"), ("محقق لأن m و K موجبان دوماً.", "ar")],
    ]),
    ([("الدور الخاص ", "ar"), ("T₀", "la")], 225, [
        [("T₀ = 2π·√(m/K) (s) — ", "la"), ("يعتمد على m و K فقط.", "ar")],
    ]),
    ([("متى لا يتغير ", "ar"), ("T₀", "la"), ("؟", "ar")], 225, [
        [("لا يتعلق بسعة الاهتزاز ", "ar"), ("Xmax", "la"), (" — ", "ar")],
        [("ولا يتعلق بـ g (لا يتعلق بالارتفاع).", "ar")],
    ]),
    ([("على ماذا يعتمد ", "ar"), ("T₀", "la"), ("؟", "ar")], 225, [
        [("طرديا مع ", "ar"), ("√m", "la"), (" — عكسيا مع ", "ar"), ("1/√K", "la")],
    ]),
]
by = SY2 + 100
for i, (front, ch, lines) in enumerate(cards):
    cv.card(pl, by, pr - pl, ch, 22, CARD, border=LINE)
    cv.number_badge(pl + 20, by + 20, i + 1, BRAND)
    cv.draw_flow(pr - 24, by + 50, front, 24, TXT, bold=True)
    d.line([(pl + 24, by + 78), (pr - 24, by + 78)], fill=_c4(LINE), width=2)
    yy = by + 122
    for segs in lines:
        cv.draw_flow(pr - 24, yy, segs, 20, TXT2)
        yy += 36
    by += ch + 20
draw_rtl(img, pr, SY2 + PH - 90, "4 بطاقات — المصطلح + التعريف", 18, TXT2, path=SANS)

# ---------- S6: المثال المحلول ----------
pl, pr = cv.phone(X1, SY2, PW, PH, "مثال محلول", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "من نوط الأستاذ", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.a_rounded(pl + 16, yy, pr - 16, yy + 116, 14, fill=CARD2, outline=LINE)
cv.draw_flow(cr, yy + 44, [("نواس مرن دوره الخاص ", "ar"), ("T₀ = 2 (s)", "la"), (" — نجعل كتلته", "ar")], 19, TXT)
cv.draw_flow(cr, yy + 84, [("ربع ما كانت عليه. دوره الخاص الجديد؟", "ar")], 19, TXT)
yy += 166
steps = [
    [("من الملاحظات: ", "ar"), ("T₀ ∝ √m", "la")],
    [("نعوض: ", "ar"), ("T₀' = 2 × √(1/4)", "la")],
    [("نحسب: ", "ar"), ("T₀' = 2 × 1/2 = 1", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 52
yy += 10
big = "T₀' = 1 (s)"
bw = text_width(big, DEJAVU_SI, 32) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 68, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 67], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 48, big, 32, BRAND, path=DEJAVU_SI, slant=0.22)

# ============================ الصف الثالث ============================
# ---------- S7: الاختبار الذاتي (4) ----------
pl, pr = cv.phone(X2, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("نواس مرن دوره الخاص ", "ar"), ("T₀", "la"), (" — نضاعف كتلة الجسم.", "ar")],
       [("دوره الخاص الجديد؟", "ar")] ],
     [[("√2·T₀", "la")], [("2·T₀", "la")], [("T₀/2", "la")], [("T₀", "la")]]),
    ([ [("نواس مرن دوره الخاص ", "ar"), ("T₀", "la"), (" — نجعل صلابة النابض", "ar")],
       [("ربع ما كان عليه. دوره الخاص الجديد؟", "ar")] ],
     [[("2·T₀", "la")], [("4·T₀", "la")], [("T₀/2", "la")], [("T₀/4", "la")]]),
    ([ [("نواس مرن دوره الخاص ", "ar"), ("T₀ = 2 (s)", "la"), (" — نجعل كتلته", "ar")],
       [("ربع ما كانت عليه. دوره الخاص الجديد؟", "ar")] ],
     [[("1 s", "la")], [("2 s", "la")], [("0.5 s", "la")], [("4 s", "la")]]),
    ([ [("نواس مرن نبضه ", "ar"), ("ω₀", "la"), (" — الكتلة نصفها والصلابة", "ar")],
       [("مثليها. نبضه الخاص الجديد؟", "ar")] ],
     [[("2·ω₀", "la")], [("4·ω₀", "la")], [("ω₀/2", "la")], [("ω₀/4", "la")]]),
]
by = SY3 + 96
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
cv.a_rounded(pr - 230, SY3 + PH - 104, pr - 24, SY3 + PH - 56, 24,
             fill=(45, 212, 167, 26), outline=(45, 212, 167, 120))
cv.refresh(pr - 130, SY3 + PH - 80, 14, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY3 + PH - 68, "سؤال جديد", 20, BRAND, bold=True)

# ============================ التسميات ============================
row1 = [
    ([("الشرح 1 — س3 + المعادلة", "ar")], X1),
    ([("الشرح 2 — المقارنة: ", "ar"), ("ω₀ = √(K/m)", "la")], X2),
    ([("الشرح 3 — الدور الخاص ", "ar"), ("T₀", "la")], X3),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [("التجربة + تنبؤ", X3), ("بطاقات المراجعة (4)", X2), ("المثال المحلول", X1)]
for txt, x in row2:
    w = text_width(txt, NASKH, 23, True)
    draw_rtl(img, x + PW // 2 + w // 2, SY2 + PH + 56, txt, 23, TXT, bold=True)
w = text_width("الاختبار الذاتي (4 قوالب)", NASKH, 23, True)
draw_rtl(img, X2 + PW // 2 + w // 2, SY3 + PH + 56, "الاختبار الذاتي (4 قوالب)", 23, TXT, bold=True)
cv.draw_flow(XR, SY3 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.3 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.3-review.png")
