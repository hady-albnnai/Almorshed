# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.12: مسألة (2/18) — الرسم Ep–x وقراءة الثوابت منه"""
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
cv.draw_flow(XR, 162, [("الوحدة 1.12", "ar"), (" — ", "la"), ("مسألة ", "ar"), ("(2/18):", "la"), (" الرسم ", "ar"), ("Ep–x", "la"), (" وقراءة الثوابت", "ar")], 48, TXT, bold=True)
pr = XR
for segs, tc, bc, bg in [
    ([("النص حرفي من النوط ", "ar"), ("+ ", "la"), ("تصحيحات ", "ar"), ("R1–R14", "la")], BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ([("فلاشات النوط: ", "ar"), ("F0091–F0092 ", "la"), ("رسم ", "ar"), ("Ep–x", "la")], TXT2, LINE, CARD),
    ([("3 خطوات ", "ar"), ("+ ", "la"), ("4 بطاقات ", "ar"), ("+ ", "la"), ("4 أسئلة", "ar")], TXT2, LINE, CARD),
]:
    tw = cv.flow_width(segs, 22, True)
    w = tw + 48
    cv.alpha_rect(pr - w, 214, w, 54, bg, radius=27)
    d.rounded_rectangle([pr - w, 214, pr - 1, 267], radius=27, outline=_c4(bc), width=2)
    cv.draw_flow(pr - 24, 214 + 39, segs, 22, tc, bold=True)
    pr -= w + 20

# ============================ الصف الأول ============================
SY, PW, PH = 330, 760, 1350
X1, X2, X3 = XR - PW, XR - 2 * PW - 30, XR - 3 * PW - 60
SY2 = 1860
SY3 = 3390
SUB = "الوحدة 1.12 · النواس المرن"

# ---------- S1: نص المسألة + رسم Ep–x ----------
pl, pr = cv.phone(X1, SY, PW, PH, "نواس المرن", SUB)
cr = pr - 24
segs_p = [("مسألة ", "ar"), ("(2/18)", "la")]
w_p = cv.flow_width(segs_p, 19, True) + 44
cv.alpha_rect(cr - w_p, SY + 100, w_p, 48, (45, 212, 167, 26), radius=24)
d.rounded_rectangle([cr - w_p, SY + 100, cr - 1, SY + 147], radius=24, outline=(45, 212, 167, 100), width=2)
cv.draw_flow(cr - 22, SY + 134, segs_p, 19, BRAND, bold=True)
cr = cr - w_p - 12
cv.pill_r(cr, SY + 100, "من الرسم", 19, TXT2, LINE, CARD2)
yy = SY + 196
cv.draw_flow(cr, yy, [("الموجو نابض أفقي بسيط صلابة ", "ar"), ("k", "la"), (" مربوط بجسم كتلته ", "ar")], 18, TXT); yy += 32
cv.draw_flow(cr, yy, [("m = 0,4 kg", "la"), ("— ", "la"), ("يوضّح الرسم تغيّر الطاقة الكامنة ", "ar"), ("Ep", "la"), (" بتغيّر الموضع ", "ar"), ("x:", "la")], 18, TXT); yy += 44
cv.draw_flow(cr, yy, [("المطلوب:  ", "ar"), ("1) k     2) T₀     3) v", "la"), (" عند مركز الاهتزاز", "ar")], 18, BRAND, bold=True); yy += 52
# إطار الرسم
gx0, gx1 = pl + 44, pr - 24
gy0, gy1 = yy, yy + 400
cv.a_rounded(gx0, gy0, gx1, gy1, 14, fill=(8, 14, 26), outline=(44, 63, 99))
ocx = (gx0 + gx1) // 2 - 10
yb = gy1 - 56
yE = gy0 + 46
hx = 168  # Xmax بالبكسل
# المحاور
d.line([(ocx, gy0 + 22), (ocx, yb)], fill=_c4(TXT2), width=3)                    # محور Ep
d.line([(ocx - 40, yb), (gx1 - 26, yb)], fill=_c4(TXT2), width=3)                # محور x
d.polygon([(ocx, gy0 + 14), (ocx - 7, gy0 + 28), (ocx + 7, gy0 + 28)], fill=_c4(TXT2))
d.polygon([(gx1 - 20, yb), (gx1 - 34, yb - 7), (gx1 - 34, yb + 7)], fill=_c4(TXT2))
draw_ltr(img, ocx - 96, gy0 + 34, "Ep(J)", 17, TXT2, path=DEJAVU)
draw_ltr(img, gx1 - 44, yb + 12, "x", 18, BRAND2, path=DEJAVU_SI, slant=0.22)
# القطع المكسور Ep = E*(x/Xmax)^2
pts = []
for i in range(121):
    xx = (i / 120.0 - 0.5) * 2 * hx
    yyv = yb - (yb - yE) * (xx / hx) ** 2
    pts.append((ocx + xx, yyv))
d.line(pts, fill=_c4(BRAND), width=5, joint="curve")
# الخط الأفقي E
d.line([(ocx - hx - 22, yE), (ocx + hx + 22, yE)], fill=_c4(GOLD), width=4)
draw_ltr(img, gx0 + 18, yE - 30, "E = 5×10⁻² J", 17, GOLD, path=DEJAVU)
# خطوط منقطة عند ±Xmax
for sgn in (-1, 1):
    tx = ocx + sgn * hx
    for k2 in range(int(yE), yb, 14):
        d.line([(tx, k2), (tx, min(k2 + 7, yb))], fill=_c4((90, 110, 140)), width=2)
    d.ellipse([tx - 6, yE - 6, tx + 6, yE + 6], fill=_c4(GOLD))
    lab = ("-10 cm" if sgn < 0 else "10 cm")
    lw = text_width(lab, DEJAVU, 15)
    draw_ltr(img, int(tx - lw // 2), yb + 16, lab, 15, TXT2, path=DEJAVU)
draw_ltr(img, ocx + hx // 2 + 26, (yE + yb) // 2 + 30, "Ep = ½kx²", 16, MATHC, path=DEJAVU_SI, slant=0.22)
yy = gy1 + 44
cv.draw_flow(cr, yy, [("الخط الأفقي ", "ar"), ("= ", "la"), ("الطاقة الكلية ", "ar"), ("(", "la"), ("ثابتة", "ar"), (")", "la"), (" · ", "la"), ("التقاطع ", "ar"), ("= ", "la"), ("±Xmax", "la"), (" حيث ", "ar"), ("Ep = E", "la"), (" و ", "ar"), ("Ek = 0", "la")], 17, TXT2)
yy += 44
cv.draw_flow(cr, yy, [("نقرأ من الرسم: ", "ar"), ("E = 5×10⁻² J", "la"), ("  و  ", "ar"), ("Xmax = 10⁻¹ m", "la")], 18, TXT, bold=True)
cv.bottom_bar(X1, SY + PH - 108, PW)

# ---------- S2: قراءة الرسم + 1) k ----------
pl, pr = cv.phone(X2, SY, PW, PH, "نواس المرن", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "قراءة الرسم", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "الخطوة 1", 19, TXT2, LINE, CARD2)
yy = SY + 190
# صندوق القراءة
bh = 268
cv.a_rounded(pl + 16, yy, pr - 16, yy + bh, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 16, "أ", BRAND2)
cv.draw_flow(cr - 46, yy + 40, [("قراءة الرسم ", "ar"), ("Ep–x", "la"), (":", "ar")], 18, TXT, bold=True)
reads = [
    [("الخط الأفقي: الطاقة الكلية ", "ar"), ("E", "la"), (" ثابتة طول النواس", "ar")],
    [("القطع المكسور: ", "ar"), ("Ep = ½kx²", "la")],
    [("التقاطع عند ", "ar"), ("x = ±10 cm", "la"), (" — ", "la"), ("حيث ", "ar"), ("Ep = E", "la"), (" و ", "ar"), ("Ek = 0", "la")],
]
yyr = yy + 84
for segs in reads:
    cv.draw_flow(cr - 24, yyr, segs, 17, TXT2)
    yyr += 44
    if segs is reads[1]:
        pass
yy += bh + 40
# المطلوب 1
cv.a_rounded(pl + 16, yy, pr - 16, yy + 300, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 16, "1", BRAND)
cv.draw_flow(cr - 46, yy + 40, [("قيمة ثابت الصلابة ", "ar"), ("k", "la"), (":", "ar")], 18, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 84, [("عند المطال الأعظمي:  ", "ar"), ("E = Ep = ½kX²max", "la")], 18, TXT)
cv.draw_flow(cr - 24, yy + 126, [("إذن:  ", "ar"), ("k = 2E/X²max", "la")], 18, TXT)
cv.draw_flow(cr - 24, yy + 172, [("نعوّض:  ", "ar"), ("k = (2×5×10⁻²)/(10⁻²)", "la")], 18, TXT)
yy += 326
big = "k = 10 N/m"
bw = text_width(big, DEJAVU_SI, 32) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 66, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 65], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 46, big, 32, BRAND, path=DEJAVU_SI, slant=0.22)
cv.bottom_bar(X2, SY + PH - 108, PW)

# ---------- S3: 2) T₀ + 3) v عند المركز ----------
pl, pr = cv.phone(X3, SY, PW, PH, "نواس المرن", SUB)
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "الدور والسرعة", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "الخطوتان 2 و 3", 19, TXT2, LINE, CARD2)
yy = SY + 190
# المطلوب 2
cv.a_rounded(pl + 16, yy, pr - 16, yy + 214, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 16, "2", BRAND)
cv.draw_flow(cr - 46, yy + 40, [("الدور ", "ar"), ("T₀", "la"), (":", "ar")], 18, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 84, [("T₀ = 2π√(m/k) = 2π√((4×10⁻¹)/10)", "la")], 18, TXT)
cv.draw_flow(cr - 24, yy + 128, [("= 2π√(4×10⁻²) = 4π×10⁻¹ ≈ 1,25 s", "la")], 18, TXT)
yy += 240
# المطلوب 3
cv.a_rounded(pl + 16, yy, pr - 16, yy + 330, 12, fill=CARD2, outline=LINE)
cv.number_badge(cr - 30, yy + 16, "3", BRAND)
cv.draw_flow(cr - 46, yy + 40, [("v", "la"), (" عند مركز الاهتزاز:", "ar")], 18, TXT, bold=True)
cv.draw_flow(cr - 24, yy + 84, [("x = 0  ⟹  Ep = 0  ⟹  Ek ", "la"), ("أعظمى", "ar")], 18, TXT)
cv.draw_flow(cr - 24, yy + 126, [("إذن ", "ar"), ("v", "la"), (" أعظمى:  ", "ar"), ("vmax = ω₀Xmax", "la")], 18, TXT)
cv.draw_flow(cr - 24, yy + 170, [("(= (2π/T₀)·Xmax)", "la")], 18, TXT2)
cv.draw_flow(cr - 24, yy + 214, [("= (2π/(4π×10⁻¹))×10⁻¹", "la")], 18, TXT)
yy += 356
big = "v = ∓0,5 m/s"
bw = text_width(big, DEJAVU_SI, 30) + 64
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy, bw, 64, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy, pxc + bw // 2 - 1, yy + 63], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, pxc - bw // 2 + 32, yy + 44, big, 30, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 82
cv.draw_flow(cr, yy, [("الإشارة ", "ar"), ("±", "la"), (" حسب جهة مرور الجسم", "ar")], 16, TXT2)

# ============================ الصف الثاني: البطاقات (4) ============================
pl, pr = cv.phone(X2, SY2, PW, PH, "بطاقات المراجعة", SUB)
cards = [
    ([("قراءة رسم ", "ar"), ("Ep–x", "la")], 292, [
        [("الخط الأفقي ", "ar"), ("= ", "la"), ("E ", "la"), ("(", "la"), ("ثابتة", "ar"), (")", "la"), (" · ", "la"), ("القطع المكسور ", "ar"), ("= ", "la"), ("Ep = ½kx²", "la")],
        [("التقاطع عند ", "ar"), ("x = ±Xmax", "la"), (": حيث ", "ar"), ("Ep = E", "la"), (" و ", "ar"), ("Ek = 0", "la")],
    ]),
    ([("الصلابة من الرسم", "ar")], 236, [
        [("عند المطال الأعظمي:  ", "ar"), ("E = ½kX²max", "la")],
        [("إذن:  ", "ar"), ("k = 2E/X²max", "la")],
    ]),
    ([("الدور من ", "ar"), ("m", "la"), (" و ", "ar"), ("k", "la")], 236, [
        [("T₀ = 2π√(m/k)", "la")],
        [("يُحسب بعد استنتاج ", "ar"), ("k", "la"), (" من الرسم.", "ar")],
    ]),
    ([("السرعة عند مركز الاهتزاز", "ar")], 292, [
        [("x = 0 ⟹ Ep = 0 ⟹ Ek ", "la"), ("أعظمى", "ar")],
        [("vmax = ω₀Xmax = (2π/T₀)·Xmax", "la")],
    ]),
]
by = SY2 + 100
for i, (front, ch, lines) in enumerate(cards):
    cv.card(pl, by, pr - pl, ch, 22, CARD, border=LINE)
    cv.number_badge(pl + 20, by + 20, i + 1, BRAND)
    cv.draw_flow(pr - 24, by + 50, front, 24, TXT, bold=True)
    d.line([(pl + 24, by + 78), (pr - 24, by + 78)], fill=_c4(LINE), width=2)
    yy = by + 134
    for segs in lines:
        cv.draw_flow(pr - 24, yy, segs, 20, TXT2)
        yy += 44
    by += ch + 18

# ============================ الصف الثالث: الاختبار الذاتي (4) ============================
pl, pr = cv.phone(X2, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([ [("في رسم ", "ar"), ("Ep–x —", "la"), (" الخط الأفقي يمثل:", "ar")] ],
     [[("الطاقة الكلية ", "ar"), ("E (", "la"), ("ثابتة طول النواس", "ar"), (")", "la")],
      [("الطاقة الكامنة فقط", "ar")],
      [("الطاقة الحركية فقط", "ar")],
      [("ثابت الصلابة ", "ar"), ("k", "la")]]),
    ([ [("تُقرأ السعة ", "ar"), ("Xmax", "la"), (" من الرسم عند:", "ar")] ],
     [[("قيمة ", "ar"), ("x", "la"), (" حيث تصل ", "ar"), ("Ep", "la"), (" إلى ", "ar"), ("E", "la")],
      [("قيمة ", "ar"), ("x", "la"), (" حيث ", "ar"), ("Ep = 0", "la")],
      [("نصف قيمة ", "ar"), ("E", "la")],
      [("نهاية محور الزمن", "ar")]]),
    ([ [("عندما ", "ar"), ("E = 5×10⁻² J", "la"), (" و ", "ar"), ("Xmax = 10⁻¹ m", "la"), (" تكون ", "ar"), ("k:", "la")] ],
     [[("10 N/m", "la")], [("5 N/m", "la")], [("20 N/m", "la")], [("100 N/m", "la")]]),
    ([ [("عند المرور في مركز الاهتزاز:", "ar")] ],
     [[("Ep = 0  ⟹  ", "la"), ("Ek ", "la"), ("أعظمى", "ar"), ("  ⟹  ", "la"), ("v ", "la"), ("أعظمى", "ar")],
      [("Ep ", "la"), ("أعظمى و", "ar"), ("Ek = 0", "la")],
      [("v = 0", "la")],
      [("Ep = Ek", "la"), (" في كل الموضع", "ar")]]),
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
    ([("نص المسألة ", "ar"), ("+ ", "la"), ("رسم ", "ar"), ("Ep–x", "la")], X1),
    ([("قراءة الرسم و ", "ar"), ("k", "la")], X2),
    ([("T₀ + v", "la"), (" عند المركز", "ar")], X3),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
segs = [("بطاقات المراجعة ", "ar"), ("(4)", "la")]
w = cv.flow_width(segs, 23, True)
cv.draw_flow(X2 + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
segs = [("الاختبار الذاتي ", "ar"), ("(4", "la"), (" قوالب", "ar"), (")", "la")]
w = cv.flow_width(segs, 23, True)
cv.draw_flow(X2 + PW // 2 + w // 2, SY3 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY3 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني", "ar"), (" · ", "la"), ("الوحدة 1.12 من 73", "ar"), (" · ", "la"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.12-review.png")
