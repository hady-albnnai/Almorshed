# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.1: شاشة نظيفة (شرح + بطاقات + أسئلة) لإرسالها للأستاذ"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

BG      = (5, 8, 15)
BG2     = (11, 18, 32)
CARD    = (22, 34, 58)
CARD2   = (28, 43, 71)
TXT     = (232, 238, 247)
TXT2    = (157, 176, 201)
LINE    = (36, 51, 80)
BRAND   = (45, 212, 167)
BRAND2  = (56, 189, 248)
GOLD    = (251, 191, 36)
MATHC   = (125, 211, 252)
DARKBTN = (4, 33, 26)

W = 2480
img = Image.new("RGBA", (W, 1780), BG + (255,))
d = ImageDraw.Draw(img)

def _c4(c):
    return c if len(c) == 4 else c + (255,)

def alpha_rect(x, y, w, h, fill, radius=0):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(layer)
    dd.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=_c4(fill))
    img.alpha_composite(layer, (x, y))

def a_rounded(x1, y1, x2, y2, radius, fill=None, outline=None, width=2):
    pad = 12
    layer = Image.new("RGBA", (x2 - x1 + pad * 2, y2 - y1 + pad * 2), (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    dl.rounded_rectangle([pad, pad, pad + (x2 - x1) - 1, pad + (y2 - y1) - 1], radius=radius,
                         fill=_c4(fill) if fill else None, outline=_c4(outline) if outline else None, width=width)
    img.alpha_composite(layer, (x1 - pad, y1 - pad))

def a_ellipse(x1, y1, x2, y2, fill=None, outline=None, width=2):
    pad = 12
    layer = Image.new("RGBA", (x2 - x1 + pad * 2, y2 - y1 + pad * 2), (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    dl.ellipse([pad, pad, pad + (x2 - x1) - 1, pad + (y2 - y1) - 1],
               fill=_c4(fill) if fill else None, outline=_c4(outline) if outline else None, width=width)
    img.alpha_composite(layer, (x1 - pad, y1 - pad))

def card(x, y, w, h, radius, fill, border=None, bw=2, shadow=True, blur=22, dy=12):
    if shadow:
        sh = Image.new("RGBA", (w + blur * 2, h + blur * 2 + dy), (0, 0, 0, 0))
        ds = ImageDraw.Draw(sh)
        ds.rounded_rectangle([blur, blur + dy, blur + w - 1, blur + h - 1 + dy], radius=radius, fill=(0, 0, 0, 110))
        sh = sh.filter(ImageFilter.GaussianBlur(blur / 2))
        img.alpha_composite(sh, (x - blur, y - blur))
    alpha_rect(x, y, w, h, fill, radius)
    if border:
        d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=radius, outline=_c4(border), width=bw)

def draw_flow(x_right, y_baseline, segs, size, fill, bold=False):
    pen = x_right
    for text, kind in segs:
        if kind == "ar":
            w = text_width(text, NASKH, size, bold)
            draw_rtl(img, pen, y_baseline, text, size, fill, bold=bold)
            pen -= w
        else:
            ls = int(size * 0.9)
            w = text_width(text, DEJAVU, ls, bold)
            draw_ltr(img, pen - w, y_baseline - 2, text, ls, fill, path=DEJAVU, bold=bold)
            pen -= w
    return pen

def math_run(x_right, y_baseline, ch, size=26):
    cw = text_width(ch, DEJAVU_SI, size)
    pw, ph = cw + 24, 40
    alpha_rect(x_right - pw, y_baseline - 28, pw, ph, (56, 189, 248, 22), radius=9)
    d.rounded_rectangle([x_right - pw, y_baseline - 28, x_right - 1, y_baseline - 28 + ph - 1], radius=9,
                        outline=(56, 189, 248, 50), width=2)
    draw_ltr(img, x_right - pw + 12, y_baseline - 3, ch, size, MATHC, path=DEJAVU_SI, slant=0.22)
    return x_right - pw - 10

def arrow_l(x, y, size, color, wdt=5):
    d.line([(x, y), (x + size, y)], fill=_c4(color), width=wdt)
    d.line([(x, y), (x + size * 0.4, y - size * 0.45)], fill=_c4(color), width=wdt)
    d.line([(x, y), (x + size * 0.4, y + size * 0.45)], fill=_c4(color), width=wdt)

def check(x, y, s, color, wdt=5):
    d.line([(x - s, y), (x - s * 0.25, y + s * 0.8)], fill=_c4(color), width=wdt)
    d.line([(x - s * 0.25, y + s * 0.8), (x + s, y - s * 0.7)], fill=_c4(color), width=wdt)

def refresh(x, y, r, color, wdt=4):
    d.arc([x - r, y - r, x + r, y + r], start=40, end=330, fill=_c4(color), width=wdt)
    ax, ay = x + r * 0.766, y - r * 0.643
    d.polygon([(ax, ay - 7), (ax + 11, ay + 2), (ax - 7, ay + 7)], fill=_c4(color))

def pill_r(x_right, y, text, tsize, tcolor, bcolor, bg, padx=22, h=48):
    tw = text_width(text, NASKH, tsize, True)
    w = tw + padx * 2
    alpha_rect(x_right - w, y, w, h, bg, radius=h // 2)
    d.rounded_rectangle([x_right - w, y, x_right - 1, y + h - 1], radius=h // 2, outline=_c4(bcolor), width=2)
    draw_rtl(img, x_right - padx, y + h - 14, text, tsize, tcolor, bold=True)
    return x_right - w

def phone(x, y, w, h, title):
    card(x, y, w, h, 56, BG2, border=(29, 42, 69))
    pl, pr = x + 24, x + w - 24
    d.line([(x, y + 78), (x + w, y + 78)], fill=_c4(LINE), width=2)
    d.rounded_rectangle([pr - 54, y + 14, pr, y + 66], radius=15, fill=_c4(CARD), outline=_c4(LINE), width=2)
    arrow_l(pr - 40, y + 40, 20, TXT, wdt=5)
    draw_rtl(img, pr - 74, y + 40, title, 25, TXT, bold=True)
    draw_rtl(img, pr - 74, y + 68, "الوحدة 1.1 · النواس المرن", 16, TXT2, path=SANS)
    return pl, pr

def bottom_bar(x, y, w):
    pl, pr = x + 24, x + w - 24
    bh, gap = 78, 18
    bw = (pr - pl - gap) // 2
    grad = Image.new("RGB", (1, bh))
    for yy in range(bh):
        t = yy / (bh - 1)
        grad.putpixel((0, yy), (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t)))
    grad = grad.resize((bw, bh))
    m = Image.new("L", (bw, bh), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, bw - 1, bh - 1], radius=20, fill=255)
    img.paste(grad, (pl, y), m)
    tw = text_width("التالية", NASKH, 23, True)
    total = tw + 14 + 30
    sx = pl + bw // 2 - total // 2 + 14
    draw_rtl(img, sx + tw, y + bh - 28, "التالية", 23, DARKBTN, bold=True)
    arrow_l(sx, y + bh // 2, 18, DARKBTN, wdt=5)
    gx = pr - bw
    alpha_rect(gx, y, bw, bh, CARD, radius=20)
    d.rounded_rectangle([gx, y, gx + bw - 1, y + bh - 1], radius=20, outline=_c4(LINE), width=2)
    t3, tw3 = "فهمتها", text_width("فهمتها", NASKH, 22, True)
    total3 = tw3 + 12 + 26
    sx3 = gx + bw // 2 - total3 // 2
    draw_rtl(img, sx3 + tw3, y + bh - 28, t3, 22, TXT2, bold=True)
    check(sx3 - 3, y + bh // 2 - 1, 11, TXT2, wdt=4)

# ============================ الرأس ============================
XR = 2400
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
draw_flow(XR, 162, [
    ("الوحدة 1.1 — ", "ar"), ("النواس المرن الغير متخامد", "ar"),
], 48, TXT, bold=True)
pr = XR
for txt, tc, bc, bg in [
    ("النص حرفي من النوط + تصحيحات R1–R14", BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ("3 بطاقات · 3 قوالب أسئلة", TXT2, LINE, CARD),
    ("وحدة خفيفة: بدون تجربة وبدون مثال", TXT2, LINE, CARD),
]:
    tw = text_width(txt, NASKH, 22, True)
    w = tw + 48
    alpha_rect(pr - w, 214, w, 54, bg, radius=27)
    d.rounded_rectangle([pr - w, 214, pr - 1, 267], radius=27, outline=_c4(bc), width=2)
    draw_rtl(img, pr - 24, 214 + 39, txt, 22, tc, bold=True)
    pr -= w + 20

# ============================ الهواتف ============================
SY, PW, PH = 330, 720, 1290
X1, X2, X3 = 2400 - PW, 2400 - 2 * PW - 40, 2400 - 3 * PW - 80

# ---------- هاتف 1: الشرح ----------
pl, pr = phone(X1, SY, PW, PH, "الاهتزازات التوافقية البسيطة")
# شريط التقدم
draw_rtl(img, pr, SY + 116, "الوحدة ١", 20, BRAND, bold=True)
d.rounded_rectangle([pl, SY + 130, pr, SY + 139], radius=5, fill=CARD + (255,))
d.rounded_rectangle([pr - 14, SY + 130, pr, SY + 139], radius=5, fill=BRAND + (255,))
# كارت الشرح
cy, chh = SY + 166, 520
card(pl, cy, pr - pl, chh, 26, CARD, border=LINE)
cr = pr - 24
cr = pill_r(cr, cy + 26, "النواس المرن الغير متخامد", 19, BRAND, (45, 212, 167, 100), (45, 212, 167, 26)) - 12
pill_r(cr, cy + 26, "وحدة ١", 19, TXT2, LINE, CARD2)
draw_rtl(img, cr, cy + 128, "تعريفه", 30, TXT, bold=True)
LH, by = 54, cy + 196
def seg_line(segs, y):
    pen = cr
    for text, kind in segs:
        if kind == "m":
            pen = math_run(pen - 6, y, text)
        else:
            w = text_width(text, NASKH, 26, kind == "b")
            draw_rtl(img, pen, y, text, 26, TXT if kind == "b" else (219, 230, 243), bold=(kind == "b"))
            pen -= w
seg_line([("هو عبارة عن نابض مرن مهمل الكتلة", "n")], by); by += LH
seg_line([("حلقاته متباعدة ثابت صلابته ", "n"), ("k", "m"), (" معلق فيه", "n")], by); by += LH
seg_line([("جسم صلب كتلته ", "n"), ("m", "m"), (" يمكنه أن يهتز", "n")], by); by += LH
seg_line([("الى جانبي نقطة ثابتة تدعى", "n")], by); by += LH
seg_line([(" ", "n"), ("مركز الاهتزاز", "b"), (" (أو موضع التوازن)", "n")], by); by += LH
bottom_bar(X1, SY + PH - 108, PW)

# ---------- هاتف 2: بطاقات المراجعة ----------
pl, pr = phone(X2, SY, PW, PH, "بطاقات المراجعة")
cards = [
    ("النواس المرن غير المتخامد", 240, [
        [("نابض مرن مهمل الكتلة حلقاته متباعدة،", "ar")],
        [(" ثابت صلابته ", "ar"), ("k", "la"), ("، معلق فيه جسم صلب", "ar")],
        [("كتلته ", "ar"), ("m", "la"), (" يمكنه أن يهتز إلى جانبي نقطة ثابتة.", "ar")],
    ]),
    ("مركز الاهتزاز", 200, [
        [("النقطة الثابتة التي يهتز الجسم إلى جانبيها —", "ar")],
        [("وتسمى أيضاً: موضع التوازن.", "ar")],
    ]),
    ("ثابت الصلابة k", 200, [
        [("الصلابة الثابتة للنابض — مقدار قوة الارجاع", "ar")],
        [("يتناسب طردياً مع المطال ", "ar"), ("(F = -kx)", "la")],
    ]),
]
by = SY + 100
for i, (front, card_h, back_lines) in enumerate(cards):
    card(pl, by, pr - pl, card_h, 22, CARD, border=LINE)
    # رقم البطاقة
    a_ellipse(pl + 20, by + 20, pl + 56, by + 56, fill=(45, 212, 167, 40), outline=BRAND + (255,), width=2)
    nw = text_width(str(i + 1), DEJAVU, 20, True)
    draw_ltr(img, pl + 38 - nw // 2, by + 48, str(i + 1), 20, TXT, path=DEJAVU, bold=True)
    draw_rtl(img, pr - 24, by + 50, front, 24, TXT, bold=True)
    d.line([(pl + 24, by + 78), (pr - 24, by + 78)], fill=_c4(LINE), width=2)
    yy = by + 122
    for segs in back_lines:
        draw_flow(pr - 24, yy, segs, 21, TXT2)
        yy += 34
    by += card_h + 24
draw_rtl(img, pr, SY + PH - 130, "3 بطاقات — الوجه الأول: المصطلح / الوجه الثاني: التعريف", 18, TXT2, path=SANS)

# ---------- هاتف 3: قوالب الأسئلة ----------
pl, pr = phone(X3, SY, PW, PH, "الاختبار الذاتي")
qs = [
    ("النابض الذي يهتز جسمه إلى جانبي نقطة ثابتة، تسمى هذه النقطة:",
     ["مركز الاهتزاز", "مركز كتلة الجسم", "نقطة تعليق النابض", "نهاية المطال الأعظمي"]),
    ("في تعريف النواس المرن، الرمز k يرمز إلى:",
     ["ثابت صلابة النابض", "كتلة الجسم المعلق", "سعة الاهتزاز", "الطور الابتدائي"]),
    ("قوله «نابض مهمل الكتلة» تعني أن:",
     ["كتلة النابض تُهمَل مقارنة بكتلة الجسم", "النابض بلا كتلة إطلاقاً", "الجسم بلا كتلة", "كتلة الجسم تتغير أثناء الاهتزاز"]),
]
by = SY + 100
for qi, (stem, opts) in enumerate(qs):
    qh = 330
    card(pl, by, pr - pl, qh, 22, CARD, border=LINE)
    # رقم السؤال
    a_ellipse(pl + 20, by + 20, pl + 56, by + 56, fill=(56, 189, 248, 40), outline=BRAND2 + (255,), width=2)
    nw = text_width(str(qi + 1), DEJAVU, 20, True)
    draw_ltr(img, pl + 38 - nw // 2, by + 48, str(qi + 1), 20, TXT, path=DEJAVU, bold=True)
    stem_lines = []
    import rtl_text
    for ln in rtl_text.wrap_rtl(stem, NASKH, 22, 560)[:2]:
        stem_lines.append(ln)
    yy = by + 48
    for ln in stem_lines:
        draw_rtl(img, pr - 24, yy, ln, 22, TXT)
        yy += 32
    yy += 8
    letters = ["أ", "ب", "ج", "د"]
    for oi, opt in enumerate(opts[:4]):
        row_h = 44
        correct = (oi == 0)
        a_rounded(pl + 24, yy, pr - 24, yy + row_h - 8, 12,
                  fill=(45, 212, 167, 30) if correct else (28, 43, 71, 120),
                  outline=(45, 212, 167, 140) if correct else None)
        d.ellipse([pl + 36, yy + 6, pl + 66, yy + 36], fill=CARD2, outline=_c4(LINE), width=2)
        center_x = pl + 51
        lw_ = text_width(letters[oi], NASKH, 17, True)
        draw_rtl(img, center_x + lw_ // 2, yy + 30, letters[oi], 17, TXT2, bold=True)
        opt_color = BRAND if correct else TXT2
        if correct:
            check(pr - 52, yy + 20, 10, BRAND, wdt=4)
        wopt = text_width(opt, NASKH, 18)
        draw_rtl(img, pr - 74, yy + 30, opt, 18, opt_color, bold=correct)
        yy += row_h + 6
    by += qh + 24
refresh(pr - 120, SY + PH - 122, 15, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY + PH - 110, "سؤال جديد", 20, BRAND, bold=True)
d.rounded_rectangle([pr - 230, SY + PH - 140, pr - 24, SY + PH - 92], radius=24, outline=(45, 212, 167, 100), width=2)

# تسميات تحت الهواتف
labels = [("الشرح — النص حرفي", X1), ("بطاقات المراجعة", X2), ("الاختبار الذاتي (3 قوالب)", X3)]
for txt, x in labels:
    w = text_width(txt, NASKH, 24, True)
    draw_rtl(img, x + PW // 2 + w // 2, SY + PH + 60, txt, 24, TXT, bold=True)

# تذييل
draw_flow(XR, 1748, [
    ("المراجعة: الأستاذ فداء البني · الوحدة 1.1 من 73 · ", "ar"), ("2026-10-01", "la"),
], 20, TXT2)

img.convert("RGB").save("/home/user/Almorshed/ui-mockup/unit-1.1-review.png")
print("saved", img.size)
