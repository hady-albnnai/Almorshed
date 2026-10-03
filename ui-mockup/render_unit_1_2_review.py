# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.2: قوة الارجاع (شرح ×2 + تجربة + بطاقات + أسئلة)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
cv = ReviewCanvas(W, 3320)
d = cv.d
img = cv.img
XR = 2400

def stem_flow(x_right, y, segs, size, fill):
    """سؤال/سطر مختلط: أسطر يدوية"""
    yy = y
    for line in segs:
        cv.draw_flow(x_right, yy, line, size, fill)
        yy += size + 10
    return yy

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.2 — ", "ar"), ("قوة الارجاع", "ar")], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("الشكل F0002 من أصول النوط", TXT2, LINE, CARD),
    ("وحدة ثقيلة: شرح + تجربة + 4 بطاقات + 4 أسئلة", TXT2, LINE, CARD),
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

# ---------- S1: الشرح ① (س1 + الشكل) ----------
pl, pr = cv.phone(X1, SY, PW, PH, "الاهتزازات التوافقية البسيطة")
cr = pr - 24
cr = cv.pill_r(cr, SY + 100, "قوة الارجاع", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
cv.pill_r(cr, SY + 100, "وحدة ٢", 19, TXT2, LINE, CARD2)
draw_rtl(img, cr, SY + 192, "س1) في النواس المرن الغير متخامد، أثبت أن محصلة القوى الخارجية المؤثرة", 19, TXT)
draw_rtl(img, cr, SY + 226, "في مركز عطالة الجسم هي قوة ارجاع تعيد الجسم إلى مركز الاهتزاز", 19, BRAND, bold=True)
fig = Image.open("/home/user/Almorshed/rebuild/nawwasat/assets/images/image2.png").convert("RGB")
fw = 620
fh = int(fig.height * fw / fig.width)
fig = fig.resize((fw, fh), Image.LANCZOS)
fx = (X1 + PW // 2 - fw // 2, SY + 252)
mask = Image.new("L", (fw, fh), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, fw - 1, fh - 1], radius=18, fill=255)
img.paste(fig, fx, mask)
d.rounded_rectangle([fx[0], fx[1], fx[0] + fw - 1, fx[1] + fh - 1], radius=18, outline=_c4(LINE), width=2)
yy = fx[1] + fh + 44
cap_segs = [("أثبت أن قوة الارجاع تعطى بالعلاقة", "ar")]
cv.draw_flow((pl + pr) // 2 + cv.flow_width(cap_segs, 19) // 2, yy, cap_segs, 19, TXT)
math_txt = "F = -kx"
mw = text_width(math_txt, DEJAVU_SI, 34)
bw = mw + 60
pxc = (pl + pr) // 2
cv.alpha_rect(pxc - bw // 2, yy + 24, bw, 66, (56, 189, 248, 22), radius=14)
d.rounded_rectangle([pxc - bw // 2, yy + 24, pxc + bw // 2 - 1, yy + 89], radius=14, outline=(56, 189, 248, 90), width=2)
draw_ltr(img, pxc - mw // 2, yy + 72, math_txt, 34, MATHC, path=DEJAVU_SI, slant=0.22)
cv.bottom_bar(X1, SY + PH - 108, PW)

# ---------- S2: الشرح ② (البرهان + الخواص + س2) ----------
pl, pr = cv.phone(X2, SY, PW, PH, "الاهتزازات التوافقية البسيطة")
cr = pr - 24
cv.pill_r(cr, SY + 100, "البرهان — متل ما بالنوط", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26))
steps = [
    [("سكون:  ", "ar"), ("ω = Fs0 = k·x0", "la")],
    [("حركة:  ", "ar"), ("ω + Fs = m·a", "la")],
    [("وتوتر النابض:  ", "ar"), ("Fs = k(x + x0)", "la")],
    [("نعوض:  ", "ar"), ("k·x0 − k(x + x0) = m·a", "la")],
]
yy = SY + 170
for i, segs in enumerate(steps):
    cv.number_badge(cr - 36, yy - 26, i + 1, BRAND)
    cv.draw_flow(cr - 52, yy, segs, 19, TXT)
    yy += 46
bw = text_width("F = -kx", DEJAVU_SI, 30) + 60
cv.alpha_rect(cr - bw, yy + 6, bw, 60, (45, 212, 167, 30), radius=14)
d.rounded_rectangle([cr - bw, yy + 6, cr - 1, yy + 65], radius=14, outline=(45, 212, 167, 140), width=2)
draw_ltr(img, cr - bw + 30, yy + 48, "F = -kx", 30, BRAND, path=DEJAVU_SI, slant=0.22)
yy += 104
d.line([(pl, yy), (pr, yy)], fill=_c4(LINE), width=2)
yy += 40
cv.draw_flow(cr, yy, [("• تتناسب طرداً مع المطال وتعاكسه بالإشارة", "ar")], 18, TXT2); yy += 34
cv.draw_flow(cr, yy, [("• تعيد الجسم إلى مركز الاهتزاز — تتجه دوماً نحو المركز", "ar")], 18, TXT2); yy += 56
cv.pill_r(cr, yy, "س2) متى تكون عظمى ومتى تنعدم؟", 19, BRAND2, (56, 189, 248, 100), (56, 189, 248, 16))
yy += 58
cv.number_badge(cr - 36, yy - 26, "a", BRAND2)
cv.draw_flow(cr - 52, yy, [("عظمى في المطالين الأعظميين:  ", "ar"), ("Fmax = k·Xmax  (x = ±Xmax)", "la")], 18, TXT); yy += 46
cv.number_badge(cr - 36, yy - 26, "b", BRAND2)
cv.draw_flow(cr - 52, yy, [("معدومة في مركز الاهتزاز:  ", "ar"), ("F = 0  (x = 0)", "la")], 18, TXT)

# ---------- S3: التجربة ----------
pl, pr = cv.phone(X3, SY, PW, PH, "التجربة")
cx = (pl + pr) // 2
cv.a_rounded(pl, SY + 96, pr, SY + 160, 16, fill=(56, 189, 248, 20), outline=(56, 189, 248, 90))
pred = "تنبأ: إذا ضاعفنا المطال، قوة الارجاع؟"
draw_rtl(img, pr - 18, SY + 136, pred, 17, BRAND2, bold=True)
choices = ["لا تتغير", "تنقص للنصف", "تتضاعف"]
chw, chx = 148, pl + 12
for i, c in enumerate(choices):
    x1 = chx + i * (chw + 10)
    d.rounded_rectangle([x1, SY + 106, x1 + chw, SY + 150], radius=13, fill=CARD + (255,), outline=_c4(LINE), width=2)
    lw_ = text_width(c, NASKH, 17, True)
    draw_rtl(img, x1 + chw // 2 + lw_ // 2, SY + 139, c, 17, TXT2, bold=True)
sim_y = SY + 186
cv.card(pl + 16, sim_y, pr - pl - 32, 430, 18, (8, 14, 26), border=(44, 63, 99))
cv.ceiling(cx - 120, sim_y + 40, 240, (90, 110, 140))
cv.spring(cx, sim_y + 40, sim_y + 240, 7, 44, (150, 170, 200))
d.ellipse([cx - 40, sim_y + 240, cx + 40, sim_y + 320], fill=_c4(GOLD))
d.line([(cx + 100, sim_y + 56), (cx + 100, sim_y + 240)], fill=_c4(BRAND2), width=4)
d.polygon([(cx + 100, sim_y + 48), (cx + 92, sim_y + 68), (cx + 108, sim_y + 68)], fill=_c4(BRAND2))
d.polygon([(cx + 100, sim_y + 248), (cx + 92, sim_y + 228), (cx + 108, sim_y + 228)], fill=_c4(BRAND2))
draw_ltr(img, cx + 116, sim_y + 140, "x", 26, BRAND2, slant=0.22, path=DEJAVU_SI)
d.line([(cx - 100, sim_y + 250), (cx - 100, sim_y + 120)], fill=_c4(BRAND), width=5)
d.polygon([(cx - 100, sim_y + 110), (cx - 108, sim_y + 132), (cx - 92, sim_y + 132)], fill=_c4(BRAND))
draw_ltr(img, cx - 142, sim_y + 180, "F", 26, BRAND, slant=0.22, path=DEJAVU_SI)
cv.alpha_rect(cx - 135, sim_y + 350, 270, 48, CARD + (255,), radius=12)
d.rounded_rectangle([cx - 135, sim_y + 350, cx + 135, sim_y + 397], radius=12, outline=_c4(LINE), width=2)
draw_ltr(img, cx - 112, sim_y + 384, "x = 0.15 m   F = 1.5 N", 20, MATHC, path=DEJAVU_B)
sy = SY + 650
d.rounded_rectangle([pl + 50, sy, pr - 50, sy + 12], radius=6, fill=CARD2)
d.rounded_rectangle([pl + 50, sy, pl + 250, sy + 12], radius=6, fill=_c4(BRAND))
d.ellipse([pl + 232, sy - 12, pl + 268, sy + 24], fill=_c4(BRAND))
draw_rtl(img, pr - 50, sy + 46, "المطال", 19, TXT2)
draw_ltr(img, pl + 130, sy + 44, "x", 24, MATHC, slant=0.22, path=DEJAVU_SI)
grad = Image.new("RGB", (1, 80))
for yyy in range(80):
    t = yyy / 79
    grad.putpixel((0, yyy), (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t)))
grad = grad.resize((pr - pl - 100, 80))
m = Image.new("L", (pr - pl - 100, 80), 0)
ImageDraw.Draw(m).rounded_rectangle([0, 0, pr - pl - 101, 79], radius=20, fill=255)
img.paste(grad, (pl + 50, SY + 750), m)
d.polygon([(cx - 30, SY + 772), (cx - 30, SY + 792), (cx - 12, SY + 782)], fill=_c4(DARKBTN))
draw_rtl(img, cx + 60, SY + 796, "تشغيل", 25, DARKBTN, bold=True)

# ============================ الصف الثاني ============================
SY2, PW2, PH2 = 1860, 760, 1350
X4 = XR - PW2
X5 = XR - 2 * PW2 - 30

# ---------- S4: البطاقات (4) ----------
pl, pr = cv.phone(X4, SY2, PW2, PH2, "بطاقات المراجعة")
cards = [
    ("قوة الارجاع", 225, [
        [("القوة التي تعيد الجسم إلى مركز الاهتزاز —", "ar")],
        [("تعطى بالعلاقة ", "ar"), ("F = -kx", "la"), (".", "ar")],
    ]),
    ("طبيعة قوة الارجاع", 225, [
        [("تتناسب طردياً مع المطال وتعاكسه بالإشارة —", "ar")],
        [("تتجه دوماً إلى مركز الاهتزاز.", "ar")],
    ]),
    ("متى تكون عظمى؟", 225, [
        [("في المطالين الأعظميين ", "ar"), ("(x = ±Xmax)", "la"), (" :", "ar")],
        [("Fmax = k·Xmax", "la")],
    ]),
    ("متى تنعدم؟", 225, [
        [("في مركز الاهتزاز:  ", "ar"), ("F = 0  (x = 0)", "la")],
    ]),
]
by = SY2 + 100
for i, (front, ch, lines) in enumerate(cards):
    cv.card(pl, by, pr - pl, ch, 22, CARD, border=LINE)
    cv.number_badge(pl + 20, by + 20, i + 1, BRAND)
    draw_rtl(img, pr - 24, by + 50, front, 24, TXT, bold=True)
    d.line([(pl + 24, by + 78), (pr - 24, by + 78)], fill=_c4(LINE), width=2)
    yy = by + 122
    for segs in lines:
        cv.draw_flow(pr - 24, yy, segs, 20, TXT2)
        yy += 36
    by += ch + 20
draw_rtl(img, pr, SY2 + PH2 - 90, "4 بطاقات — المصطلح + التعريف", 18, TXT2, path=SANS)

# ---------- S5: الأسئلة (4) ----------
pl, pr = cv.phone(X5, SY2, PW2, PH2, "الاختبار الذاتي")
qs = [
    ([[("نابض ثابت صلابته ", "ar"), ("k = 10 N/m", "la"), (" استطال المطال ", "ar"), ("x = 0.2 m", "la")],
      [("وكم مقدار قوة الارجاع؟", "ar")]],
     [[("2 N", "la")], [("0.02 N", "la")], [("50 N", "la")], [("20 N", "la")]]),
    ([ [("متى تكون قوة الارجاع عظمى؟", "ar")] ],
     [[("في المطالين الأعظميين ", "ar"), ("(x = ±Xmax)", "la")], [("في مركز الاهتزاز", "ar")],
      [("ثابتة طوال الاهتزاز", "ar")], [("عندما تكون السرعة عظمى", "ar")]]),
    ([ [("أين تنعدم قوة الارجاع؟", "ar")] ],
     [[("في مركز الاهتزاز ", "ar"), ("(x = 0)", "la")], [("في المطالين الأعظميين", "ar")],
      [("بعد ربع دور دائماً", "ar")], [("في كل المواضع", "ar")]]),
    ([ [("الجسم يمين مركز الاهتزاز ", "ar"), ("(x > 0)", "la")],
      [("— إلى أين تتجه قوة الارجاع؟", "ar")] ],
     [[("تتجه يساراً (نحو المركز)", "ar")], [("تتجه يميناً (مع المطال)", "ar")],
      [("معدومة", "ar")], [("عمودية على الحركة", "ar")]]),
]
by = SY2 + 96
letters = ["أ", "ب", "ج", "د"]
for qi, (stem_lines, opts) in enumerate(qs):
    qh = 290 if len(stem_lines) == 2 else 260
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
cv.a_rounded(pr - 230, SY2 + PH2 - 104, pr - 24, SY2 + PH2 - 56, 24,
             fill=(45, 212, 167, 26), outline=(45, 212, 167, 120))
cv.refresh(pr - 130, SY2 + PH2 - 80, 14, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY2 + PH2 - 68, "سؤال جديد", 20, BRAND, bold=True)

# ============================ التسميات ============================
row1 = [("الشرح ① — س1 + الشكل F0002", X1), ("الشرح ② — البرهان + الخواص + س2", X2), ("التجربة + تنبؤ", X3)]
for txt, x in row1:
    w = text_width(txt, NASKH, 23, True)
    draw_rtl(img, x + PW // 2 + w // 2, SY + PH + 56, txt, 23, TXT, bold=True)
row2 = [("بطاقات المراجعة (4)", X4), ("الاختبار الذاتي (4 قوالب)", X5)]
for txt, x in row2:
    w = text_width(txt, NASKH, 23, True)
    draw_rtl(img, x + PW2 // 2 + w // 2, SY2 + PH2 + 56, txt, 23, TXT, bold=True)

cv.draw_flow(XR, SY2 + PH2 + 130, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.2 من 73 · ", "ar"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.2-review.png")
