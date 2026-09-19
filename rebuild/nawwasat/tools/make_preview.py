#!/usr/bin/env python3
"""ينتج ملف معاينة واحداً قائماً بذاته (html/preview-nhtml2.html) لعرضه في المتصفح/المعاينة:
   • CSS مضمّن inline، • الخطوط العربية base64، • الصور base64 — بلا أي طلب شبكي.
   canonical: html/index.html (يُستخدم في NHTML-3/4 لإخراج PDF).
"""
from __future__ import annotations

import base64
import mimetypes
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "rebuild" / "nawwasat"
HTML = OUT / "html" / "index.html"
CSS = OUT / "html" / "styles.css"
JS = OUT / "html" / "fit-math.js"
IMAGES = OUT / "assets" / "images"
FONTS = OUT / "assets" / "fonts"
DEST = OUT / "html" / "preview-nhtml2.html"
DEST_LITE = OUT / "html" / "preview-lite.html"
LITE_MAX_W = 620
LITE_Q = 72


def data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def lite_uri(path: Path, max_w: int = LITE_MAX_W, q: int = LITE_Q) -> str:
    """نسخة مصغَّرة للمعاينة فقط (لا تمسّ الأصول): تُعاد كـ data URI."""
    import io
    from PIL import Image
    im = Image.open(path)
    if im.width > max_w:
        im = im.resize((max_w, max(1, round(im.height * max_w / im.width))), Image.LANCZOS)
    buf = io.BytesIO()
    if im.mode in ("RGBA", "LA", "P"):
        # الرسوم خلفيتها بيضاء: تُسطَّح على أبيض كي تنضغط JPEG (معاينة فقط)
        rgba = im.convert("RGBA")
        flat = Image.new("RGB", rgba.size, "white")
        flat.paste(rgba, mask=rgba.split()[-1])
        im = flat
    im.convert("RGB").save(buf, "JPEG", quality=q, optimize=True, progressive=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def build(html_path: Path, dest: Path, lite: bool):
    html = HTML.read_text(encoding="utf-8")
    css = CSS.read_text(encoding="utf-8")
    js = JS.read_text(encoding="utf-8")

    # الخطوط: تُستبدل مساراتها بمحتوى base64
    for font in FONTS.glob("*.ttf"):
        uri = data_uri(font)
        css = css.replace(f'url("../assets/fonts/{font.name}")', f'url("{uri}")')
        css = css.replace(f"url('../assets/fonts/{font.name}')", f'url("{uri}")')

    # الصور: مسار نسبي ⇒ data URI
    def img_sub(m):
        rel = m.group(1)
        p = (OUT / "html" / rel).resolve()
        if not p.exists():
            p = (OUT / rel).resolve()
        if not p.exists():
            return m.group(0)
        return 'src="' + (lite_uri(p) if lite else data_uri(p)) + '"'

    n_imgs = len(re.findall(r'src="\.\./assets/images/[^"]+"', html))
    html = re.sub(r'src="(\.\./assets/images/[^"]+)"', img_sub, html)

    # CSS + JS مضمّنان، وحذف وسوم <link>
    html = re.sub(r'\s*<link rel="stylesheet"[^>]*>', "", html)
    html = html.replace(
        "<title>", "<style>\n" + css + "\n</style>\n<style id=\"preview-note\">"
        "body{background:#eef1f4}</style>\n<title>", 1)
    html = html.replace("</body>", "<script>\n" + js + "\n</script>\n</body>")

    dest.write_text(html, encoding="utf-8")
    print(f"{'lite preview' if lite else 'preview'}: {dest} "
          f"({dest.stat().st_size/1024/1024:.2f} MB) · صور مضمّنة: {n_imgs}"
          f" · خطوط: {len(list(FONTS.glob('*.ttf')))}")


def main():
    build(HTML, DEST, lite=False)
    build(HTML, DEST_LITE, lite=True)


if __name__ == "__main__":
    main()
