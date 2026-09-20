#!/usr/bin/env python3
"""make_pdf.py — إخراج النوطة PDF من HTML (NHTML-4).

المسار: Chromium (Playwright) → انتظار الخطوط والصور كاملةً → ملاءمة المعادلات (window.__fitMath)
        → page.pdf(A4 · printBackground · preferCSSPageSize) مع قالب تذييل فيه سطر الأستاذ حرفياً
        (بخطّ عربي مضمَّن base64، لأنّ قالب التذييل مستند منفصل) + رقم الصفحة.

لا لقطات شاشة بديلاً عن PDF (شرط إعادة البناء).

المخرجات: pdf/نوطة-النواسات.pdf · content/pdf-check.json · reports/nhtml4-shots/*.png
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import datetime
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# منطقة المحتوى في A4 مع هوامش 15/20مم (بالنسبة إلى 96dpi): 180مم × 259مم
A4_CONTENT_PX = (round(180 / 25.4 * 96), round(259 / 25.4 * 96))      # ≈ (680, 979)


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def footer_template(footer_text: str, font_file: Path) -> str:
    """قالب تذييل Chromium: سطر الأستاذ حرفياً + رقم الصفحة، بخطّ عربي مضمَّن."""
    b64 = base64.b64encode(font_file.read_bytes()).decode("ascii")
    safe = (footer_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
    return f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    @font-face {{ font-family: 'NNA'; src: url(data:font/ttf;base64,{b64}) format('truetype'); }}
    * {{ -webkit-print-color-adjust: exact; }}
    .wrap {{ width: 100%; font-family: 'NNA', 'Times New Roman', serif; font-size: 8.6pt;
             line-height: 1.35; color: #46515c; text-align: center; direction: rtl; }}
    .line {{ white-space: pre; }}
    .num  {{ font-family: 'Times New Roman', serif; font-size: 9pt; color: #66727e; }}
    </style></head><body><div class="wrap">
      <div class="line">{safe}</div>
      <div class="num"><span class="pageNumber"></span></div>
    </div></body></html>"""


async def build(html: Path, pdf_out: Path, shots: Path, footer_text: str, font_file: Path):
    from playwright.async_api import async_playwright

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # المقاس = منطقة المحتوى الفعلية في PDF، وإلا اختلف التخطيط عن القياس واكتُشف القصّ متأخراً
        page = await browser.new_page(viewport={"width": A4_CONTENT_PX[0], "height": A4_CONTENT_PX[1]})
        await page.goto(html.as_uri(), wait_until="load")

        # 1) الخطوط
        await page.evaluate("async()=>{try{await document.fonts.ready}catch(e){}}")
        # 2) الصور كاملة (بلا lazy loading)
        await page.wait_for_function(
            "() => [...document.images].every(i => i.complete && i.naturalWidth > 0)",
            timeout=120000)
        # 3) ملاءمة المعادلات والجداول على هندسة الطباعة — مرّتان:
        #    الأولى بعد الخطوط، والثانية بعد استقرار تخطيط MathML (وإلا قِيست الجداول صغيرة)
        await page.emulate_media(media="print")
        await page.evaluate("()=>{ if (window.__fitMath) window.__fitMath(); }")
        await page.wait_for_timeout(900)
        await page.evaluate("()=>{ if (window.__fitMath) window.__fitMath(); }")
        await page.wait_for_timeout(900)

        stats = await page.evaluate("""() => ({
            imgs: document.images.length,
            imgs_loaded: [...document.images].filter(i => i.complete && i.naturalWidth > 0).length,
            maths: document.querySelectorAll('math').length,
            equations: document.querySelectorAll('.equation').length,
            figures: document.querySelectorAll('figure.fig').length,
            fitted: document.querySelectorAll('math[data-fitted]').length,
            font: getComputedStyle(document.body).fontFamily,
            tables_fitted: document.querySelectorAll('table.data-table[data-fitted]').length,
            wide_tables: [...document.querySelectorAll('table.data-table')].filter(t => {
                const b = t.parentElement;
                return b && t.getBoundingClientRect().width > b.clientWidth + 1;
            }).length,
            clipped: [...document.querySelectorAll('.notebook *')].filter(el =>
                el.scrollWidth > el.clientWidth + 2 && el.clientWidth > 0 &&
                ['auto','scroll','hidden'].includes(getComputedStyle(el).overflowX)).length,
            overWide: [...document.querySelectorAll('math')].filter(m => {
                const b = m.closest('.equation, .col, figure, p, td') || m.parentElement;
                return b && m.getBoundingClientRect().width > b.clientWidth + 1;
            }).length,
        })""")

        pdf_out.parent.mkdir(parents=True, exist_ok=True)
        await page.pdf(
            path=str(pdf_out),
            format="A4",
            print_background=True,
            prefer_css_page_size=True,
            display_header_footer=True,
            header_template="<div></div>",
            footer_template=footer_template(footer_text, font_file),
        )

        # لقطات صفحات للمسح البصري (NHTML-5)
        shots.mkdir(parents=True, exist_ok=True)
        for name, sel in (("01-start", "body"), ("02-equation", ".equation"),
                          ("03-figure", "figure.fig"), ("04-question", ".question"),
                          ("05-table", ".table-wrapper")):
            y = await page.evaluate(
                "s=>{const e=document.querySelector(s);return e?Math.max(0,e.getBoundingClientRect().top+window.scrollY-10):-1}", sel)
            if y < 0:
                continue
            await page.evaluate("y=>window.scrollTo(0,y)", y)
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(shots / f"{name}.png"), full_page=False)

        await browser.close()
    return stats


