# -*- coding: utf-8 -*-
"""يرسم معاينة «وحدة التعلم الكاملة — النواس المرن» كصورة PNG
البنية المعتمدة (قرار ٧٥): شرح ← بطاقة مراجعة ← تجربة(+تنبؤ) ← مثال محلول ← سؤال يتجدد ∞
نفس هوية docs/13 ونفس خط الرندر في rtl_text.py"""
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
img = Image.new("RGBA", (W, 6000), BG + (255,))
d = ImageDraw.Draw(img)

def _c4(c):
    return c if len(c) == 4 else c + (255,)

def alpha_rect(x, y, w, h, fill, radius=0):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(layer)
    dd.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=_c4(fill))
    img.alpha_composite(layer, (x, y))

def card(x, y, w, h, radius, fill, border=None, bw=2, shadow=True, blur=24, dy=14):
    if shadow:
        sh = Image.new("RGBA", (w + blur * 2, h + blur * 2 + dy), (0, 0, 0, 0))
        ds = ImageDraw.Draw(sh)
        ds.rounded_rectangle([blur, blur + dy, blur + w - 1, blur + h - 1 + dy], radius=radius, fill=(0, 0, 0, 120))
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

def flow_width(segs, size, bold=False):
    return sum(text_width(t, NASKH, size, bold) if k == "ar" else text_width(t, DEJAVU, int(size * 0.9), bold) for t, k in segs)

