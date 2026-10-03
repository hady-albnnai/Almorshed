# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.9: طرق حل مسألة النواس المرن (تابع المطال بالشكل العام)"""
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
cv.draw_flow(XR, 162, [("الوحدة 1.9 — ", "ar"), ("طرق حل مسألة النواس المرن", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("وصفة: الشكل العام + الثوابت + الاستطالة السكونية", TXT2, LINE, CARD),
    ("وصفات الحل + مسألة + 4 أسئلة", TXT2, LINE, CARD),
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
SUB = "الوحدة 1.9 · النواس المرن"

def case_box(pl, pr, cr, yy, title_segs, h, fill=CARD2):
    cv.a_rounded(pl + 16, yy, pr - 16, yy + h, 12, fill=fill, outline=LINE)
    return yy

# ---------- S1: الشكل العام + Xmax + ω₀ ----------
pl, pr = cv.phone(XR1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "الشكل العام + السعة + النبض", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وصفة 1", 19, TXT2, LINE, CARD2)
yy = SY + 180
cv.draw_flow(cr, yy, [("1) التابع الزمني للمطال بالشكل العام:", "ar")], 19, TXT, bold=True)
yy += 44
big = "x = Xmax·cos(ω₀t + φ)"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 65], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 46, big, 30, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 92
cv.draw_flow(cr, yy, [("نوجد الثوابت ونعوض في التابع:", "ar")], 18, TXT2)
yy += 40
cv.draw_flow(cr, yy, [("سعة الاهتزاز ", "ar"), ("Xmax (m)", "la"), (": سعة الحركة — المطال الأعظمي", "ar")], 18, BRAND, bold=True)
yy += 40
for segs in [
    [("نشد الجسم مسافة ", "ar"), ("d", "la"), (" ونتركه دون سرعة ابتدائية: ", "ar"), ("Xmax = d", "la")],
    [("جسم يرسم قطعة مستقيمة طولها ", "ar"), ("d", "la"), (": ", "la"), ("Xmax = d/2", "la")],
    [("في مركز الاهتزاز ", "ar"), ("v = vmax", "la"), (": ", "la"), ("Xmax = vmax/ω₀", "la")],
    [("عندما ", "ar"), ("Ek = E", "la"), (": ", "la"), ("Xmax = √(2E/k)", "la")],
]:
    d.ellipse([cr - 10, yy - 14, cr - 2, yy - 6], fill=_c4(BRAND2))
    cv.draw_flow(cr - 24, yy, segs, 17, TXT2)
    yy += 34
yy += 16
cv.draw_flow(cr, yy, [("النبض الخاص ", "ar"), ("ω₀ (rad/s)", "la"), (": ", "la"), ("ω₀ = 2π/T₀", "la"), (" أو ", "ar"), ("ω₀ = √(k/m)", "la")], 18, BRAND, bold=True)

# ---------- S2: الطور الابتدائي φ ----------
pl, pr = cv.phone(XL1, SY, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY + 100, "حالات الطور الابتدائي", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY + 176
cv.draw_flow(cr, yy, [("نعوض شروط البدء في التابع (", "ar"), ("t = 0", "la"), ("):", "la")], 18, TXT, bold=True)
yy += 44
# حالة 1
cv.a_rounded(pl + 16, yy, pr - 16, yy + 92, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "1", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("الجسم في المطال الأعظمي الموجب:", "ar")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 72, [("x = Xmax ⟹ cos φ = 1 ⟹ φ = 0 rad", "la")], 17, MATHC)
yy += 108
# حالة 2
cv.a_rounded(pl + 16, yy, pr - 16, yy + 92, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "2", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("الجسم في المطال الأعظمي السالب:", "ar")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 72, [("x = −Xmax ⟹ cos φ = −1 ⟹ φ = π rad", "la")], 17, MATHC)
yy += 108
# حالة 3
cv.a_rounded(pl + 16, yy, pr - 16, yy + 150, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "3", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("الجسم في مركز الاهتزاز: ", "ar"), ("cos φ = 0 ⟹ φ = π/2", "la"), (" أو ", "ar"), ("−π/2", "la")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 72, [("نناقش في تابع السرعة: ", "ar"), ("v = −ω₀Xmax·sin(φ)", "la")], 16, TXT2)
cv.draw_flow(cr - 24, yy + 102, [("يتحرك سالبا: ", "ar"), ("v < 0 ⟹ φ = π/2", "la")], 16, TXT2)
cv.draw_flow(cr - 24, yy + 130, [("يتحرك موجبا: ", "ar"), ("v > 0 ⟹ φ = −π/2", "la")], 16, TXT2)
yy += 166
# حالة 4
cv.a_rounded(pl + 16, yy, pr - 16, yy + 92, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 14, "4", BRAND2)
cv.draw_flow(cr - 46, yy + 34, [("الجسم في نقطة مطالها ", "ar"), ("Xmax/2", "la"), (":", "la")], 17, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 72, [("cos φ = 1/2 ⟹ φ = π/3", "la"), (" أو ", "ar"), ("−π/3", "la"), (" — نناقش في ", "ar"), ("v", "la")], 17, MATHC)

# ============================ الصف الثاني ============================
# ---------- S3: الاستطالة السكونية + الدور الخاص ----------
pl, pr = cv.phone(XR1, SY2, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY2 + 100, "الاستطالة السكونية + الدور الخاص", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY2 + 100, "وصفتا 2 و 3", 19, TXT2, LINE, CARD2)
yy = SY2 + 180
cv.draw_flow(cr, yy, [("2) الاستطالة السكونية ", "ar"), ("x₀ (m)", "la"), (" — حالة السكون:", "ar")], 19, TXT, bold=True)
yy += 44
steps = [
    [("الجسم: ثقله ", "ar"), ("ω", "la"), (" وتوتر النابض بالسكون ", "ar"), ("Fs0", "la"), (": ", "la"), ("ΣF = 0", "la")],
    [("بالاسقاط على محور شاقولي للأسفل: ", "ar"), ("ω − Fs0 = 0 ⟹ ω = Fs0", "la")],
    [("النابض: قوة الشد ", "ar"), ("Fs0′ = kx₀", "la"), (" ⟹ ", "la"), ("ω = kx₀", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 18, TXT)
    yy += 52
big2 = "x₀ = ω/k = mg/k = g/ω₀²"
bw2 = text_width(big2, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw2 // 2, yy + 6, bw2, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw2 // 2, yy + 6, pxc + bw2 // 2 - 1, yy + 71], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - bw2 // 2 + 32, yy + 48, big2, 30, MATHC, path=DEJAVU_SI, slant=0.22)
yy += 118
cv.draw_flow(cr, yy, [("3) الدور الخاص ", "ar"), ("T₀ (s)", "la"), (":", "la")], 19, TXT, bold=True)
yy += 44
cv.draw_flow(cr, yy, [("T₀ = 2π/ω₀", "la"), (" أو ", "ar"), ("T₀ = 2π√(m/k)", "la"), (" أو ", "ar"), ("T₀ = t/n", "la")], 18, TXT)
yy += 38
cv.draw_flow(cr, yy, [("حيث ", "ar"), ("t/n", "la"), (" = زمن الهزات/عدد الهزات", "ar")], 16, TXT2)
yy += 36
cv.draw_flow(cr, yy, [("ومن ", "ar"), ("x₀ = mg/k", "la"), (": ", "la"), ("T₀ = 2π√(x₀/g)", "la")], 18, BRAND, bold=True)

# ---------- S4: الكتلة والنابض + الطاقات ----------
pl, pr = cv.phone(XL1, SY2, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cv.pill_r(cr, SY2 + 100, "الكتلة والنابض + الطاقات", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
yy = SY2 + 180
cv.draw_flow(cr, yy, [("4) الكتلة ", "ar"), ("m (kg)", "la"), (" وثابت صلابة النابض ", "ar"), ("k (N/m)", "la"), (":", "la")], 18, TXT, bold=True)
yy += 42
cv.draw_flow(cr, yy, [("من ", "ar"), ("ω₀² = k/m", "la"), (" و ", "ar"), ("T₀ = 2π√(m/k)", "la"), (" و ", "ar"), ("x₀ = mg/k", "la")], 18, TXT)
yy += 36
cv.draw_flow(cr, yy, [("و ", "ar"), ("k", "la"), (" أيضاً من ", "ar"), ("E = ½kX²max", "la")], 18, TXT)
yy += 56
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 46
cv.draw_flow(cr, yy, [("5) الطاقات ", "ar"), ("E (J)", "la"), (":", "la")], 19, TXT, bold=True)
yy += 44
cv.draw_flow(cr, yy, [("عند ", "ar"), ("x", "la"), (" معلومة:", "ar")], 18, BRAND, bold=True)
yy += 36
cv.draw_flow(cr, yy, [("Ep = ½kx²", "la"), ("  ←  ", "la"), ("E = ½kX²max", "la"), ("  ←  ", "la"), ("Ek = E − Ep", "la")], 17, TXT)
yy += 32
cv.draw_flow(cr, yy, [("Ek = ½k[X²max − x²]", "la")], 17, TXT2)
yy += 52
cv.draw_flow(cr, yy, [("عند ", "ar"), ("v", "la"), (" معلومة:", "ar")], 18, BRAND, bold=True)
yy += 36
cv.draw_flow(cr, yy, [("Ek = ½mv²", "la"), ("  ←  ", "la"), ("E = ½kX²max", "la"), ("  ←  ", "la"), ("Ep = E − Ek", "la")], 17, TXT)

# ============================ الصف الثالث ============================
# ---------- S5: الموضع وجهة الحركة + مسألة ----------
pl, pr = cv.phone(XR1, SY3, PW, PH, "الاهتزازات التوافقية البسيطة", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY3 + 100, "الموضع وجهة الحركة", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY3 + 100, "وصفة 6", 19, TXT2, LINE, CARD2)
yy = SY3 + 180
cv.draw_flow(cr, yy, [("6) موضع وجهة الحركة في لحظة ما (عند ", "ar"), ("t", "la"), (" معلومة):", "ar")], 18, TXT, bold=True)
yy += 44
cv.draw_flow(cr, yy, [("الموضع: ", "ar"), ("x = Xmax·cos(ω₀t + φ)", "la")], 18, TXT)
yy += 40
cv.draw_flow(cr, yy, [("الجهة: ", "ar"), ("v = −ω₀Xmax·sin(ω₀t + φ)", "la")], 18, TXT)
yy += 40
cv.draw_flow(cr, yy, [("v < 0", "la"), (" يتحرك بالاتجاه السالب · ", "ar"), ("v > 0", "la"), (" يتحرك بالاتجاه الموجب", "ar")], 17, TXT2)
yy += 36
cv.draw_flow(cr, yy, [("عند بدء الزمن: ", "ar"), ("t = 0", "la")], 17, TXT2)
yy += 56
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 44
cv.draw_flow(cr, yy, [("مسألة: مبدأ الزمن كان الجسم في مركز الاهتزاز متجهاً بالاتجاه الموجب — حدد ", "ar"), ("φ", "la")], 18, BRAND, bold=True)
yy += 46
steps = [
    [("في المركز: ", "ar"), ("x = 0 = Xmax·cos(φ)", "la")],
    [("cos(φ) = 0 ⟹ φ = π/2 أو −π/2", "la")],
    [("الجهة الموجبة: ", "ar"), ("v > 0 ⟹ sin(φ) < 0", "la")],
]
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 24, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 17, TXT)
    yy += 46
ans = "φ = −π/2"
bw3 = text_width(ans, DEJAVU_SI, 26) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw3 // 2, yy + 6, bw3, 60, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw3 // 2, yy + 6, pxc + bw3 // 2 - 1, yy + 65], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw3 // 2 + 32, yy + 44, ans, 26, BRAND, path=DEJAVU_SI, slant=0.22)

# ---------- S6: الأسئلة ----------
pcx = XL1
pl, pr = cv.phone(pcx, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("نشُد الجسم مسافة ", "ar"), ("d", "la"), (" ونتركه دون سرعة ابتدائية — السعة ", "ar"), ("Xmax", "la"), (":", "la")] ],
     [[("Xmax = d", "la")], [("Xmax = d/2", "la")], [("Xmax = 2d", "la")], [("Xmax = d/ω₀", "la")]]),
    ([ [("جسم يرسم قطعة مستقيمة طولها ", "ar"), ("d", "la"), (" — السعة ", "ar"), ("Xmax", "la"), (":", "la")] ],
     [[("Xmax = d/2", "la")], [("Xmax = d", "la")], [("Xmax = 2d", "la")], [("Xmax = d/π", "la")]]),
    ([ [("مبدأ الزمن كان الجسم في مركز الاهتزاز متجهاً بالاتجاه السالب — الطور الابتدائي ", "ar"), ("φ", "la"), (":", "la")] ],
     [[("φ = π/2", "la")], [("φ = −π/2", "la")], [("φ = 0", "la")], [("φ = π", "la")]]),
    ([ [("هزازة رأسية كتلتها ", "ar"), ("m = 200 g", "la"), (" وثابت صلابة نابضها ", "ar"), ("k = 20 N/m", "la")],
       [("الاستطالة السكونية ", "ar"), ("x₀ = mg/k", "la"), (" بالسنتيمتر؟", "ar")] ],
     [[("1 cm", "la")], [("0.5 cm", "la")], [("2 cm", "la")], [("4 cm", "la")]]),
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
    ([( "الشكل العام + السعة + النبض الخاص", "ar")], XR1),
    ([( "حالات الطور الابتدائي (4)", "ar")], XL1),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([( "الاستطالة السكونية + الدور الخاص", "ar")], XR1),
    ([( "الكتلة والنابض + الطاقات", "ar")], XL1),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
row3 = [
    ([( "الموضع وجهة الحركة + مسألة الطور", "ar")], XR1),
    ([( "الاختبار الذاتي (4 قوالب)", "ar")], XL1),
]
for segs, x in row3:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY3 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY3 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.9 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.9-review.png")
