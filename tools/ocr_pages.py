#!/usr/bin/env python3
"""OCR the scanned ministry PDF (no text layer) using the page's embedded
image (original scan quality) + tesseract Arabic.

usage: python3 ocr_pages.py <pdf> <out.txt> [first] [last]
"""
import io
import subprocess
import sys
import tempfile
from pathlib import Path

import pymupdf as fitz


def page_image(doc, index, dpi=0):
    """Return PNG bytes for the page, preferring the embedded full-page image."""
    imgs = doc[index].get_images(full=True)
    if imgs:
        xref = imgs[0][0]
        info = doc.extract_image(xref)
        if info["width"] >= 800:
            return info["image"], info["ext"]
    pix = doc[index].get_pixmap(dpi=dpi or 300)
    return pix.tobytes("png"), "png"


def ocr(data, ext, psm=6):
    with tempfile.NamedTemporaryFile(suffix="." + ext, delete=False) as f:
        f.write(data)
        path = f.name
    try:
        r = subprocess.run(
            ["tesseract", path, "stdout", "-l", "ara", "--psm", str(psm),
             "-c", "preserve_interword_spaces=1"],
            capture_output=True, text=True, timeout=300,
        )
        return r.stdout
    finally:
        Path(path).unlink(missing_ok=True)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    first = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    last = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    doc = fitz.open(src)
    last = last or doc.page_count
    out = []
    for i in range(first - 1, min(last, doc.page_count)):
        try:
            data, ext = page_image(doc, i)
            txt = ocr(data, ext)
        except Exception as e:  # noqa
            txt = f"[OCR ERROR p{i+1}: {e}]"
        out.append(f"\n<<<PAGE {i+1}>>>\n{txt}")
        print(f"p{i+1} ", end="", flush=True)
    Path(dst).write_text("".join(out), encoding="utf-8")
    print(f"\nwrote {dst} ({len(out)} pages)")


if __name__ == "__main__":
    main()
