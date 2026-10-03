# -*- coding: utf-8 -*-
"""مساعدة مشتركة لرسم صور مراجعة الوحدات (هوية docs/13)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from rtl_text import (draw_rtl, draw_ltr, text_width, wrap_rtl,
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

def _c4(c):
    return c if len(c) == 4 else c + (255,)

class ReviewCanvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), BG + (255,))
        self.d = ImageDraw.Draw(self.img)

    # ---------- مساحات ----------
    def alpha_rect(self, x, y, w, h, fill, radius=0):
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dd = ImageDraw.Draw(layer)
        dd.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=_c4(fill))
        self.img.alpha_composite(layer, (x, y))

    def a_rounded(self, x1, y1, x2, y2, radius, fill=None, outline=None, width=2):
        pad = 12
        layer = Image.new("RGBA", (x2 - x1 + pad * 2, y2 - y1 + pad * 2), (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        dl.rounded_rectangle([pad, pad, pad + (x2 - x1) - 1, pad + (y2 - y1) - 1], radius=radius,
                             fill=_c4(fill) if fill else None, outline=_c4(outline) if outline else None, width=width)
        self.img.alpha_composite(layer, (x1 - pad, y1 - pad))

    def a_ellipse(self, x1, y1, x2, y2, fill=None, outline=None, width=2):
        pad = 12
        layer = Image.new("RGBA", (x2 - x1 + pad * 2, y2 - y1 + pad * 2), (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        dl.ellipse([pad, pad, pad + (x2 - x1) - 1, pad + (y2 - y1) - 1],
                   fill=_c4(fill) if fill else None, outline=_c4(outline) if outline else None, width=width)
        self.img.alpha_composite(layer, (x1 - pad, y1 - pad))

    def card(self, x, y, w, h, radius, fill, border=None, bw=2, shadow=True, blur=22, dy=12):
        if shadow:
            sh = Image.new("RGBA", (w + blur * 2, h + blur * 2 + dy), (0, 0, 0, 0))
            ds = ImageDraw.Draw(sh)
            ds.rounded_rectangle([blur, blur + dy, blur + w - 1, blur + h - 1 + dy], radius=radius, fill=(0, 0, 0, 110))
            sh = sh.filter(ImageFilter.GaussianBlur(blur / 2))
            self.img.alpha_composite(sh, (x - blur, y - blur))
        self.alpha_rect(x, y, w, h, fill, radius)
        if border:
            self.d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=radius, outline=_c4(border), width=bw)

    # ---------- خط ----------
    def draw_flow(self, x_right, y_baseline, segs, size, fill, bold=False):
        """segs: [(text, 'ar'|'la')] من اليمين"""
        pen = x_right
        for text, kind in segs:
            if kind == "ar":
                w = text_width(text, NASKH, size, bold)
                draw_rtl(self.img, pen, y_baseline, text, size, fill, bold=bold)
                pen -= w
            else:
                ls = int(size * 0.9)
                w = text_width(text, DEJAVU, ls, bold)
                draw_ltr(self.img, pen - w, y_baseline - 2, text, ls, fill, path=DEJAVU, bold=bold)
                pen -= w
        return pen

    def flow_width(self, segs, size, bold=False):
        return sum(text_width(t, NASKH, size, bold) if k == "ar" else text_width(t, DEJAVU, int(size * 0.9), bold) for t, k in segs)

    def math_run(self, x_right, y_baseline, ch, size=26):
        cw = text_width(ch, DEJAVU_SI, size)
        pw, ph = cw + 24, 40
        self.alpha_rect(x_right - pw, y_baseline - 28, pw, ph, (56, 189, 248, 22), radius=9)
        self.d.rounded_rectangle([x_right - pw, y_baseline - 28, x_right - 1, y_baseline - 28 + ph - 1], radius=9,
                                 outline=(56, 189, 248, 50), width=2)
        draw_ltr(self.img, x_right - pw + 12, y_baseline - 3, ch, size, MATHC, path=DEJAVU_SI, slant=0.22)
        return x_right - pw - 10

    def math_line(self, x_right, y_baseline, text, size=22, fill=MATHC):
        """سطر معادلات كامل (LTR) مائل"""
        w = text_width(text, DEJAVU_SI, size)
        draw_ltr(self.img, x_right - w, y_baseline, text, size, fill, path=DEJAVU_SI, slant=0.22)
        return x_right - w

    # ---------- عناصر ----------
    def arrow_l(self, x, y, size, color, wdt=5):
        self.d.line([(x, y), (x + size, y)], fill=_c4(color), width=wdt)
        self.d.line([(x, y), (x + size * 0.4, y - size * 0.45)], fill=_c4(color), width=wdt)
        self.d.line([(x, y), (x + size * 0.4, y + size * 0.45)], fill=_c4(color), width=wdt)

    def check(self, x, y, s, color, wdt=5):
        self.d.line([(x - s, y), (x - s * 0.25, y + s * 0.8)], fill=_c4(color), width=wdt)
        self.d.line([(x - s * 0.25, y + s * 0.8), (x + s, y - s * 0.7)], fill=_c4(color), width=wdt)

    def refresh(self, x, y, r, color, wdt=4):
        self.d.arc([x - r, y - r, x + r, y + r], start=40, end=330, fill=_c4(color), width=wdt)
        ax, ay = x + r * 0.766, y - r * 0.643
        self.d.polygon([(ax, ay - 7), (ax + 11, ay + 2), (ax - 7, ay + 7)], fill=_c4(color))

    def spring(self, x_top, y_top, y_bot, coils, amp, color, wdt=6):
        n = coils * 2
        dy = (y_bot - y_top) / n
        pts = [(x_top, y_top)]
        for i in range(1, n):
            pts.append((x_top + (amp if i % 2 == 1 else -amp), y_top + dy * i))
        pts.append((x_top, y_bot))
        self.d.line(pts, fill=_c4(color), width=wdt, joint="curve")

    def ceiling(self, x, y, w, color):
        self.d.line([(x, y), (x + w, y)], fill=_c4(color), width=5)
        for i in range(0, w, 16):
            self.d.line([(x + i, y), (x + i - 10, y - 12)], fill=_c4(color), width=3)

    def pill_r(self, x_right, y, text, tsize, tcolor, bcolor, bg, padx=22, h=48):
        tw = text_width(text, NASKH, tsize, True)
        w = tw + padx * 2
        self.alpha_rect(x_right - w, y, w, h, bg, radius=h // 2)
        self.d.rounded_rectangle([x_right - w, y, x_right - 1, y + h - 1], radius=h // 2, outline=_c4(bcolor), width=2)
        draw_rtl(self.img, x_right - padx, y + h - 14, text, tsize, tcolor, bold=True)
        return x_right - w

    def phone(self, x, y, w, h, title, sub="الوحدة 1.2 · النواس المرن"):
        self.card(x, y, w, h, 56, BG2, border=(29, 42, 69))
        pl, pr = x + 24, x + w - 24
        self.d.line([(x, y + 78), (x + w, y + 78)], fill=_c4(LINE), width=2)
        self.d.rounded_rectangle([pr - 54, y + 14, pr, y + 66], radius=15, fill=_c4(CARD), outline=_c4(LINE), width=2)
        self.arrow_l(pr - 40, y + 40, 20, TXT, wdt=5)
        draw_rtl(self.img, pr - 74, y + 40, title, 25, TXT, bold=True)
        draw_rtl(self.img, pr - 74, y + 68, sub, 16, TXT2, path=SANS)
        return pl, pr

    def bottom_bar(self, x, y, w):
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
        self.img.paste(grad, (pl, y), m)
        tw = text_width("التالية", NASKH, 23, True)
        total = tw + 14 + 30
        sx = pl + bw // 2 - total // 2 + 14
        draw_rtl(self.img, sx + tw, y + bh - 28, "التالية", 23, DARKBTN, bold=True)
        self.arrow_l(sx, y + bh // 2, 18, DARKBTN, wdt=5)
        gx = pr - bw
        self.alpha_rect(gx, y, bw, bh, CARD, radius=20)
        self.d.rounded_rectangle([gx, y, gx + bw - 1, y + bh - 1], radius=20, outline=_c4(LINE), width=2)
        t3, tw3 = "فهمتها", text_width("فهمتها", NASKH, 22, True)
        total3 = tw3 + 12 + 26
        sx3 = gx + bw // 2 - total3 // 2
        draw_rtl(self.img, sx3 + tw3, y + bh - 28, t3, 22, TXT2, bold=True)
        self.check(sx3 - 3, y + bh // 2 - 1, 11, TXT2, wdt=4)

    def number_badge(self, x, y, num, color):
        self.a_ellipse(x, y, x + 36, y + 36, fill=color[:3] + (40,), outline=color + (255,), width=2)
        nw = text_width(str(num), DEJAVU, 20, True)
        draw_ltr(self.img, x + 18 - nw // 2, y + 28, str(num), 20, TXT, path=DEJAVU, bold=True)

    def save(self, path, small_w=1400):
        self.img.convert("RGB").save(path)
        base = path.rsplit(".", 1)[0]
        self.img.resize((small_w, int(self.img.size[1] * small_w / self.img.size[0])), Image.LANCZOS).save(
            f"{base}-{small_w}.png", optimize=True)
        print("saved", self.img.size, "->", path)
