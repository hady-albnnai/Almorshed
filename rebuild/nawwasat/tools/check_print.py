#!/usr/bin/env python3
"""check_print.py — فحص تنسيق الطباعة (NHTML-3) قبل إخراج PDF.

يقيس على محرّك Chromium مع محاكاة وسيط print وقياس A4:
  • عدد الصفحات المتوقّع (من إخراج PDF تشخيصي — لا يُعتمد كتسليم نهائي)
  • العناصر الخارجة عن عرض الصفحة أو أعلى من ارتفاع الصفحة (سبب قصّ/فقدان)
  • المعادلات التي لم تُلاءَم وتتجاوز عرض العمود المطبوع
  • لقطات لصفحات مختارة للمراجعة البصرية

يُخرج: content/print-check.json + reports/nhtml3-shots/*.png
"""
from __future__ import annotations

import argparse
import asyncio
import datetime
import json
import sys
from pathlib import Path

A4_W_MM, A4_H_MM = 210.0, 297.0
MARGIN = (18.0, 15.0, 20.0, 15.0)          # أعلى، يمين، أسفل، يسار (مم)
CONTENT_W_MM = A4_W_MM - MARGIN[1] - MARGIN[3]
CONTENT_H_MM = A4_H_MM - MARGIN[0] - MARGIN[2]
MM2PX = 96.0 / 25.4


