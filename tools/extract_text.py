#!/usr/bin/env python3
"""
Arabic-aware text extraction for the Syrian 3rd-secondary physics book.

The PDF (Adobe InDesign, fonts GEDinarOne / Baghdad / MMCenturyNew) stores
Arabic in a way that breaks naive extraction:

  1. Characters are emitted in *stream* (logical) order, which for some
     layouts (the table of contents, tabbed rows, figure captions) is the
     reverse of the true right-to-left visual order.
  2. Lam-Alef style ligatures emit their SECOND component as a ZERO-WIDTH
     character sitting at the junction between Alef and the next letter.
     e.g.  الحركة  comes out as   ا , ح(zero-width) , ل , ر , ك , ة
     i.e. "احلركة".  Likewise  الأولى -> "األولى",  الاهتزازات -> "االهتزازات".

Fixes applied here, in order:
  A. Swap any zero-width LETTER (not a diacritic mark, not a space) with the
     character that follows it -- swapping the *character* but keeping the
     *slot's* bounding box, so step B still orders it correctly.
  B. Sort every line's characters right-to-left by x0 (then x1) descending.

Usage:  python3 extract_text.py <in.pdf> <out.txt> [--pages 1-20]
"""
import re
import sys

import pymupdf as fitz

# Unicode categories we must NOT treat as ligature junk
ARABIC_LETTER = re.compile(r"[\u0621-\u063A\u0641-\u064A\u0671-\u0672\u0675-\u0677]")
# diacritics / tatweel / punctuation are marks, never swapped
MARKS = set("\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0640\u0670\u0653\u0654\u0655")


def fix_zero_width_letters(chars):
    """chars: list of dicts {c, bbox}. Swap zero-width letters with the next
    letter, keeping the *slot* bboxes in place (so ordering stays sane)."""
    out = [dict(ch) for ch in chars]
    i = 0
    n = len(out)
    while i < n - 1:
        ch = out[i]
        nx = out[i + 1]
        w = ch["bbox"][2] - ch["bbox"][0]
        if (
            w < 0.6                       # zero / near-zero width
            and ch["c"] in AR_LETTERS     # it is a letter
            and not nx["c"].isspace()     # next is not a space
        ):
            # swap the glyphs, keep the boxes
            out[i]["c"], out[i + 1]["c"] = nx["c"], ch["c"]
            i += 2                        # do not re-examine these slots
        else:
            i += 1
    return out


AR_LETTERS = set(
    chr(c)
    for c in list(range(0x0621, 0x063B))
    + list(range(0x0641, 0x064B))
    + [0x0671, 0x0672, 0x0675, 0x0676, 0x0677]
)


def line_text(line):
    chars = []
    for span in line["spans"]:
        # span-level left-to-right / right-to-left hint is unreliable: ignore it
        for ch in span["chars"]:
            chars.append({"c": ch["c"], "bbox": ch["bbox"]})
    if not chars:
        return ""
    chars = fix_zero_width_letters(chars)
    # stable sort: right-to-left by x0, tie-break by x1
    chars.sort(key=lambda d: (d["bbox"][0], d["bbox"][2]), reverse=True)
    return "".join(d["c"] for d in chars)


def page_text(page):
    data = page.get_text("rawdict")
    lines = []
    for block in data["blocks"]:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            lines.append((line["bbox"][1], line["bbox"][0], line))
    # keep visual top-to-bottom order; do NOT reorder horizontally here
    lines.sort(key=lambda t: (round(t[0], 1), -t[1]))
    return "\n".join(line_text(l) for _, _, l in lines)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    rng = None
    if "--pages" in sys.argv:
        rng = sys.argv[sys.argv.index("--pages") + 1]
    doc = fitz.open(src)
    lo, hi = 0, doc.page_count
    if rng:
        a, b = rng.split("-")
        lo, hi = int(a) - 1, int(b)
    buf = []
    for i in range(lo, min(hi, doc.page_count)):
        buf.append(f"\n<<<PAGE {i+1}>>>\n")
        buf.append(page_text(doc[i]))
    txt = "".join(buf)
    txt = re.sub(r"[ \t]+", " ", txt)
    txt = re.sub(r"\n{3,}", "\n\n", txt)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(txt)
    print(f"wrote {dst}: {len(txt)} chars, pages {lo+1}-{min(hi, doc.page_count)}")


if __name__ == "__main__":
    main()