def center_rtl(x_center, y, text, size, fill, bold=False, path=NASKH):
    w = text_width(text, path, size, bold)
    draw_rtl(img, x_center + w // 2, y, text, size, fill, path=path, bold=bold)

def center_ltr(x_center, y, text, size, fill, bold=False, slant=0.0):
    w = text_width(text, DEJAVU_SI if slant else DEJAVU, size, bold)
    draw_ltr(img, x_center - w // 2, y, text, size, fill, path=DEJAVU_SI if slant else DEJAVU, bold=bold, slant=slant)

def math_run_centered(x_center, y_baseline, ch, size=30):
    cw = text_width(ch, DEJAVU_SI, size)
    pw = cw + 26
    ph = 44
    x = x_center - pw // 2
    alpha_rect(x, y_baseline - 32, pw, ph, (56, 189, 248, 22), radius=10)
    d.rounded_rectangle([x, y_baseline - 32, x + pw - 1, y_baseline - 32 + ph - 1], radius=10, outline=(56, 189, 248, 50), width=2)
    center_ltr(x_center, y_baseline - 4, ch, size, MATHC, slant=0.22)
    return pw

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

def arrow_l(x, y, size, color, wdt=6):
    d.line([(x, y), (x + size, y)], fill=_c4(color), width=wdt)
    d.line([(x, y), (x + size * 0.4, y - size * 0.45)], fill=_c4(color), width=wdt)
    d.line([(x, y), (x + size * 0.4, y + size * 0.45)], fill=_c4(color), width=wdt)

def check(x, y, s, color, wdt=6):
    d.line([(x - s, y), (x - s * 0.25, y + s * 0.8)], fill=_c4(color), width=wdt)
    d.line([(x - s * 0.25, y + s * 0.8), (x + s, y - s * 0.7)], fill=_c4(color), width=wdt)

def refresh(x, y, r, color, wdt=5):
    d.arc([x - r, y - r, x + r, y + r], start=40, end=330, fill=_c4(color), width=wdt)
    ax, ay = x + r * 0.766, y - r * 0.643
    d.polygon([(ax, ay - 8), (ax + 12, ay + 2), (ax - 8, ay + 8)], fill=_c4(color))

def spring(x_top, y_top, y_bot, coils, amp, color, wdt=6):
    n = coils * 2
    dy = (y_bot - y_top) / n
    pts = [(x_top, y_top)]
    for i in range(1, n):
        pts.append((x_top + (amp if i % 2 == 1 else -amp), y_top + dy * i))
    pts.append((x_top, y_bot))
    d.line(pts, fill=_c4(color), width=wdt, joint="curve")

def ceiling(x, y, w, color):
    d.line([(x, y), (x + w, y)], fill=_c4(color), width=5)
    for i in range(0, w, 16):
        d.line([(x + i, y), (x + i - 10, y - 12)], fill=_c4(color), width=3)

def phone_frame(x, y, w, h, title, sub=None):
    card(x, y, w, h, 64, BG2, border=(29, 42, 69))
    pl, pr = x + 24, x + w - 24
    # شريط علوي
    d.line([(x, y + 84), (x + w, y + 84)], fill=_c4(LINE), width=2)
    d.rounded_rectangle([pr - 58, y + 16, pr, y + 72], radius=16, fill=_c4(CARD), outline=_c4(LINE), width=2)
    arrow_l(pr - 42, y + 44, 22, TXT, wdt=5)
    center_rtl(pr - 76 - text_width(title, NASKH, 27, True) // 2 + text_width(title, NASKH, 27, True) // 2, y + 40, title, 27, TXT, bold=True) if False else draw_rtl(img, pr - 76, y + 40, title, 27, TXT, bold=True)
    if sub:
        draw_rtl(img, pr - 76, y + 70, sub, 18, TXT2, path=SANS)
    return pl, pr

def bottom_bar(x, y, w):
    """فهمتها ✓ / التالية ⬅ (المرجعية المعتمدة 51ae7ae)"""
    pl, pr = x + 24, x + w - 24
    bh, gap = 88, 20
    bw = (pr - pl - gap) // 2
    # primary (يسار)
    grad = Image.new("RGB", (1, bh))
    for yy in range(bh):
        t = yy / (bh - 1)
        grad.putpixel((0, yy), (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t)))
    grad = grad.resize((bw, bh))
    m = Image.new("L", (bw, bh), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, bw - 1, bh - 1], radius=22, fill=255)
    img.paste(grad, (pl, y), m)
    tw = text_width("التالية", NASKH, 25, True)
    total = tw + 16 + 34
    sx = pl + bw // 2 - total // 2 + 16
    draw_rtl(img, sx + tw, y + bh - 32, "التالية", 25, DARKBTN, bold=True)
    arrow_l(sx, y + bh // 2, 20, DARKBTN, wdt=5)
    # ghost (يمين)
    gx = pr - bw
    alpha_rect(gx, y, bw, bh, CARD, radius=22)
    d.rounded_rectangle([gx, y, gx + bw - 1, y + bh - 1], radius=22, outline=_c4(LINE), width=2)
    t3 = "فهمتها"
    tw3 = text_width(t3, NASKH, 24, True)
    total3 = tw3 + 14 + 30
    sx3 = gx + bw // 2 - total3 // 2
    draw_rtl(img, sx3 + tw3, y + bh - 32, t3, 24, TXT2, bold=True)
    check(sx3 - 4, y + bh // 2, 13, TXT2, wdt=5)

def annotation(x, y, w, h, kicker, title, lines):
    card(x, y, w, h, 32, CARD, border=LINE)
    ax = x + w - 40
    kw = text_width(kicker, SANS, 21, True)
    d.rounded_rectangle([ax - kw - 30, y + 24, ax + 16, y + 74], radius=25, fill=(18, 35, 60), outline=_c4(LINE), width=2)
    draw_rtl(img, ax, y + 62, kicker, 21, BRAND2, path=SANS, bold=True)
    draw_rtl(img, ax, y + 140, title, 32, TXT, bold=True)
    yy = y + 200
    for segs in lines:
        draw_flow(ax, yy, segs, 22, TXT2)
        yy += 56

# ============================ الرأس ============================
XR = 2400
draw_rtl(img, XR, 96, "معاينة تصميم — وحدة التعلم الكاملة", 26, BRAND2, path=SANS, bold=True)
draw_rtl(img, XR, 178, "الوحدة ١: النواس المرن — الدورة الكاملة (٥ أجزاء)", 50, TXT, bold=True)
draw_flow(XR, 256, [
    ("التسلسل المعتمد: شرح ← بطاقة مراجعة ← تجربة (+تنبؤ) ← مثال محلول ← سؤال يتجدد ", "ar"),
    ("∞", "la"),
    (" — الاختبار اختياري، وطبقة التعليم نتألفها من المنهج + نوط الأستاذ (الأستاذ يعتمد).", "ar"),
], 26, TXT2)
pr = XR
chip_specs = [
    ([("الوحدات: ", "ar"), ("~100", "la"), (" بالنوط كلها", "ar")], TXT2, LINE, CARD),
    ([("الاختبار الذاتي: اختياري", "ar")], BRAND, LINE, CARD),
    ([("نتألفها — الأستاذ يعتمد", "ar")], BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
]
for segs, tc, bc, bg in chip_specs:
    w = flow_width(segs, 23) + 52
    alpha_rect(pr - w, 316, w, 60, bg, radius=30)
    a_rounded(pr - w, 316, pr - 1, 375, 30, outline=bc, width=2)
    draw_flow(pr - 26, 316 + 44, segs, 23, tc)
    pr -= w + 24

# ============================ شريط التدفق ============================
SY = 470
dashed_y = SY - 14
steps = ["الشرح", "بطاقة مراجعة", "التجربة + تنبؤ", "مثال محلول", "اختبار ذاتي"]
mini_w, mini_h, gap = 392, 660, 52
total_w = 5 * mini_w + 4 * gap
x0 = 2400 - total_w
for i in range(5):
    mx = x0 + i * (mini_w + gap)
    # سهم بين (من اليمين للشمال)
    if i < 4:
        sx = mx - gap // 2
        arrow_l(sx - 16, SY + mini_h // 2, 32, BRAND, wdt=7)
    card(mx, SY, mini_w, mini_h, 44, BG2, border=(29, 42, 69), shadow=False, )
    # شارة رقم
    num = ["١", "٢", "٣", "٤", "٥"][i]
    a_ellipse(mx + 18, SY + 14, mx + 70, SY + 66, fill=(45, 212, 167, 40), outline=_c4(BRAND), width=2)
    center_rtl(mx + 44, SY + 50, num, 26, BRAND, bold=True)
    # محتوى مصغر حسب الخطوة
    cx = mx + mini_w // 2
    if i == 0:  # شرح (معتمد)
        d.rounded_rectangle([mx + 20, SY + 90, mx + mini_w - 20, SY + 170], radius=14, outline=_c4(BRAND), width=2)
        d.polygon([(mx + mini_w - 78, SY + 90), (mx + mini_w - 40, SY + 90), (mx + mini_w - 59, SY + 112)], fill=_c4(BRAND))
        draw_rtl(img, cx + 26, SY + 150, "معتمد", 22, BRAND, bold=True)
        check(cx - 30, SY + 138, 11, BRAND, wdt=4)
        for j, wfr in enumerate([0.9, 0.75, 0.85, 0.6]):
            lw = int((mini_w - 70) * wfr)
            d.rounded_rectangle([cx - lw // 2, SY + 210 + j * 34, cx + lw // 2, SY + 224 + j * 34], radius=7, fill=CARD2)
        d.rounded_rectangle([cx - 40, SY + 360, cx + 40, SY + 396], radius=10, outline=(56, 189, 248, 120), width=2)
        center_ltr(cx, SY + 388, "k m", 24, MATHC, slant=0.2)
        for j in range(3):
            lw = int((mini_w - 70) * [0.88, 0.7, 0.8][j])
            d.rounded_rectangle([cx - lw // 2, SY + 430 + j * 34, cx + lw // 2, SY + 444 + j * 34], radius=7, fill=CARD2)
    elif i == 1:  # بطاقة
        card(mx + 40, SY + 110, mini_w - 80, 300, 24, CARD, border=LINE)
        center_rtl(cx, SY + 240, "مركز الاهتزاز", 34, TXT, bold=True)
        refresh(cx, SY + 330, 22, TXT2, wdt=5)
        for j, wfr in enumerate([0.55, 0.4]):
            lw = int((mini_w - 120) * wfr)
            d.rounded_rectangle([cx - lw // 2, SY + 390 + j * 30, cx + lw // 2, SY + 402 + j * 30], radius=6, fill=CARD2)
        d.rounded_rectangle([mx + 50, SY + 470, mx + mini_w - 50, SY + 530], radius=16, fill=_c4(BRAND))
        draw_rtl(img, cx + 24, SY + 510, "عرفتها", 24, DARKBTN, bold=True)
        check(cx - 34, SY + 498, 12, DARKBTN, wdt=4)
    elif i == 2:  # تجربة
        a_rounded(mx + 30, SY + 96, mx + mini_w - 30, SY + 156, 14, fill=(56, 189, 248, 20), outline=(56, 189, 248, 90), width=2)
        center_rtl(cx, SY + 138, "تنبأ قبل التشغيل", 19, BRAND2, bold=True)
        ceiling(mx + 90, SY + 200, mini_w - 180, (90, 110, 140))
        spring(cx, SY + 200, SY + 380, 5, 34, (150, 170, 200))
        d.ellipse([cx - 30, SY + 380, cx + 30, SY + 440], fill=_c4(GOLD))
        d.rounded_rectangle([mx + 50, SY + 480, mx + mini_w - 50, SY + 492], radius=6, fill=CARD2)
        d.ellipse([mx + 160, SY + 470, mx + 192, SY + 502], fill=_c4(BRAND))
        d.rounded_rectangle([mx + 90, SY + 540, mx + mini_w - 90, SY + 600], radius=16, fill=_c4(BRAND))
        d.polygon([(cx - 26, SY + 562), (cx - 26, SY + 582), (cx - 8, SY + 572)], fill=_c4(DARKBTN))
        draw_rtl(img, cx + 52, SY + 584, "تشغيل", 24, DARKBTN, bold=True)
    elif i == 3:  # مثال
        d.rounded_rectangle([mx + 30, SY + 100, mx + mini_w - 30, SY + 210], radius=16, fill=_c4(CARD), outline=_c4(LINE), width=2)
        for j, wfr in enumerate([0.8, 0.6]):
            lw = int((mini_w - 90) * wfr)
            d.rounded_rectangle([cx - lw // 2, SY + 124 + j * 40, cx + lw // 2, SY + 138 + j * 40], radius=6, fill=CARD2)
        d.rounded_rectangle([mx + 70, SY + 240, mx + mini_w - 70, SY + 300], radius=16, fill=_c4(BRAND))
        center_rtl(cx, SY + 282, "اعرض الحل", 24, DARKBTN, bold=True)
        d.rounded_rectangle([mx + 30, SY + 330, mx + mini_w - 30, SY + 560], radius=16, fill=(18, 28, 48), outline=(44, 63, 99), width=2)
        for j in range(4):
            lw = int((mini_w - 100) * [0.7, 0.55, 0.62, 0.4][j])
            d.rounded_rectangle([cx - lw // 2, SY + 356 + j * 48, cx + lw // 2, SY + 370 + j * 48], radius=6, fill=CARD2)
        a_rounded(cx - 60, SY + 520, cx + 60, SY + 552, 10, outline=(56, 189, 248, 120), width=2)
        center_ltr(cx, SY + 546, "≈ 0.99 s", 22, MATHC)
    else:  # سؤال
        d.rounded_rectangle([mx + 30, SY + 100, mx + mini_w - 30, SY + 190], radius=16, fill=_c4(CARD), outline=_c4(LINE), width=2)
        for j, wfr in enumerate([0.85, 0.6]):
            lw = int((mini_w - 90) * wfr)
            d.rounded_rectangle([cx - lw // 2, SY + 122 + j * 38, cx + lw // 2, SY + 136 + j * 38], radius=6, fill=CARD2)
        for j in range(4):
            d.rounded_rectangle([mx + 50, SY + 216 + j * 62, mx + mini_w - 50, SY + 268 + j * 62], radius=14, outline=_c4(LINE), width=2)
            lw = int((mini_w - 140) * [0.3, 0.4, 0.33, 0.38][j])
            d.rounded_rectangle([cx + 20 - lw // 2, SY + 232 + j * 62, cx + 20 + lw // 2, SY + 246 + j * 62], radius=6, fill=CARD2)
        d.rounded_rectangle([mx + 60, SY + 490, mx + mini_w - 60, SY + 560], radius=18, fill=_c4(BRAND))
        refresh(cx - 90, SY + 525, 16, DARKBTN, wdt=4)
        draw_rtl(img, cx + 70, SY + 540, "سؤال جديد", 24, DARKBTN, bold=True)
    # تسمية تحت
    label = steps[i]
    if i == 4:
        label = "اختبار ذاتي (سؤال جديد ∞)"
    center_rtl(cx, SY + mini_h + 52, label, 26, TXT, bold=True)

# ============================ الأقسام ============================
SEC_Y0 = SY + mini_h + 130
PHONE_X, PHONE_W, PHONE_H = 1600, 800, 980
ANN_X, ANN_W, ANN_H = 80, 1440, 980

def section(y, step_label, title, build_phone, ann):
    d.line([(80, y - 46), (2400, y - 46)], fill=_c4(LINE), width=2)
    sw = text_width(step_label, NASKH, 24, True)
    alpha_rect(2400 - sw - 130, y - 84, sw + 130, 56, (45, 212, 167, 20), radius=28)
    a_rounded(2400 - sw - 130, y - 84, 2399, y - 29, 28, outline=(45, 212, 167, 100), width=2)
    draw_rtl(img, 2400 - 65, y - 38, step_label, 24, BRAND, bold=True)
    draw_rtl(img, 2400 - sw - 170, y - 38, title, 40, TXT, bold=True)
    pl, pr = phone_frame(PHONE_X, y, PHONE_W, PHONE_H, ann["phone_title"], ann.get("phone_sub"))
    build_phone(pl, pr, y)
    annotation(ANN_X, y, ANN_W, ANN_H, ann["kicker"], ann["title"], ann["lines"])
    return y + PHONE_H + 72

def unit_chip(pl, pr, y):
    tw = text_width("النواس المرن · وحدة ١", NASKH, 19)
    w = tw + 44
    alpha_rect(pr - w, y, w, 44, CARD2, radius=22)
    d.rounded_rectangle([pr - w, y, pr - 1, y + 43], radius=22, outline=_c4(LINE), width=2)
    draw_rtl(img, pr - 22, y + 32, "النواس المرن · وحدة ١", 19, TXT2)

# ---------- ٢: بطاقة المراجعة ----------
def build_card_phone(pl, pr, y):
    unit_chip(pl, pr, y + 96)
    # عداد
    draw_rtl(img, pr, y + 152, "٣/١", 22, BRAND, bold=True)
    # بطاقة
    bx, by, bw, bh = pl + 60, y + 200, PHONE_W - 120, 400
    card(bx, by, bw, bh, 28, CARD, border=(44, 63, 99), bw=2)
    cx = bx + bw // 2
    center_rtl(cx, by + 150, "مركز الاهتزاز", 46, TXT, bold=True)
    # خط فاصل
    d.line([(bx + 60, by + 210), (bx + bw - 60, by + 210)], fill=_c4(LINE), width=2)
    refresh(cx, by + 280, 26, TXT2, wdt=6)
    # أزرار
    bb, bh2, gap = y + 640, 76, 20
    bw2 = (pr - pl - gap) // 2
    d.rounded_rectangle([pl, bb, pl + bw2 - 1, bb + bh2 - 1], radius=20, fill=CARD, outline=_c4(LINE), width=2)
    center_rtl(pl + bw2 // 2, bb + 52, "أعرضها بعدين", 23, TXT2, bold=True)
    grad = Image.new("RGB", (1, bh2))
    for yy in range(bh2):
        t = yy / (bh2 - 1)
        grad.putpixel((0, yy), (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t)))
    grad = grad.resize((bw2, bh2))
    m = Image.new("L", (bw2, bh2), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, bw2 - 1, bh2 - 1], radius=20, fill=255)
    img.paste(grad, (pr - bw2, bb), m)
    t3 = "عرفتها"
    tw3 = text_width(t3, NASKH, 24, True)
    total3 = tw3 + 14 + 30
    sx3 = pr - bw2 // 2 - total3 // 2
    draw_rtl(img, sx3 + tw3, bb + 50, t3, 24, DARKBTN, bold=True)
    check(sx3 - 4, bb + bh2 // 2 - 2, 13, DARKBTN, wdt=5)
    # نقاط التقدم
    for i in range(3):
        px = pl + 30 + i * 34
        d.ellipse([px, y + 756, px + 16, y + 772], fill=_c4(BRAND) if i == 0 else _c4(CARD2))

ycur = section(SEC_Y0, "الجزء ٢", "بطاقة المراجعة — تثبيت ما قريته", build_card_phone, {
    "phone_title": "بطاقة مراجعة", "phone_sub": "بعد القراءة مباشرة",
    "kicker": "استرجاع نشط", "title": "بطاقة مراجعة من تعريف الأستاذ",
    "lines": [
        [("المحتوى: ", "ar"), ("2-4", "la"), (" بطاقات لكل وحدة — الأوجه من تعريفات الأستاذ (البلوك ٦): المصطلح وجه + التعريف ظهر.", "ar")],
        [("نتألفها من تعريفات الأستاذ + المنهج — الأستاذ يراجع ويعتمد وحدة-وحدة (قرار ٧٧).", "ar")],
        [("التكرار: توزيع متباعد بالخوارزمية الموجودة بالتطبيق (", "ar"), ("FSRS", "la"), (") — ", "ar"), ("docs/12", "ar")],
        [("الوحدة الخفيفة؟ ", "ar"), ("1-2", "la"), (" بطاقات تكفي — مو كل وحدة تاخذ أربع.", "ar")],
    ],
})

# ---------- ٣: التجربة (+ تنبؤ) ----------
def build_exp_phone(pl, pr, y):
    unit_chip(pl, pr, y + 96)
    cx = (pl + pr) // 2
    # شريط التنبؤ
    a_rounded(pl, y + 140, pr, y + 208, 16, fill=(56, 189, 248, 20), outline=(56, 189, 248, 90), width=2)
    draw_rtl(img, pr - 20, y + 182, "تنبأ قبل التشغيل:", 21, BRAND2, bold=True)
    choices = ["ما يتغير", "ينقص للنصف", "يتضاعف"]
    chw = 150
    chx = pl + 14
    for i, c in enumerate(choices):
        x1 = chx + i * (chw + 12)
        sel = (i == 1)
        a_rounded(x1, y + 154, x1 + chw, y + 194, 14,
                            fill=(45, 212, 167, 30) if sel else CARD,
                            outline=(45, 212, 167, 160) if sel else LINE, width=2)
        center_rtl(x1 + chw // 2, y + 184, c, 19, BRAND if sel else TXT2, bold=sel)
    # منطقة المحاكاة
    sim_y, sim_h = y + 236, 420
    card(pl + 20, sim_y, pr - pl - 40, sim_h, 20, (8, 14, 26), border=(44, 63, 99))
    scx = cx
    ceiling(scx - 130, sim_y + 44, 260, (90, 110, 140))
    spring(scx, sim_y + 44, sim_y + 250, 7, 46, (150, 170, 200))
    d.ellipse([scx - 44, sim_y + 250, scx + 44, sim_y + 338], fill=_c4(GOLD))
    center_ltr(scx, sim_y + 300, "m", 30, (120, 70, 0), bold=True, slant=0.22)
    # سهم الإزاحة
    d.line([(scx + 120, sim_y + 60), (scx + 120, sim_y + 280)], fill=_c4(BRAND2), width=4)
    d.polygon([(scx + 120, sim_y + 52), (scx + 112, sim_y + 72), (scx + 128, sim_y + 72)], fill=_c4(BRAND2))
    d.polygon([(scx + 120, sim_y + 288), (scx + 112, sim_y + 268), (scx + 128, sim_y + 268)], fill=_c4(BRAND2))
    draw_ltr(img, scx + 138, sim_y + 172, "x", 28, BRAND2, slant=0.22, path=DEJAVU_SI)
    # قراءة الزمن الدوري
    d.rounded_rectangle([scx - 120, sim_y + 356, scx + 120, sim_y + 400], radius=12, fill=CARD, outline=_c4(LINE), width=2)
    draw_ltr(img, scx - 96, sim_y + 388, "T = 1.41 s", 24, MATHC, path=DEJAVU_B)
    # سلايدر الكتلة
    sy = y + 700
    d.rounded_rectangle([pl + 60, sy, pr - 60, sy + 12], radius=6, fill=CARD2)
    d.rounded_rectangle([pl + 60, sy, pl + 240, sy + 12], radius=6, fill=_c4(BRAND))
    d.ellipse([pl + 222, sy - 12, pl + 258, sy + 24], fill=_c4(BRAND))
    draw_rtl(img, pr - 60, sy + 48, "الكتلة", 20, TXT2)
    center_ltr(pl + 150, sy + 46, "m", 26, MATHC, bold=True, slant=0.22)
    # زر التشغيل
    grad = Image.new("RGB", (1, 80))
    for yy in range(80):
        t = yy / 79
        grad.putpixel((0, yy), (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t)))
    grad = grad.resize((pr - pl - 120, 80))
    m = Image.new("L", (pr - pl - 120, 80), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, pr - pl - 121, 79], radius=20, fill=255)
    img.paste(grad, (pl + 60, y + 810), m)
    center_rtl(cx, y + 862, "تشغيل", 26, DARKBTN, bold=True)

ycur = section(ycur, "الجزء ٣", "التجربة — حدس قبل المعالجة", build_exp_phone, {
    "phone_title": "التجربة", "phone_sub": "محاكاة موجودة بالتطبيق",
    "kicker": "تجربة نشطة", "title": "التجربة الموجودة + سؤال تنبؤ",
    "lines": [
        [("المحاكاة: ", "ar"), ("الموجودة بالتطبيق", "ar"), (" (ما بنعيد اختراعها — قرار ٧٥).", "ar")],
        [("قبل التشغيل: سؤال تنبؤ بثلاث خيارات — تنبأ ثم تحقق، مو استكشاف أعمى (أدلة PhET).", "ar")],
        [("سبب الترتيب (تجربة ثم مثال): الطالب يمسك الإحساس بالظاهرة قبل المعالجة الرياضية.", "ar")],
        [("ما في تجربة للوحدة؟ الجزء يتخطى — الوحدة الخفيفة ما تاخذ إلزامات.", "ar")],
    ],
})

# ---------- ٤: المثال المحلول ----------
def build_ex_phone(pl, pr, y):
    unit_chip(pl, pr, y + 96)
    cx = (pl + pr) // 2
    # بطاقة المسألة
    card(pl + 30, y + 140, pr - pl - 60, 220, 24, CARD, border=LINE)
    draw_rtl(img, pr - 58, y + 186, "المطلوب", 20, BRAND2, bold=True)
    draw_flow(pr - 58, y + 248, [
        ("نابض صلابته ", "ar"), ("k = 20", "la"),
        (" معلق فيه جسم كتلته ", "ar"), ("m = 0.5", "la"),
        (" — احسب الزمن الدوري ", "ar"), ("T", "la"), (".", "ar"),
    ], 25, TXT)
    # زر الحل
    d.rounded_rectangle([cx - 110, y + 396, cx + 110, y + 456], radius=18, fill=_c4(BRAND))
    center_rtl(cx, y + 438, "اعرض الحل", 24, DARKBTN, bold=True)
    # الحل المفتوح
    card(pl + 30, y + 488, pr - pl - 60, 380, 24, (18, 28, 48), border=(44, 63, 99))
    draw_rtl(img, pr - 58, y + 534, "الحل", 22, BRAND, bold=True)
    steps = [
        [("T = 2π√(m/k)", "la")],
        [("T = 2π√(0.5/20)", "la")],
        [("≈ 0.99 s   ", "la"), ("— تقريباً ثانية", "ar")],
    ]
    for i, segs in enumerate(steps):
        yy = y + 606 + i * 76
        a_ellipse(pr - 60, yy - 24, pr - 34, yy + 2, fill=(45, 212, 167, 40), outline=_c4(BRAND), width=2)
        center_rtl(pr - 47, yy - 4, str(i + 1), 18, BRAND, bold=True)
        draw_flow(pr - 84, yy, segs, 26, TXT, bold=True)
    a_rounded(cx - 90, y + 812, cx + 90, y + 850, 12, outline=(56, 189, 248, 120), width=2)
    center_ltr(cx, y + 842, "T ≈ 1 s", 24, MATHC, bold=True)

ycur = section(ycur, "الجزء ٤", "المثال المحلول — من أمثلة الأستاذ", build_ex_phone, {
    "phone_title": "مثال محلول", "phone_sub": "قبل الاختبار",
    "kicker": "مثال محلول", "title": "خطوة-خطوة من نوطة الأستاذ",
    "lines": [
        [("المحتوى الفعلي: ", "ar"), ("أمثلة الأستاذ حرفياً", "ar"), (" (المعطيات والحل كما بالنوط — R1–R14 فقط). الأرقام بالصورة توضيحية للصيغة.", "ar")],
        [("المبدأ: worked example — الطالب يشوف طريقة التفكير قبل ما يعالج بنفسه (يقلل الحمل المعرفي).", "ar")],
        [("نتألفها من أمثلة الأستاذ + المنهج (قرار ٧٧) — الأستاذ يراجع ويعتمد وحدة-وحدة (قد يعدل قبل الاعتماد).", "ar")],
        [("لا مثال بالوحدة؟ الجزء يتخطى — الوحدة الخفيفة: شرح + بطاقة + سؤال.", "ar")],
    ],
})

# ---------- ٥: الاختبار الذاتي ----------
def build_q_phone(pl, pr, y):
    unit_chip(pl, pr, y + 96)
    cx = (pl + pr) // 2
    # السؤال
    card(pl + 30, y + 140, pr - pl - 60, 200, 24, CARD, border=LINE)
    draw_rtl(img, pr - 58, y + 186, "سؤال", 20, BRAND2, bold=True)
    draw_flow(pr - 58, y + 246, [
        ("نابض صلابته ", "ar"), ("k = 8", "la"),
        (" يحمل كتلة ", "ar"), ("m = 0.2", "la"),
        (" — الزمن الدوري؟", "ar"),
    ], 25, TXT)
    # الخيارات (معطيات مختلفة عن المثال = القالب المتجدد)
    opts = ["0.50 s", "1.26 s", "2.51 s", "3.14 s"]
    oy = y + 372
    for i, txt in enumerate(opts):
        a_rounded(pl + 40, oy, pr - 40, oy + 68, 16, fill=CARD if i != 0 else (45, 212, 167, 45), outline=LINE if i != 0 else (45, 212, 167, 160), width=2)
        draw_ltr(img, pr - 130, oy + 44, txt, 24, TXT, path=DEJAVU_B)
        num = ["أ", "ب", "ج", "د"][i]
        d.ellipse([pl + 58, oy + 16, pl + 102, oy + 60], fill=CARD2, outline=_c4(LINE), width=2)
        center_rtl(pl + 80, oy + 48, num, 22, TXT2, bold=True)
        oy += 84
    # زر سؤال جديد
    grad = Image.new("RGB", (1, 84))
    for yy in range(84):
        t = yy / 83
        grad.putpixel((0, yy), (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t)))
    grad = grad.resize((pr - pl - 120, 84))
    m = Image.new("L", (pr - pl - 120, 84), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, pr - pl - 121, 83], radius=20, fill=255)
    img.paste(grad, (pl + 60, y + 730), m)
    refresh(cx - 105, y + 772, 17, DARKBTN, wdt=4)
    draw_rtl(img, cx + 95, y + 786, "سؤال جديد", 26, DARKBTN, bold=True)
    bottom_bar(PHONE_X, y + PHONE_H - 132, PHONE_W)

ycur = section(ycur, "الجزء ٥", "الاختبار الذاتي — سؤال بيتجدد", build_q_phone, {
    "phone_title": "اختبر نفسك", "phone_sub": None,
    "kicker": "تمرين لا نهائي", "title": "قالب معاملي: كل ضغطة = سؤال جديد",
    "lines": [
        [("كل ضغطة «سؤال جديد» = معطيات جديدة (المثال: k=20, m=0.5  ثم السؤال: k=8, m=0.2) + خلط الخيارات.", "ar")],
        [("القوالب: المسائل العددية كلها معاملية (m, k, A, θ, g) — قالب واحد يغطي عشرات المتغيرات.", "ar")],
        [("مشتتات تلقائية من الأخطاء الشائعة (الجذر بالعكس، إهمال 2π، …).", "ar")],
        [("اختياري (قرار ٧٦): ما في بوابة إجبارية — «فهمتها» متاحة دائماً، والزر بيدي تمرين لا نهائي بدون كتابة يدوية.", "ar")],
    ],
})

# تذييل
draw_flow(XR, ycur + 30, [
    ("بعد اعتماد هالصورة: خرائط الوحدات (حوالي ", "ar"), ("100", "la"),
    (") ثم تأليف طبقة التعليم لكل وحدة ثم صفحة مراجعة ", "ar"), ("v2", "la"),
], 22, TXT2)
draw_flow(XR, ycur + 76, [
    ("هوية ", "ar"), ("docs/13", "la"), (" · قرارات ", "ar"), ("73-77", "la"), (" (", "ar"),
    ("docs/35", "la"), (") · رندر ", "ar"), ("uharfbuzz + freetype", "la"), (" · ", "ar"),
    ("2026-10-01", "la"),
], 20, TXT2)

img2 = img.crop((0, 0, W, ycur + 110))
img2.convert("RGB").save("/home/user/Almorshed/ui-mockup/nawwasat-unit-preview.png")
print("saved", img2.size)