async def run(html: Path, out_dir: Path, shots: Path, pdf_diag: Path | None):
    from playwright.async_api import async_playwright

    report = {
        "stage": "NHTML-3-print-check",
        "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "html": str(html.relative_to(html.parents[2])),
        "page": {"size_mm": [A4_W_MM, A4_H_MM], "margin_mm": MARGIN,
                 "content_mm": [round(CONTENT_W_MM, 1), round(CONTENT_H_MM, 1)]},
    }
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={"width": int(CONTENT_W_MM * MM2PX), "height": int(CONTENT_H_MM * MM2PX)})
        await pg.goto(html.as_uri(), wait_until="load")
        await pg.emulate_media(media="print")
        await pg.evaluate("async()=>{try{await document.fonts.ready}catch(e){}}")
        await pg.evaluate("()=>{ if (window.__fitMath) window.__fitMath(); }")
        await pg.wait_for_timeout(1200)

        data = await pg.evaluate("""(() => {
          const cw = document.documentElement.clientWidth;
          const ch = document.documentElement.clientHeight;
          const isAtomic = el => el.closest('.equation, figure.fig, .cluster, .table-wrapper, .cols, .li') !== null;
          const overflow = [], tall = [], wideMath = [], tooTallAtomic = [];
          document.querySelectorAll('.notebook *').forEach(el => {
            const r = el.getBoundingClientRect();
            if (!r.width && !r.height) return;
            if (r.width > cw + 1) overflow.push({tag: el.tagName, cls: (el.className||'').toString().slice(0,34),
                                                 w: Math.round(r.width), txt: (el.textContent||'').trim().slice(0, 40)});
            if (!isAtomic(el) && r.height > ch * 1.2)
              tall.push({tag: el.tagName, cls: (el.className||'').toString().slice(0,34),
                         h: Math.round(r.height), txt: (el.textContent||'').trim().slice(0, 40)});
            if (isAtomic(el) && r.height > ch * 0.95)
              tooTallAtomic.push({tag: el.tagName, cls: (el.className||'').toString().slice(0,34),
                         h: Math.round(r.height), txt: (el.textContent||'').trim().slice(0, 40)});
          });
          document.querySelectorAll('math').forEach(m => {
            const box = m.closest('.equation, .col, figure, p, td') || m.parentElement;
            if (box && m.getBoundingClientRect().width > box.clientWidth + 1)
              wideMath.push({alt: m.getAttribute('alttext') || '', mw: Math.round(m.getBoundingClientRect().width),
                             bw: Math.round(box.clientWidth), fitted: m.dataset.fitted || ''});
          });
          // الفراغات الرأسية الميتة: فجوات بين الكتل أعلى من 40mm
          const main = document.querySelector('.notebook');
          const kids = [...main.children].map(el => el.getBoundingClientRect())
                          .filter(r => r.height > 0).sort((a, b) => a.top - b.top);
          const minGap = 40 * 3.7795;   // 40mm بالبكسل
          const gaps = [];
          for (let i = 1; i < kids.length; i++) {
            const g = kids[i].top - kids[i-1].bottom;
            if (g > minGap) gaps.push({afterIndex: i, px: Math.round(g),
                                       mm: Math.round(g / 3.7795),
                                       before: (main.children[i-1].className||'').toString().slice(0,30),
                                       after: (main.children[i].className||'').toString().slice(0,30)});
          }
          const cs = getComputedStyle(document.querySelector('.notebook'));
          return { contentWidthPx: cw, contentHeightPx: ch, notebookWidth: Math.round(cs.width),
                   docHeightPx: document.body.scrollHeight,
                   counts: { math: document.querySelectorAll('math').length,
                             equations: document.querySelectorAll('.equation').length,
                             figures: document.querySelectorAll('figure.fig').length,
                             images: document.querySelectorAll('img').length,
                             questions: document.querySelectorAll('.question').length,
                             clusters: document.querySelectorAll('.cluster').length,
                             cols: document.querySelectorAll('.cols').length,
                             tables: document.querySelectorAll('table').length,
                             footerVisible: !!document.querySelector('.doc-footer') &&
                                             getComputedStyle(document.querySelector('.doc-footer')).display !== 'none' },
                   overflow: overflow.slice(0, 25), overflowTotal: overflow.length,
                   tallBlocks: tall.slice(0, 15), tallTotal: tall.length,
                   wideMath: wideMath.slice(0, 20), wideMathTotal: wideMath.length,
                   tooTallAtomic: tooTallAtomic.slice(0, 12), tooTallAtomicTotal: tooTallAtomic.length,
                   deadGaps: gaps.slice(0, 15), deadGapsTotal: gaps.length,
                   deadGapsPxTotal: gaps.reduce((s, g) => s + g.px, 0) };
        })()""")

        report.update(data)
        est_pages = data["docHeightPx"] / data["contentHeightPx"]
        report["estimated_pages_by_height"] = round(est_pages, 1)

        # لقطات لمواضع مختارة (عرض عمود المحتوى المطبوع)
        shots.mkdir(parents=True, exist_ok=True)
        picks = [("01-start", "body"), ("02-question", ".question"),
                 ("03-cluster", ".cluster"), ("04-table", ".table-wrapper"),
                 ("05-cols", ".cols-4"), ("06-greenbars", "math")]
        for name, sel in picks:
            y = await pg.evaluate(
                "s=>{const e=document.querySelector(s);return e?Math.max(0,e.getBoundingClientRect().top+window.scrollY-20):-1}", sel)
            if y < 0:
                continue
            await pg.evaluate("y=>window.scrollTo(0,y)", y)
            await pg.wait_for_timeout(250)
            await pg.screenshot(path=str(shots / f"{name}.png"),
                                clip={"x": 0, "y": 0, "width": int(data["contentWidthPx"]),
                                      "height": int(data["contentHeightPx"])})

        if pdf_diag:
            footer_tpl = ('<div style="width:100%;font:8.4pt sans-serif;color:#4a5560;'
                          'text-align:center;"><span class="pageNumber"></span></div>')
            await pg.pdf(path=str(pdf_diag), format="A4", print_background=True,
                         prefer_css_page_size=True, display_header_footer=True,
                         header_template="<div></div>", footer_template=footer_tpl)
            try:
                from pypdf import PdfReader
                report["pdf_diagnostic_pages"] = len(PdfReader(str(pdf_diag)).pages)
            except Exception:
                report["pdf_diagnostic_pages"] = None
        await b.close()

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "print-check.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("contentWidthPx", "contentHeightPx", "docHeightPx",
                                             "estimated_pages_by_height", "pdf_diagnostic_pages",
                                             "overflowTotal", "tallTotal", "tooTallAtomicTotal",
                                             "wideMathTotal", "deadGapsTotal", "deadGapsPxTotal") },
                     ensure_ascii=False, indent=1))
    print("counts:", json.dumps(data["counts"], ensure_ascii=False))
    if data["overflow"]:
        print("تجاوز العرض (أعلى 5):")
        for o in data["overflow"][:5]:
            print("   ", o)
    if data["wideMath"]:
        print("معادلات أوسع من حاويتها (أعلى 5):")
        for o in data["wideMath"][:5]:
            print("   ", o)
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--html", default="rebuild/nawwasat/html/index.html")
    ap.add_argument("--pdf-diag", default="rebuild/nawwasat/pdf/_nhtml3-diagnostic.pdf")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    out = repo / "rebuild" / "nawwasat"
    pdf_diag = repo / args.pdf_diag
    pdf_diag.parent.mkdir(parents=True, exist_ok=True)
    rc = asyncio.run(run(repo / args.html, out / "content", out / "reports" / "nhtml3-shots", pdf_diag))
    fails = [k for k in ("overflowTotal", "wideMathTotal") if rc.get(k)]
    print(("⚠️ يحتاج معالجة: " + ", ".join(fails)) if fails else "✅ لا قصّ ولا تجاوز أفقياً")


if __name__ == "__main__":
    main()
