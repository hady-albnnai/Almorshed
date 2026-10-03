# مكوّن رسم نصي: uharfbuzz (تشكيل) + freetype-py (رسم) + PIL
# العربي: buffer بالترتيب البصري (يسار→يمين) → نعكسه ونرسم من اليمين
# العريض: وزن متغيّر حقيقي (wght) على الطرفين (hb + FT)
#
# قاعدة التغطية (إلزامية لكل الوحدات — Noto Naskh ثابت non-hinted):
#   "ar" (Naskh): يحوي العربية + الأرقام 0-9 + ":" و "." فقط.
#   أي حرف لاتيني (a-z) أو رمز ( = + - ( ) / ± ½ ² ω π …) لا يرسم في Naskh (يظهر ▯).
#   → كل رمز غير عربي/رقم يجب أن يكون في مقطع "la" (DejaVu).
#   "la" (DejaVu): لا يحوي العربية إطلاقًا → لا تضع عربيًا داخل مقطع "la".
#   للتحقق قبل أي تقديم: python3 ui-mockup/scan_segs.py <ملف_الوحدة>.py
import os
import uharfbuzz as hb
import freetype
from PIL import Image

_FDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
NASKH = os.path.join(_FDIR, "NotoNaskhArabic-Regular.ttf")  # ثابت (نسخة notofonts)
NASKH_B = os.path.join(_FDIR, "NotoNaskhArabic-Bold.ttf")
SANS = os.path.join(_FDIR, "NotoSansArabic.ttf")            # متغيّر (wght, wdth)
DEJAVU = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
DEJAVU_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
DEJAVU_SI = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"

# للعريض: إحداثيات تصميم (خطوط متغيرة) أو ملف عريض (خطوط ثابتة)
_BOLD_COORDS = {SANS: [700.0, 100.0]}
_BOLD_FILE = {NASKH: NASKH_B}

_fonts = {}
def _get(path, size, bold=False):
    key = (path, size, bold)
    if key not in _fonts:
        fpath = _BOLD_FILE.get(path, path) if bold else path
        f = hb.Font(hb.Face(open(fpath, "rb").read()))
        f.scale = (size * 64, size * 64)
        if bold and path in _BOLD_COORDS:
            f.set_var_coords_design(_BOLD_COORDS[path])
        ft = freetype.Face(fpath)
        ft.set_pixel_sizes(0, size)
        if bold and path in _BOLD_COORDS:
            ft.set_var_design_coords(_BOLD_COORDS[path])
        _fonts[key] = (f, ft)
    return _fonts[key]

def text_width(text, path, size, bold=False):
    f, _ = _get(path, size, bold)
    buf = hb.Buffer(); buf.add_str(text); buf.guess_segment_properties()
    hb.shape(f, buf)
    return abs(sum(p.x_advance for p in buf.glyph_positions)) // 64

def _norm(fill):
    return fill if len(fill) == 4 else fill + (255,)

def _render(ft, img, pen, y_baseline, gid, fill, slant=0.0, ox=0, oy=0):
    ft.load_glyph(gid, freetype.FT_LOAD_RENDER)
    bm = ft.glyph.bitmap
    if bm.width == 0 or bm.rows == 0:
        return
    w, h = bm.width, bm.rows
    bufd = bytes(bm.buffer[:bm.pitch * bm.rows])
    rows = [bufd[r * bm.pitch:(r + 1) * bm.pitch] for r in range(bm.rows)]
    m = Image.frombytes("L", (w, h), b"".join(rows))
    layer = Image.new("RGBA", (w, h), fill)
    layer.putalpha(m)
    if slant:
        pad = int(abs(slant) * h) + 2
        big = Image.new("RGBA", (w + pad * 2, h), (0, 0, 0, 0))
        big.alpha_composite(layer, (pad, 0))
        big = big.transform((w + pad * 2, h), Image.AFFINE, (1, slant, -slant * h / 2, 0, 1, 0), resample=Image.BICUBIC)
        layer = big.crop((pad, 0, pad + w, h))
    img.alpha_composite(layer, (pen - ft.glyph.bitmap_left + ox, y_baseline - ft.glyph.bitmap_top + oy))

def draw_rtl(img, x_right, y_baseline, text, size, fill, path=NASKH, bold=False, slant=0.0):
    f, ft = _get(path, size, bold)
    fill = _norm(fill)
    buf = hb.Buffer(); buf.add_str(text); buf.guess_segment_properties()
    hb.shape(f, buf)
    gs = [g.codepoint for g in buf.glyph_infos][::-1]
    pos = [p.x_advance for p in buf.glyph_positions][::-1]
    xo = [p.x_offset for p in buf.glyph_positions][::-1]
    yo = [p.y_offset for p in buf.glyph_positions][::-1]
    pen = x_right
    for i, gid in enumerate(gs):
        pen -= pos[i] >> 6
        _render(ft, img, pen + (xo[i] >> 6), y_baseline, gid, fill, slant, oy=-(yo[i] >> 6))
    return pen

def draw_ltr(img, x_left, y_baseline, text, size, fill, path=DEJAVU, bold=False, slant=0.0):
    f, ft = _get(path, size, bold)
    fill = _norm(fill)
    buf = hb.Buffer(); buf.add_str(text); buf.guess_segment_properties()
    hb.shape(f, buf)
    gs = [g.codepoint for g in buf.glyph_infos]
    pos = [p.x_advance for p in buf.glyph_positions]
    xo = [p.x_offset for p in buf.glyph_positions]
    yo = [p.y_offset for p in buf.glyph_positions]
    pen = x_left
    for i, gid in enumerate(gs):
        _render(ft, img, pen + (xo[i] >> 6), y_baseline, gid, fill, slant, oy=-(yo[i] >> 6))
        pen += pos[i] >> 6
    return pen

def wrap_rtl(text, path, size, max_w, bold=False):
    words = text.split(" ")
    lines, cur = [], ""
    for w in reversed(words):
        cand = (cur + " " + w) if cur else w
        if text_width(cand, path, size, bold) <= max_w:
            cur = cand
        else:
            if cur: lines.append(cur)
            cur = w
    if cur: lines.append(cur)
    return lines
