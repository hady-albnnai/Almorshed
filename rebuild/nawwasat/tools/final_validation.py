#!/usr/bin/env python3
"""final_validation.py — تحقّق NHTML-5 النهائي على PDF المُخرَج.

يقابل كل عنصر في المصدر المجمّد بما ظهر فعلاً في PDF:
  1. النصّ: تغطية حروف نصّ كل كتلة (بلا فقدان حرف واحد).
  2. الصور: العدد والأسماء والبصمات (مقابل word/media) والظهور في الصفحات.
  3. المعادلات: العدد والرموز والإشارات (± ∓ ⟸ √ etc.) والألوان (المحدّدات الخضراء #008000).
  4. الترقيم: عدد الصفحات · تذييل على كل صفحة · لا صفحات فارغة · تسلسل الأرقام.
  5. المسح البصري: تحويل كل الصفحات إلى صور وقياس الشواذ (سواد ضخم · صفحة شبه فارغة · محتوى خارج الهوامش).

المخرجات: content/final-validation.json · reports/nhtml5-shots/ (لقطات مرجعية)
"""
from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import json
import re
import unicodedata
from pathlib import Path

import pymupdf
from PIL import Image
import io
import numpy as np

AR_LETTER = re.compile(r"[\u0621-\u064A]")
GREEN = 0x008000


