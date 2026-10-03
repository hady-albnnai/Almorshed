# -*- coding: utf-8 -*-
"""يرسم معاينة «أول فقرة من نوطة النواسات بالتطبيق» كصورة PNG
(بديل عن المتصفح — نفس تصميم ui-mockup/nawwasat-p1-preview.html)

التبعيات:
    pip install --user --break-system-packages pillow uharfbuzz freetype-py
    الخطوط (متغيّلة) في rtl_text.py → عدّل NASKH/SANS إذا تغيّر المسار:
      NotoNaskhArabic[wght].ttf · NotoSansArabic[wdth,wght].ttf
      (تُحمَّل من repos/google/fonts عبر api.github.com contents)
الإخراج: ui-mockup/nawwasat-p1-preview.png"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from rtl_text import (draw_rtl, draw_ltr, text_width, wrap_rtl,
                  NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

# ألوان docs/13
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
GOLDDK  = (245, 158, 11)
MATHC   = (125, 211, 252)

W, H = 2480, 2210
img = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(img)

def _c4(c):
    return c if len(c) == 4 else c + (255,)

def alpha_rect(x, y, w, h, fill, radius=0):
    fill = _c4(fill)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(layer)
    dd.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=fill)
    img.alpha_composite(layer, (x, y))

def shadow_card(x, y, w, h, radius, fill, border=None, blur=28, dy=18, border_w=2):
    sh = Image.new("RGBA", (w + blur * 2, h + blur * 2 + dy), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    ds.rounded_rectangle([blur, blur + dy, blur + w - 1, blur + h - 1 + dy], radius=radius, fill=(0, 0, 0, 130))
    sh = sh.filter(ImageFilter.GaussianBlur(blur / 2))
    img.alpha_composite(sh, (x - blur, y - blur))
    alpha_rect(x, y, w, h, fill, radius)
    if border:
        d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=radius, outline=_c4(border), width=border_w)

def pill(x_right, y, text, tsize, tcolor, bcolor, bg, tfont=NASKH, tbold=False, padx=28, h=60):
    tw = text_width(text, tfont, tsize, tbold)
    w = tw + padx * 2
    alpha_rect(x_right - w, y, w, h, bg, radius=h // 2)
    d.rounded_rectangle([x_right - w, y, x_right - 1, y + h - 1], radius=h // 2, outline=_c4(bcolor), width=2)
    draw_rtl(img, x_right - padx, y + h - 16, text, tsize, tcolor, path=tfont, bold=tbold)
    return x_right - w

def draw_flow(x_right, y_baseline, segs, size, fill, bold=False):
    """سطر مختلط: segs = [(text, 'ar'|'la')] يُرسم من اليمين"""
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

def arrow_left(x, y, size, color, wdt=6):
    d.line([(x, y), (x + size, y)], fill=_c4(color), width=wdt)
    d.line([(x, y), (x + size * 0.4, y - size * 0.45)], fill=_c4(color), width=wdt)
    d.line([(x, y), (x + size * 0.4, y + size * 0.45)], fill=_c4(color), width=wdt)

def flame(cx, cy, s=1.0):
    pts = [(cx, cy - 20 * s), (cx + 9 * s, cy - 6 * s), (cx + 12 * s, cy + 6 * s),
           (cx + 6 * s, cy + 15 * s), (cx, cy + 18 * s), (cx - 6 * s, cy + 15 * s),
           (cx - 12 * s, cy + 6 * s), (cx - 9 * s, cy - 6 * s)]
    d.polygon(pts, fill=_c4(GOLD))
    d.ellipse([cx - 6 * s, cy - 2 * s, cx + 6 * s, cy + 14 * s], fill=_c4(GOLDDK))

def dashed_h(x1, x2, y, color, dash=14, gap=10, wdt=2):
    x = x1
    while x < x2:
        d.line([(x, y), (min(x + dash, x2), y)], fill=_c4(color), width=wdt)
        x += dash + gap

def dashed_rect(x, y, w, h, radius, color, wdt=2):
    d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=radius, outline=_c4(color), width=wdt)

def math_run(x_right, y_baseline, ch, size=32):
    cw = text_width(ch, DEJAVU_SI, size)
    pw = cw + 30
    ph = 48
    alpha_rect(x_right - pw, y_baseline - 34, pw, ph, (56, 189, 248, 22), radius=10)
    d.rounded_rectangle([x_right - pw, y_baseline - 34, x_right - 1, y_baseline - 34 + ph - 1],
                        radius=10, outline=(56, 189, 248, 50), width=2)
    draw_ltr(img, x_right - pw + 15, y_baseline - 4, ch, size, MATHC, path=DEJAVU_SI, slant=0.22)
    return x_right - pw - 14

# ============ رأس الصفحة ============
XR = 2400
draw_rtl(img, XR, 96, "معاينة تصميم — شاشة المادة العلمية", 26, BRAND2, path=SANS, bold=True)
draw_rtl(img, XR, 178, "أول فقرة من نوطة النواسات — كيف رح تطلع بالتطبيق", 52, TXT, bold=True)
draw_flow(XR, 262, [
    ("نص الأستاذ كما هو حرفا-بحرف (بدون إعادة صياغة)، المعاملات كـ ", "ar"),
    ("math runs", "la"),
    ("، والشكل من أصول النوط مباشرة.", "ar"),
], 27, TXT2)
# صف الشرائح (من اليمين)
pr = XR
pr = pill(pr, 330, "الحالة: بانتظار موافقة الأستاذ", 24, BRAND, (45, 212, 167, 100), (45, 212, 167, 16), h=64) - 28
pr = pill(pr, 330, "القسم: النواس المرن", 24, TXT2, LINE, CARD, h=64) - 28
u11 = [("الوحدة ", "ar"), ("1.1", "la"), (" من ", "ar"), ("73", "la")]
cw = sum(text_width(t, NASKH, 24) if k == "ar" else text_width(t, DEJAVU, 22) for t, k in u11)
uw = cw + 56
alpha_rect(pr - uw, 330, uw, 64, CARD, radius=32)
d.rounded_rectangle([pr - uw, 330, pr - 1, 393], radius=32, outline=_c4(LINE), width=2)
draw_flow(pr - 28, 330 + 64 - 16, u11, 24, BRAND, bold=True)
pr -= uw + 28
u1segs = [("الوحدة ", "ar"), ("U1", "la"), (" · النواسات", "ar")]
cw = sum(text_width(t, NASKH, 24) if k == "ar" else text_width(t, DEJAVU, 22) for t, k in u1segs)
uw = cw + 56
alpha_rect(pr - uw, 330, uw, 64, CARD, radius=32)
d.rounded_rectangle([pr - uw, 330, pr - 1, 393], radius=32, outline=_c4(LINE), width=2)
draw_flow(pr - 28, 330 + 64 - 16, u1segs, 24, TXT2)
pr -= uw + 28

# ============ الهاتف ============
PX, PY, PW, PH = 1600, 520, 800, 1600
shadow_card(PX, PY, PW, PH, 76, BG2, border=(29, 42, 69), blur=30)
PL, PR_ = PX + 28, PX + PW - 28   # 1628 / 2372
# شريط الحالة
draw_rtl(img, PR_, PY + 52, "٩:٤١", 22, TXT2)
bx = PL
d.rounded_rectangle([bx, PY + 30, bx + 40, PY + 50], radius=6, outline=_c4(TXT2), width=3)
d.rectangle([bx + 42, PY + 35, bx + 47, PY + 45], fill=_c4(TXT2))
d.rectangle([bx + 4, PY + 34, bx + 10, PY + 46], fill=_c4(TXT2))
# الشريط العلوي
d.line([(PX, PY + 96), (PX + PW, PY + 96)], fill=_c4(LINE), width=2)
d.rounded_rectangle([PR_ - 68, PY + 18, PR_, PY + 86], radius=18, fill=_c4(CARD), outline=_c4(LINE), width=2)
arrow_left(PR_ - 48, PY + 52, 26, TXT, wdt=6)
draw_rtl(img, PR_ - 92, PY + 46, "الاهتزازات التوافقية البسيطة", 30, TXT, bold=True)
sub_ar = "الفصل ١: النواس المرن"
sw = text_width(sub_ar, NASKH, 21)
draw_rtl(img, PR_ - 92, PY + 78, sub_ar, 21, TXT2)
ltr = "U1 ·"
lw = text_width(ltr, DEJAVU, 21, bold=True)
draw_ltr(img, PR_ - 92 - sw - lw - 14, PY + 74, ltr, 21, BRAND2, path=DEJAVU, bold=True)
# شريحة السلسلة (يسار)
sw2 = 132
alpha_rect(PL, PY + 24, sw2, 62, (251, 191, 36, 26), radius=31)
d.rounded_rectangle([PL, PY + 24, PL + sw2 - 1, PY + 85], radius=31, outline=(251, 191, 36, 90), width=2)
flame(PL + sw2 - 34, PY + 54)
draw_rtl(img, PL + sw2 - 52, PY + 66, "١٢", 26, GOLD, bold=True)

# شريط التقدم
d.line([(PX, PY + 112), (PX + PW, PY + 112)], fill=_c4(LINE), width=1)
draw_rtl(img, PR_, PY + 150, "الوحدة ١", 22, BRAND, bold=True)
d.rounded_rectangle([PL, PY + 168, PR_, PY + 178], radius=5, fill=_c4(CARD))
d.rounded_rectangle([PR_ - 16, PY + 168, PR_, PY + 178], radius=5, fill=_c4(BRAND))

# ============ الكارت 1: الفقرة ============
C1Y, C1H = PY + 208, 500
alpha_rect(PL, C1Y, PR_ - PL, C1H, CARD, radius=32)
d.rounded_rectangle([PL, C1Y, PR_, C1Y + C1H - 1], radius=32, outline=_c4(LINE), width=2)
CR = PR_ - 28
cr = CR
cr = pill(cr, C1Y + 30, "النواس المرن الغير متخامد", 21, BRAND, (45, 212, 167, 100), (45, 212, 167, 26), h=54) - 16
pill(cr, C1Y + 30, "وحدة ١", 21, TXT2, LINE, CARD2, h=54)
draw_rtl(img, CR, C1Y + 150, "تعريفه", 33, TXT, bold=True)
BODY = (219, 230, 243)
LH = 64
by = C1Y + 224
def seg_line(segs, y):
    pen = CR
    for text, kind in segs:
        if kind == "m":
            pen = math_run(pen - 8, y, text)
        else:
            w = text_width(text, NASKH, 29, kind == "b")
            draw_rtl(img, pen, y, text, 29, TXT if kind == "b" else BODY, bold=(kind == "b"))
            pen -= w
    return pen
seg_line([("هو عبارة عن نابض مرن مهمل الكتلة، حلقاته متباعدة", "n")], by); by += LH
seg_line([("ثابت صلابته ", "n"), ("k", "m"), ("، معلق فيه جسم صلب", "n")], by); by += LH
seg_line([("كتلته ", "n"), ("m", "m"), (" يمكنه أن يهتز إلى جانبي نقطة ثابتة", "n")], by); by += LH
seg_line([("تدعى ", "n"), ("مركز الاهتزاز", "b"), (" (أو موضع التوازن).", "n")], by); by += LH - 14

# ============ الكارت 2: الفقرة التالية ============
C2Y, C2H = PY + 780, 560
alpha_rect(PL, C2Y, PR_ - PL, C2H, CARD, radius=32)
dashed_rect(PL, C2Y, PR_ - PL, C2H, 32, (44, 63, 99))
draw_rtl(img, CR, C2Y + 44, "الوحدة التالية", 21, TXT2, path=SANS, bold=True)
draw_rtl(img, CR, C2Y + 96, "قوة الارجاع", 29, TXT, bold=True)
from PIL import Image as I2
fig = I2.open("/home/user/Almorshed/rebuild/nawwasat/assets/images/image2.png").convert("RGB")
fw = 520
fh = int(fig.height * fw / fig.width)
fig = fig.resize((fw, fh), I2.LANCZOS)
fx = (PL + (PR_ - PL) // 2 - fw // 2, C2Y + 118)
mask = I2.new("L", (fw, fh), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, fw - 1, fh - 1], radius=20, fill=255)
img.paste(fig, fx, mask)
d.rounded_rectangle([fx[0], fx[1], fx[0] + fw - 1, fx[1] + fh - 1], radius=20, outline=_c4(LINE), width=2)
ny = fx[1] + fh + 26
pill(CR, ny - 12, "وحدة ٢ · شكل", 20, TXT2, LINE, CARD2, h=48)
lockx = PL + 28
d.rounded_rectangle([lockx, ny - 2, lockx + 18, ny + 14], radius=4, fill=_c4(TXT2))
d.arc([lockx + 2, ny - 12, lockx + 16, ny + 2], start=180, end=0, fill=_c4(TXT2), width=3)
# (قرار ٧٣: لا توضيح آلية الاعتماد للطالب — القفل وحده يكفي)

# ============ أزرار الأسفل ============
AY = PY + PH - 150
bh = 100
gap = 24
bw = (PR_ - PL - gap) // 2
# primary (يسار)
grad = Image.new("RGB", (1, bh))
for yy in range(bh):
    t = yy / (bh - 1)
    c = (int(45 + (31 - 45) * t), int(212 + (174 - 212) * t), int(167 + (140 - 167) * t))
    grad.putpixel((0, yy), c)
grad = grad.resize((bw, bh))
m2 = Image.new("L", (bw, bh), 0)
ImageDraw.Draw(m2).rounded_rectangle([0, 0, bw - 1, bh - 1], radius=26, fill=255)
img.paste(grad, (PL, AY), m2)
tw = text_width("التالية", NASKH, 28, bold=True)
arw = 40
total = tw + 18 + arw
sx = PL + bw // 2 - total // 2 + 20
draw_rtl(img, sx + tw, AY + bh - 36, "التالية", 28, (4, 33, 26), bold=True)
arrow_left(sx, AY + bh // 2, 24, (4, 33, 26), wdt=6)
# ghost (يمين)
gx = PR_ - bw
alpha_rect(gx, AY, bw, bh, CARD, radius=26)
d.rounded_rectangle([gx, AY, gx + bw - 1, AY + bh - 1], radius=26, outline=_c4(LINE), width=2)
t3 = "فهمتها"
tw3 = text_width(t3, NASKH, 27, bold=True)
total3 = tw3 + 16 + 34
sx3 = gx + bw // 2 - total3 // 2
draw_rtl(img, sx3 + tw3, AY + bh - 35, t3, 27, TXT2, bold=True)
cx0 = sx3 - 8
d.line([(cx0 - 14, AY + bh // 2), (cx0 - 4, AY + bh // 2 + 12)], fill=_c4(TXT2), width=6)
d.line([(cx0 - 4, AY + bh // 2 + 12), (cx0 + 16, AY + bh // 2 - 14)], fill=_c4(TXT2), width=6)

# ============ لوحة الشرح ============
AX, AY2, AW, AH = 80, 520, 1440, 1600
shadow_card(AX, AY2, AW, AH, 36, CARD, border=LINE, blur=24)
ARx = AX + AW - 48
kw = text_width("وش شو في هالشاشة؟", SANS, 23, bold=True)
d.rounded_rectangle([ARx - kw - 36, AY2 + 22, ARx + 18, AY2 + 82], radius=30, fill=(18, 35, 60), outline=_c4(LINE), width=2)
draw_rtl(img, ARx, AY2 + 70, "وش شو في هالشاشة؟", 23, BRAND2, path=SANS, bold=True)
draw_rtl(img, ARx, AY2 + 156, "كل عنصر له مصدره بالخط الأنبوبي", 36, TXT, bold=True)

ITEMS = [
    ("pen", [("النص", "ar")],
     [[("حرف الأستاذ كما هو (البلوكات ٥+٦ من النوط)، الوحيد بالتعديل: رموز ", "ar"), ("R1-R14", "la")],
      [("المتفق عليها. ما في إعادة صياغة — «اعتمدها تماما متل ما هي».", "ar")]]),
    ("math", [("الرموز ", "ar"), ("k, m", "la")],
     [[("math runs", "la"), (" بـ ", "ar"), ("Material", "la"), (" ١١-ج: كشف خطي + عزل فونتي،", "ar")],
      [("بدون ", "ar"), ("MathJax", "la"), (" وبدون إنترنت (", "ar"), ("math_text.dart", "la"), (" موجود بالتطبيق).", "ar")]]),
    ("pic", [("الشكل", "ar")],
     [[("image2.png", "la"), (" (", "ar"), ("745×598", "la"), (") من أصول النوط الـ", "ar"), ("78", "la"), (" صورة؛", "ar")],
      [("معروض ", "ar"), ("1:1", "la"), (" بدون إعادة رسم، و", "ar"), ("326", "la"), (" شكلا متجهيا ستكون ", "ar"), ("SVG", "la"), (" داخل التطبيق.", "ar")]]),
    ("num", [("التسلسل", "ar")],
     [[("1565", "la"), (" فقرة قابلة للاعتماد (", "ar"), ("1916", "la"), (" بلوك − ", "ar"), ("351", "la"), (" فارغة", "ar")],
      [("تتخطى تلقائيا) على ", "ar"), ("4", "la"), (" أقسام؛ نفس تقسيم صفحة المراجعة.", "ar")]]),
    ("scale", [("بوابة الاعتماد", "ar")],
     [[("الفقرة ما «تُفعّل» بالتطبيق إلا بعد موافقة الأستاذ: تصدير ", "ar"), ("JSON", "la")],
      [("من صفحة المراجعة ", "ar"), ("←", "la"), (" ", "ar"), ("approved:true", "la"), (" ", "ar"),
       ("←", "la"), (" تدخل بـ ", "ar"), ("pack.json", "la"), (".", "ar")]]),
]
iy = AY2 + 216
for icon, title_segs, desc_lines in ITEMS:
    ix, isz = ARx - 52, 52
    alpha_rect(ix, iy, isz, isz, CARD2, radius=12)
    d.rounded_rectangle([ix, iy, ix + isz - 1, iy + isz - 1], radius=12, outline=_c4(LINE), width=2)
    ccx, ccy = ix + isz // 2, iy + isz // 2
    if icon == "pen":
        d.line([(ccx - 10, ccy + 10), (ccx + 10, ccy - 10)], fill=_c4(BRAND), width=5)
        d.ellipse([ccx + 6, ccy - 16, ccx + 15, ccy - 7], fill=_c4(BRAND))
    elif icon == "math":
        draw_ltr(img, ccx - 12, ccy + 14, "k", 30, MATHC, path=DEJAVU_SI, slant=0.22)
    elif icon == "pic":
        d.rounded_rectangle([ccx - 14, ccy - 11, ccx + 14, ccy + 11], radius=4, outline=_c4(BRAND2), width=3)
        d.ellipse([ccx - 8, ccy - 7, ccx - 2, ccy - 1], fill=_c4(BRAND2))
        d.polygon([(ccx - 10, ccy + 9), (ccx - 2, ccy - 1), (ccx + 4, ccy + 5), (ccx + 8, ccy + 1), (ccx + 12, ccy + 9)], fill=_c4(BRAND2))
    elif icon == "num":
        draw_ltr(img, ccx - 16, ccy + 12, "123", 22, BRAND2, path=DEJAVU_B)
    elif icon == "scale":
        d.line([(ccx, ccy - 14), (ccx, ccy + 12)], fill=_c4(GOLD), width=4)
        d.line([(ccx - 14, ccy - 10), (ccx + 14, ccy - 10)], fill=_c4(GOLD), width=4)
        d.arc([ccx - 20, ccy - 8, ccx - 6, ccy + 6], start=0, end=180, fill=_c4(GOLD), width=3)
        d.arc([ccx + 6, ccy - 8, ccx + 20, ccy + 6], start=0, end=180, fill=_c4(GOLD), width=3)
        d.line([(ccx - 16, ccy + 12), (ccx + 16, ccy + 12)], fill=_c4(GOLD), width=3)
    ty = iy + 6
    draw_flow(ARx - 72, ty + 40, title_segs, 27, TXT, bold=True)
    dy0 = ty + 84
    for ln in desc_lines[:3]:
        draw_flow(ARx - 72, dy0, ln, 23, TXT2)
        dy0 += 38
    iy = max(dy0 + 30, iy + 214)
    if iy < AY2 + AH - 270:
        d.line([(AX + 48, iy - 20), (ARx, iy - 20)], fill=_c4(LINE), width=2)

# صندوق التالي
hy = AY2 + AH - 150
alpha_rect(AX + 48, hy, AW - 96, 108, (45, 212, 167, 18), radius=18)
dashed_rect(AX + 48, hy, AW - 96, 108, 18, (45, 212, 167, 100))
draw_flow(ARx - 8, hy + 44, [
    ("التالي: لو المعاينة معك، أبدأ المرحلة ", "ar"), ("A", "la"),
    (" (تفريغ الفقرات للـ ", "ar"), ("pack.json", "la"), (")", "ar"),
], 24, BRAND, bold=True)
draw_flow(ARx - 8, hy + 84, [
    ("بالتوازي مع مراجعتك — أول دفعة اعتمادات توصلني، التطبيق جاهز يستقبلها.", "ar"),
], 23, TXT)

# تذييل
draw_flow(XR, H - 44, [
    ("هوية ", "ar"), ("docs/13", "la"), (" · نفس لغة ", "ar"), ("ui-mockup", "la"),
    (" · ملف واحد مستقل يعمل بلا إنترنت · ", "ar"), ("2026-10-01", "la"),
], 21, TXT2)

img.convert("RGB").save("/home/user/Almorshed/ui-mockup/nawwasat-p1-preview.png")
print("saved", img.size)