def inspect(pdf_path: Path, footer_text: str) -> dict:
    """فحص PDF: صفحات · قياس · صور · تذييل · صفحات فارغة · نصّ المعادلات."""
    import pymupdf
    doc = pymupdf.open(pdf_path)
    n = doc.page_count
    dims = set()
    images_per_page, text_lens, footer_pages, blank_pages, eq_hits = [], [], 0, [], 0
    margin_pt = {"left": 15 * 72 / 25.4, "right": 15 * 72 / 25.4,
                 "top": 18 * 72 / 25.4, "bottom": 20 * 72 / 25.4}
    clipped_pages = []
    for i, page in enumerate(doc):
        r = page.rect
        minx, maxx, miny, maxy = 1e9, -1e9, 1e9, -1e9
        for dr in page.get_drawings():
            b = dr["rect"]
            minx, maxx = min(minx, b.x0), max(maxx, b.x1)
            miny, maxy = min(miny, b.y0), max(maxy, b.y1)
        if minx > 1e8:
            continue
        # التذييل يُرسم داخل الهامش السفلي (قالب Chromium) ويُستثنى
        over = (minx < margin_pt["left"] - 3) or (maxx > r.width - margin_pt["right"] + 3) \
               or (miny < margin_pt["top"] - 3) or (maxy > r.height - margin_pt["bottom"] + 8)
        if over:
            clipped_pages.append({"page": i + 1,
                                  "x_mm": [round(minx / 72 * 25.4, 1), round(maxx / 72 * 25.4, 1)],
                                  "y_mm": [round(miny / 72 * 25.4, 1), round(maxy / 72 * 25.4, 1)]})
    dark_fills = []
    for i, page in enumerate(doc):
        for dr in page.get_drawings():
            f = dr.get("fill")
            r = dr["rect"]
            if f and sum(f) / 3 < 0.5 and r.width * r.height > 100000:   # مساحة داكنة ضخمة = عيب رسم
                dark_fills.append({"page": i + 1, "w": round(r.width), "h": round(r.height),
                                   "fill": [round(c, 3) for c in f]})
    m = re.search(r"0\d{8,}", footer_text)          # رقم هاتف الأستاذ في السطر
    digits = m.group(0) if m else re.sub(r"\D", "", footer_text)
    for i, page in enumerate(doc):
        r = page.rect
        dims.add((round(r.width / 72 * 25.4, 1), round(r.height / 72 * 25.4, 1)))
        imgs = page.get_images(full=True)
        images_per_page.append(len(imgs))
        txt = page.get_text()
        text_lens.append(len(txt.strip()))
        if digits and digits in txt.replace(" ", ""):
            footer_pages += 1
        if len(txt.strip()) < 12 and not imgs:
            blank_pages.append(i + 1)
        eq_hits += len(re.findall(r"[Xx]maX|maX", txt))
    # الخطوط المضمّنة
    fonts = set()
    for i in range(min(n, 12)):
        for f in doc[i].get_fonts(full=True):
            fonts.add(f[3])
    meta = dict(doc.metadata or {})
    doc.close()
    return {
        "pages": n,
        "page_dimensions_mm": sorted(dims),
        "images_total_placements": sum(images_per_page),
        "pages_with_images": sum(1 for x in images_per_page if x),
        "footer_pages": footer_pages,
        "blank_pages": blank_pages,
        "text_chars_total": sum(text_lens),
        "min_text_chars_on_page": min(text_lens) if text_lens else 0,
        "equation_text_hits": eq_hits,
        "content_outside_margins": clipped_pages[:12],
        "content_outside_margins_total": len(clipped_pages),
        "dark_large_fills": dark_fills[:10],
        "dark_large_fills_total": len(dark_fills),
        "fonts_seen_first_pages": sorted(fonts),
        "pdf_metadata": {k: meta.get(k) for k in ("title", "author", "producer", "creator")},
        "bytes": pdf_path.stat().st_size,
        "sha256": sha256(pdf_path),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--name", default="نوطة-النواسات.pdf")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    out = repo / "rebuild" / "nawwasat"
    html = out / "html" / "index.html"
    pdf_out = out / "pdf" / args.name
    shots = out / "reports" / "nhtml4-shots"
    structure = json.loads((out / "content" / "structure.json").read_text(encoding="utf-8"))
    footer_text = structure.get("footer_text", "")
    font_file = out / "assets" / "fonts" / "NotoNaskhArabic.ttf"

    stats = asyncio.run(build(html, pdf_out, shots, footer_text, font_file))
    info = inspect(pdf_out, footer_text)
    report = {
        "stage": "NHTML-4",
        "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source_sha256": structure.get("source_sha256"),
        "html": "rebuild/nawwasat/html/index.html",
        "pdf": str(pdf_out.relative_to(repo)),
        "footer_text": footer_text,
        "browser_side": stats,
        "pdf_side": info,
    }
    (out / "content" / "pdf-check.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    if info.get("content_outside_margins_total"):
        print("⛔ صفحات فيها محتوى خارج الهوامش (قصّ محتمل):", info["content_outside_margins"][:5])
    if info.get("dark_large_fills_total"):
        print("⛔ أشكال داكنة ضخمة (عيب رسم):", info["dark_large_fills"][:4])
    print(json.dumps({"pdf": report["pdf"], "pages": info["pages"], "size_mb": round(info["bytes"]/1024/1024, 2),
                      "dims": info["page_dimensions_mm"], "images": info["images_total_placements"],
                      "footer_pages": info["footer_pages"], "blank_pages": info["blank_pages"],
                      "eq_text_hits": info["equation_text_hits"],
                      "overWide_math": stats["overWide"], "imgs_loaded": f"{stats['imgs_loaded']}/{stats['imgs']}"},
                     ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
