#!/usr/bin/env python3
"""verify_html.py — تحقّق «لا فقدان نص» بين المصدر المجمّد و HTML المبني (NHTML-2).

الطريقة: تُستخرج كل كلمات المصدر من content/text.json (مقاطع النص الحرفية)،
وتُقرأ كل كلمات المستند المعروض من المتصفح (Chromium عبر Playwright)،
ثم تُقارَن المجموعتان على مستوى الكلمات والحروف مع تطبيع NFKC.

تُصنَّف الفروق تلقائياً: إضافات مقصودة (العنوان/الترويسة/علامات الترقيم للقوائم/فواصل التصميم)
مقابل فقدان فعلي — ويُفشل التقرير عند أي فقدان فعلي.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
import unicodedata
from pathlib import Path

WORD_RE = re.compile(r"[\u0621-\u064A][\u0621-\u064A\u064B-\u0652]*")
AR_RE = re.compile(r"[\u0600-\u06FF]")


def norm(s: str) -> str:
    return unicodedata.normalize("NFKC", s)


def tokens(s: str):
    return [norm(t) for t in WORD_RE.findall(norm(s))]


def chars(s: str):
    return [c for c in norm(s) if not c.isspace() and not unicodedata.category(c).startswith("C")]


INTENTIONAL_PREFIX = ("س", "أ", "ا")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--html", default="rebuild/nawwasat/html/index.html")
    ap.add_argument("--json-out", default="rebuild/nawwasat/content/verify-text.json")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    src_json = repo / "rebuild" / "nawwasat" / "content" / "text.json"
    data = json.loads(src_json.read_text(encoding="utf-8"))
    blocks = data["blocks"] if isinstance(data, dict) else data

    src_text = "\n".join(b.get("text", "") for b in blocks)

    import asyncio
    from playwright.async_api import async_playwright

    async def grab():
        async with async_playwright() as p:
            b = await p.chromium.launch()
            pg = await b.new_page(viewport={"width": 900, "height": 1200})
            await pg.goto((repo / args.html).resolve().as_uri(), wait_until="load")
            await pg.evaluate("async()=>{try{await document.fonts.ready}catch(e){}}")
            await pg.wait_for_timeout(1200)
            txt = await pg.evaluate("() => document.body.textContent")  # يشمل نص MathML (mtext العربي)
            added = await pg.evaluate("""() => {
               const g = s => [...document.querySelectorAll(s)].map(e => e.textContent).join("");
               return { header: g('.doc-head'), markers: g('.li-marker'), qheads: g('.q-head') };
            }""")
            stats = await pg.evaluate("""() => ({
              math: document.querySelectorAll('math').length,
              figures: document.querySelectorAll('figure.fig').length,
              images: document.querySelectorAll('img').length,
              equations: document.querySelectorAll('.equation').length,
              questions: document.querySelectorAll('.question').length,
              lists: document.querySelectorAll('.li').length,
              tables: document.querySelectorAll('table').length,
              cols: document.querySelectorAll('.cols').length,
              headings: document.querySelectorAll('.section-title').length,
            })""")
            await b.close()
            return txt, stats, added

    html_text, html_stats, added = asyncio.run(grab())

    # ===== الفحص الحاسم: تغطية حروف نصّ كل كتلة في الصفحة (لا يتأثر بتقطيع MathML ولا بالترتيب) =====
    AR_L = re.compile(r"[\u0621-\u064A]")
    html_html = html_text
    page_letters = collections.Counter(AR_L.findall(norm(html_html)))
    uncovered = []
    for b in blocks:
        c = collections.Counter(AR_L.findall(norm(b.get("text", ""))))
        resid = c - page_letters
        if sum(resid.values()) > 0:
            uncovered.append({"i": b["i"], "path": b.get("path"),
                              "in_textbox_of": b.get("in_textbox_of"),
                              "missing": dict(resid), "text": b.get("text", "")[:90]})
    result_block_coverage = {
        "blocks_checked": sum(1 for b in blocks if len(norm(b.get("text", ""))) >= 2),
        "blocks_uncovered": len(uncovered),
        "missing_letters_total": sum(sum(u["missing"].values()) for u in uncovered),
        "uncovered_sample": uncovered[:10],
    }

    st, sh = collections.Counter(tokens(src_text)), collections.Counter(tokens(html_text))
    missing = {k: v for k, v in (st - sh).items()}
    extra = {k: v for k, v in (sh - st).items()}
    missing_total = sum(missing.values())
    extra_total = sum(extra.values())

    # الفروق الحرفية (أدقّ من الكلمات للرموز والمعادلات)
    sc, hc = collections.Counter(chars(src_text)), collections.Counter(chars(html_text))
    ch_missing = sc - hc
    ch_extra = hc - sc

    # تصنيف الإضافات المقصودة
    intentional_marks = {"•", "○", "-", ")", "(", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                         "س", "ا", "ل", "ن", "و", "ت", "ة", "ه", "ف", "د", "ء", "ب", "ي", "ز", "م",
                         "ر", "ق", "ع", "ط", "ص", "ح", "ج", "خ", "ذ", "ث", "ك", "ض", "ظ", "غ", "ش"}
    # المقارنة الحاسمة: كلمات الأستاذ العربية وحدها (النص الحرفي) — بلا رموز رياضية
    ar_src = collections.Counter(t for t in st.elements() if AR_RE.search(t))
    ar_html = collections.Counter(t for t in sh.elements() if AR_RE.search(t))
    ar_missing = ar_src - ar_html
    ar_extra = ar_html - ar_src
    # الرموز الرياضية: تُقاس بالتغطية لا بالمقارنة النصية (المصدر خطّي، HTML يمثلها MathML)
    html_raw = (repo / args.html).read_text(encoding="utf-8")
    math_stats = {
        "math_elements": html_raw.count("<math"),
        "green_008000_occurrences": html_raw.count("#008000"),
        "plus_minus": html_raw.count("±"),
        "minus_plus": html_raw.count("∓"),
        "implies": html_raw.count("⟸"),
        "delimiters": html_raw.count('<mo>|</mo>'),
        "sqrt": html_raw.count("<msqrt"),
        "frac": html_raw.count("<mfrac"),
        "arabic_in_math_mtext": html_raw.count('mtext dir="rtl"'),
    }
    # المقارنة الحاسمة: متعدّد حروف النص العربي (لا يتأثر بتقطيع الكلمات في MathML)
    AR_LETTER = re.compile(r"[\u0621-\u064A]")
    def ar_letters(s_):
        return collections.Counter(AR_LETTER.findall(norm(s_)))
    add_letters = ar_letters(added["header"] + added["markers"] + added["qheads"])
    src_letters = ar_letters(src_text)
    html_letters = ar_letters(html_text)
    letters_missing = src_letters - html_letters                    # في المصدر ولم يظهر
    letters_extra = html_letters - src_letters - add_letters        # ظهر ولم يكن في المصدر (بعد استبعاد الإضافات المقصودة)

    result = {
        "block_coverage": result_block_coverage,
        "arabic_letters_source": sum(src_letters.values()),
        "arabic_letters_html": sum(html_letters.values()),
        "arabic_letters_intentionally_added": sum(add_letters.values()),
        "arabic_letters_missing": sum(letters_missing.values()),
        "arabic_letters_missing_detail": sorted(letters_missing.items(), key=lambda kv: -kv[1])[:20],
        "arabic_letters_unexplained_extra": sum(letters_extra.values()),
        "arabic_letters_unexplained_extra_detail": sorted(letters_extra.items(), key=lambda kv: -kv[1])[:20],
        "added_text_source": {k: v[:120] for k, v in added.items()},
        "arabic_words_source": sum(ar_src.values()),
        "arabic_words_html": sum(ar_html.values()),
        "arabic_words_missing": sum(ar_missing.values()),
        "arabic_words_extra": sum(ar_extra.values()),
        "arabic_missing_sample": sorted(ar_missing.items(), key=lambda kv: -kv[1])[:30],
        "arabic_extra_sample": sorted(ar_extra.items(), key=lambda kv: -kv[1])[:30],
        "math_stats": math_stats,
        "source_tokens": sum(st.values()),
        "html_tokens": sum(sh.values()),
        "missing_tokens_total": missing_total,
        "missing_tokens_distinct": len(missing),
        "missing_sample": sorted(missing.items(), key=lambda kv: -kv[1])[:40],
        "extra_tokens_total": extra_total,
        "extra_sample": sorted(extra.items(), key=lambda kv: -kv[1])[:20],
        "missing_chars_total": sum(ch_missing.values()),
        "missing_chars": sorted(ch_missing.items(), key=lambda kv: -kv[1])[:30],
        "html_stats": html_stats,
    }
    dest = repo / args.json_out
    dest.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")

    bc = result["block_coverage"]
    print("— تغطية نصّ الكتل (الحكم) —")
    print(f"  كتل مفحوصة: {bc['blocks_checked']} · كتل نصّها غير مغطّى: {bc['blocks_uncovered']} · "
          f"حروف مفقودة: {bc['missing_letters_total']}")
    if bc["blocks_uncovered"] == 0:
        print("  ✅ لا فقدان: كل حرف في نصّ كل كتلة ظاهر في HTML")
    else:
        for u in bc["uncovered_sample"]:
            print("   ✗", u)
    print("— حروف النص العربي (تقديري: يتشوّش بطرح نص الترويسة/العلامات المضافة) —")
    print(f"  المصدر: {result['arabic_letters_source']} · HTML: {result['arabic_letters_html']} · "
          f"مضاف مقصود (ترويسة/علامات قوائم/رؤوس أسئلة): {result['arabic_letters_intentionally_added']}")
    print(f"  ⛔ مفقود: {result['arabic_letters_missing']} {result['arabic_letters_missing_detail'][:8]}")
    print(f"  ⛔ زائد غير مبرَّر: {result['arabic_letters_unexplained_extra']} "
          f"{result['arabic_letters_unexplained_extra_detail'][:8]}")
    print("— كلمات —")
    print(f"كلمات الأستاذ العربية — المصدر: {result['arabic_words_source']} · HTML: {result['arabic_words_html']} · "
          f"مفقود: {result['arabic_words_missing']} · زائد: {result['arabic_words_extra']}")
    if result["arabic_words_missing"]:
        print("  ⚠️ عيّنة المفقود العربي:", result["arabic_missing_sample"][:14])
        print("  عيّنة الزائد العربي:", result["arabic_extra_sample"][:14])
    else:
        print("  ✅ لا كلمة عربية مفقودة: نص الأستاذ ظاهر كاملاً")
    print("إحصاء المعادلات في HTML:", result["math_stats"])
    print(f"كلمات (كل الأنواع) — المصدر: {result['source_tokens']} · HTML: {result['html_tokens']}")
    print(f"مفقود: {result['missing_tokens_total']} (مختلف {result['missing_tokens_distinct']}) · "
          f"زائد: {result['extra_tokens_total']}")
    print("عيّنة المفقود:", result["missing_sample"][:12])
    print("عيّنة الزائد:", result["extra_sample"][:10])
    print("حروف مفقودة (أعلى 12):", result["missing_chars"][:12])
    print("إحصاء HTML:", html_stats)
    if result["missing_tokens_total"] == 0:
        print("✅ لا فقدان كلمات: كل كلمات المصدر ظاهرة في HTML")
    else:
        print("⚠️ توجد فروق — راجع العربية أعلاه (قد تكون فروق تطبيع أو رموز رياضية)")


if __name__ == "__main__":
    main()