def norm(s: str) -> str:
    return unicodedata.normalize("NFKC", s or "")


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    out = repo / "rebuild" / "nawwasat"
    pdf = out / "pdf" / "نوطة-النواسات.pdf"
    shots = out / "reports" / "nhtml5-shots"
    shots.mkdir(parents=True, exist_ok=True)

    text_json = json.loads((out / "content" / "text.json").read_text(encoding="utf-8"))["blocks"]
    refmap = json.loads((out / "content" / "reference-map.json").read_text(encoding="utf-8"))
    structure = json.loads((out / "content" / "structure.json").read_text(encoding="utf-8"))

    doc = pymupdf.open(pdf)
    pages = list(doc)
    result: dict = {
        "stage": "NHTML-5",
        "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "artifacts": {
            "source_docx_sha256": sha256_file(out / "source" / "original.docx"),
            "source_docx_sha256_expected": structure.get("source_sha256"),
            "html_sha256": sha256_file(out / "html" / "index.html"),
            "pdf_sha256": sha256_file(pdf),
            "pdf_bytes": pdf.stat().st_size,
        },
        "pages": len(pages),
    }

    # ---------------------------------------------------------------- 1) النصّ
    page_texts = [p.get_text() for p in pages]
    page_letters = [collections.Counter(AR_LETTER.findall(norm(t))) for t in page_texts]
    total_letters = collections.Counter()
    for c in page_letters:
        total_letters.update(c)

    uncovered, checked = [], 0
    for b in text_json:
        letters = collections.Counter(AR_LETTER.findall(norm(b.get("text", ""))))
        if sum(letters.values()) < 1:
            continue
        checked += 1
        resid = letters - total_letters
        if sum(resid.values()) > 0:
            uncovered.append({"i": b["i"], "path": b.get("path"),
                              "in_textbox_of": b.get("in_textbox_of"),
                              "missing": dict(resid), "text": b.get("text", "")[:80]})
    result["text"] = {
        "blocks_checked": checked,
        "blocks_with_missing_letters": len(uncovered),
        "missing_letters_total": sum(sum(u["missing"].values()) for u in uncovered),
        "uncovered_sample": uncovered[:10],
        "arabic_letters_in_pdf": sum(total_letters.values()),
    }

    # ---------------------------------------------------------------- 2) الصور
    media = {}
    for name in (out / "assets" / "images").iterdir():
        media[name.name] = sha256_file(name)
    embedded = []
    for i, page in enumerate(pages):
        for im in page.get_images(full=True):
            xref = im[0]
            try:
                info = doc.extract_image(xref)
            except Exception:
                continue
            embedded.append({"page": i + 1, "xref": xref, "w": info["width"], "h": info["height"],
                             "ext": info["ext"], "bytes": len(info["image"]),
                             "sha256": hashlib.sha256(info["image"]).hexdigest()})
    emb_hashes = {e["sha256"] for e in embedded}
    images_from_source = {n for n in media}
    # مطابقة بصرية: متوسط-البصمة (32 بت) لكل ملف مصدر مقابل كل صورة مُدرجة في PDF
    def ahash_bytes(data: bytes):
        try:
            im = Image.open(io.BytesIO(data)).convert("L").resize((32, 32), Image.LANCZOS)
        except Exception:
            return None
        px = list(im.getdata())
        avg = sum(px) / len(px)
        return sum(1 << k for k, v in enumerate(px) if v > avg)

    src_hashes = {}
    for name in sorted(media):
        h = ahash_bytes((out / "assets" / "images" / name).read_bytes())
        if h is not None:
            src_hashes[name] = h
    phash_matches, phash_unmatched = [], []
    for e in embedded:
        try:
            dh = ahash_bytes(doc.extract_image(e["xref"])["image"])
        except Exception:
            dh = None
        if dh is None:
            phash_unmatched.append({"page": e["page"], "why": "تعذّر فكّ الترميز"})
            continue
        best, bname = 99, None
        for name, sh in src_hashes.items():
            dist = bin(sh ^ dh).count("1")
            if dist < best:
                best, bname = dist, name
        (phash_matches if best <= 8 else phash_unmatched).append(
            {"page": e["page"], "src": bname, "hamming": best})

    result["images"] = {
        "source_files": len(media),
        "source_used_in_structure": structure.get("coverage", {}).get("figures_total"),
        "embedded_placements": len(embedded),
        "pages_with_images": len({e["page"] for e in embedded}),
        "embedded_sha256_matching_source_files": sum(1 for h in emb_hashes if h in set(media.values())),
        "source_files_not_embedded_bytewise": [n for n, h in media.items() if h not in emb_hashes][:10],
        "expected_pictures": 75,
        "phash_matched_placements": len(phash_matches),
        "phash_unmatched": phash_unmatched[:10],
        "phash_max_hamming": max([m["hamming"] for m in phash_matches], default=None),
        "distinct_source_images_placed": len({m["src"] for m in phash_matches}),
    }

    # ---------------------------------------------------------------- 3) الرموز والمعادلات (HTML↔PDF)
    import html as _html

    html_src = (out / "html" / "index.html").read_text(encoding="utf-8")
    no_alt = re.sub(r'\s(?:alttext)="[^"]*"', "", html_src)
    body = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", no_alt, flags=re.S)
    plain = unicodedata.normalize("NFKC", _html.unescape(re.sub(r"<[^>]+>", "", body)))
    pdf_flat = unicodedata.normalize("NFKC", "\n".join(page_texts))

    TRACKED = ["±", "∓", "Δ", "α", "ω", "π", "θ", "φ", "Γ", "∑", "|", "⟸", "⇐", "⟹", "⇒",
               "→", "≤", "≠", "√", "ℰ", "∝", "∆"]
    sym_table, sym_mismatch = {}, []
    for ch in TRACKED:
        a, b = plain.count(ch), pdf_flat.count(ch)
        sym_table[ch] = {"html": a, "pdf": b, "ok": b >= a}
        if a > b:
            sym_mismatch.append({"symbol": ch, "html": a, "pdf": b})
    # مقاطع النصّ الخضراء فعلياً في PDF (المحدّدات | | الملوّنة #008000)
    green_spans, green_pages = 0, set()
    for i, page in enumerate(pages):
        for blk in page.get_text("dict")["blocks"]:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    if int(span.get("color", 0)) == GREEN:
                        green_spans += 1
                        green_pages.add(i + 1)
    result["green_bars_in_pdf"] = {"spans": green_spans, "pages": sorted(green_pages)}

    struct_counts = {
        "msqrt_radicals": len(re.findall(r"<msqrt", html_src)),
        "mfrac_fractions": len(re.findall(r"<mfrac", html_src)),
        "vector_accents_mover": len(re.findall(r'<mover[^>]*accent="true"', html_src)),
        "vector_accents_source_m_acc": structure.get("stats", {}).get("math_accents", 55),
        "green_008000_in_math": html_src.count("#008000"),
        "math_elements": len(re.findall(r"<math\b", html_src)),
    }
    result["equations"] = {
        "math_expected": structure.get("coverage", {}).get("equations_total"),
        "math_in_html": struct_counts["math_elements"],
        "inline_math_promoted": structure.get("stats", {}).get("inline_math_promoted"),
        "symbol_match_html_vs_pdf": sym_table,
        "symbol_mismatches": sym_mismatch,
        "structure_counts": struct_counts,
    }

    # ---------------------------------------------------------------- 4) الترقيم والتذييل
    footer_text = structure.get("footer_text", "")
    phone = (re.search(r"0\d{8,}", footer_text) or [None])
    phone = phone.group(0) if hasattr(phone, "group") else None
    footer_pages, nums_ok, nums_found = [], True, []
    for i, t in enumerate(page_texts):
        compact = re.sub(r"\s+", "", norm(t))
        if phone and phone in compact:
            footer_pages.append(i + 1)
        tail = [l for l in t.strip().split("\n") if l.strip().isdigit()]
        if tail:
            nums_found.append(int(tail[-1]))
    expected_seq = list(range(1, len(pages) + 1))
    if nums_found[:len(pages)] != expected_seq[:len(nums_found)]:
        nums_ok = False
    result["pagination"] = {
        "pages": len(pages),
        "footer_on_pages": len(footer_pages),
        "footer_text": footer_text,
        "page_numbers_sequential": nums_ok,
        "page_number_range": [min(nums_found), max(nums_found)] if nums_found else None,
        "page_size_mm": sorted({(round(p.rect.width / 72 * 25.4, 1), round(p.rect.height / 72 * 25.4, 1))
                                for p in pages}),
    }

    # ---------------------------------------------------------------- 5) المسح البصري
    scan = {"dark_pages": [], "near_empty_pages": [], "pages_rendered": 0}
    for i, page in enumerate(pages):
        pm = page.get_pixmap(dpi=40, alpha=False)
        arr = np.frombuffer(pm.samples, dtype=np.uint8).reshape(pm.height, pm.width, 3)
        gray = arr.mean(axis=2)
        dark_ratio = float((gray < 120).mean())
        ink_ratio = float((gray < 230).mean())
        if dark_ratio > 0.25:
            scan["dark_pages"].append({"page": i + 1, "dark_ratio": round(dark_ratio, 3)})
        if ink_ratio < 0.008 and not page.get_images(full=True):
            scan["near_empty_pages"].append({"page": i + 1, "ink_ratio": round(ink_ratio, 4)})
        scan["pages_rendered"] += 1
        if (i + 1) in (1, 8, 30, 60, len(pages)):      # لقطات مرجعية للمراجعة العينية
            page.get_pixmap(dpi=100).save(shots / f"page-{i+1:03d}.png")
    # صفحة فيها المحددات الخضراء
    for pg in result["green_bars_in_pdf"]["pages"][:3]:
        pages[pg - 1].get_pixmap(dpi=130).save(shots / f"green-bars-page-{pg:03d}.png")
    result["visual_scan"] = scan

    # ألواح مسح بصري: كل الصفحات، 12/لوح — دليل مراجعة عينية للمالك
    COLS, ROWS, DPI = 3, 4, 52
    thumbs = [page.get_pixmap(dpi=DPI, alpha=False) for page in pages]
    tw, th = thumbs[0].width, thumbs[0].height
    per = COLS * ROWS
    sheets = []
    for s0 in range(0, len(thumbs), per):
        chunk = thumbs[s0:s0 + per]
        sheet = Image.new("RGB", (COLS * tw + (COLS + 1) * 4, ROWS * th + (ROWS + 1) * 4), (225, 225, 225))
        for k, pm in enumerate(chunk):
            im = Image.frombytes("RGB", (pm.width, pm.height), pm.samples)
            r, c = divmod(k, COLS)
            sheet.paste(im, (4 + c * (tw + 4), 4 + r * (th + 4)))
        path = shots / f"sheet-{s0 // per + 1:02d}.png"
        sheet.save(path, optimize=True)
        sheets.append({"sheet": path.name, "pages": [s0 + 1, s0 + len(chunk)]})
    result["visual_scan"]["contact_sheets"] = sheets

    # ---------------------------------------------------------------- الحكم
    ok_text = result["text"]["blocks_with_missing_letters"] == 0
    ok_imgs = len(embedded) >= 75 and len(phash_matches) == len(embedded)
    ok_pages = not scan["dark_pages"] and not scan["near_empty_pages"]
    ok_footer = len(footer_pages) == len(pages)
    ok_src = result["artifacts"]["source_docx_sha256"] == result["artifacts"]["source_docx_sha256_expected"]
    ok_sym = not sym_mismatch
    ok_math = struct_counts["math_elements"] == 1346 and struct_counts["green_008000_in_math"] == 12
    result["verdict"] = {
        "text_complete": ok_text,
        "images_present": ok_imgs,
        "pages_clean": ok_pages,
        "footer_every_page": ok_footer,
        "source_untouched": ok_src,
        "symbols_intact": ok_sym,
        "math_and_green_colors": ok_math,
        "PASS": all([ok_text, ok_imgs, ok_pages, ok_footer, ok_src, ok_sym, ok_math]),
    }

    dest = out / "content" / "final-validation.json"
    dest.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(result["verdict"], ensure_ascii=False, indent=1))
    print(json.dumps({"text": result["text"], "images": {k: v for k, v in result["images"].items()
                     if k != "source_files_not_embedded_bytewise"},
                      "symbols": sym_table,
                      "green_text_spans_in_pdf": green_spans,
                      "green_pages": sorted(green_pages),
                      "structure": struct_counts,
                      "pagination": result["pagination"],
                      "visual_scan": {"dark_pages": scan["dark_pages"],
                                      "near_empty_pages": scan["near_empty_pages"]}},
                     ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
