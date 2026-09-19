#!/usr/bin/env python3
"""يبني content/reference-map.json — خريطة «كل عنصر ⇒ موضعه في المصدر وإثباته»:
   • لكل صورة: sha256 للملف في assets/images مقابل مدخل word/media في المستند (إثبات بايت-ببايت).
   • لكل معادلة: نصّها الحرفي بعد التصحيحات + الكتلة المرجعية.
   • لكل كتلة: مرجعها الفعلي في XML (body/p[n] · tbl[n]/r/c/p[j] · txbx[Fxxxx]/p[j]) ونصّها.
   تُستخدم هذه الخريطة في NHTML-5 لمقابلة كل عنصر معروض بعنصر مصدري بلا اختراع ولا حذف.
"""
from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

from lxml import etree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import inventory_docx as I                # noqa: E402
from inventory_docx import Inventory, local, W, M, MC, math_flat   # noqa: E402
from extract_content import apply_rules                            # noqa: E402


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
    src = out / "source" / "original.docx"
    zf = zipfile.ZipFile(src)
    doc = etree.fromstring(zf.read("word/document.xml"))
    log = collections.Counter()
    apply_rules(doc, True, log, [])

    inv = Inventory(src)
    inv.doc = doc
    inv.body = doc.find(f"{{{W}}}body")
    inv.run()

    # --- الصور: إثبات التطابق
    images = []
    for ent in zf.namelist():
        if not ent.startswith("word/media/"):
            continue
        name = Path(ent).name
        local_p = out / "assets" / "images" / name
        if not local_p.exists():
            continue
        zbytes = zf.read(ent)
        lbytes = local_p.read_bytes()
        images.append({
            "file": f"assets/images/{name}",
            "bytes": len(zbytes),
            "same_bytes": zbytes == lbytes,
            "sha256_source": hashlib.sha256(zbytes).hexdigest(),
            "sha256_local": sha256_file(local_p),
        })
    # --- الكتل: مرجع XML فعلي
    MC_FB = f"{{{MC}}}Fallback"
    blocks = []
    for b in inv.blocks:
        el = inv.block_elems[b["i"] - 1]
        ref = b.get("path")
        if b["kind"] == "p":
            m = re.match(r"body/p\[(\d+)\](?:.*)", ref or "")
            anc = [local(a) for a in el.iterancestors()]
            if "txbxContent" in anc:
                owner = None
                for a in el.iterancestors():
                    if local(a) == "txbxContent":
                        owner = a
                        break
                # رقم الفقرة الأخيرة تشير إلى الموضع الحقيقي عبر المسار المحسوب في الجرد
                xml_ref = ref
            else:
                xml_ref = ref
        else:
            xml_ref = ref
        blocks.append({
            "i": b["i"], "kind": b["kind"], "ref": xml_ref, "text": b["text"],
            "eqs": [e["id"] for e in (inv.equations_by_block.get(b["i"], []) if hasattr(inv, "equations_by_block") else [])]
                   or [e for e in b.get("eqs", [])],
            "figs": b.get("figs", []),
            "tab": bool(b.get("flags", {}).get("has_tab")),
            "spaces3": bool(b.get("flags", {}).get("multi_space")),
            "num": b.get("num"), "style": b.get("style"),
        })
    # --- المعادلات: نصّها الحرفي (بعد تصحيحات R1–R14 المطبَّقة في الذاكرة)
    equations = []
    for e in inv.equations:
        flat = (e.get("flat") or e.get("linear") or "").strip()
        equations.append({
            "id": e["id"], "block": e.get("block"), "ref": e.get("block_path"),
            "display": e.get("display"), "container": e.get("container"),
            "in_table": e.get("in_table"), "in_textbox_of": e.get("in_textbox_of"),
            "literal_text": flat, "chars": e.get("chars"),
            "has_plus_minus": ("±" in flat or "∓" in flat),
        })

    figures = [{
        "id": f["id"], "order": f.get("order"), "kind": f["kind"], "block": f.get("block"),
        "ref": f.get("block_path"), "source": f.get("source"), "anchor": f.get("anchor"),
        "media": f.get("graphic_uri"), "text_blocks": f.get("text_blocks"),
        "parent_fig": f.get("parent_fig"), "text_preview": f.get("text_preview"),
        "extent_emu": f.get("extent_emu"), "extent_cm": f.get("extent_cm"),
        "position": f.get("position"),
    } for f in inv.figures]

    data = {
        "stage": "NHTML-2-reference-map",
        "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source_sha256": sha256_file(src),
        "rules_applied": dict(log),
        "totals": {
            "blocks": len(blocks), "equations": len(equations), "figures": len(figures),
            "images": len(images),
            "images_identical": sum(1 for x in images if x["same_bytes"]),
        },
        "images": images, "blocks": blocks, "equations": equations, "figures": figures,
    }
    dest = out / "content" / "reference-map.json"
    dest.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"reference-map: {dest} ({dest.stat().st_size/1024/1024:.2f} MB)")
    print(json.dumps(data["totals"], ensure_ascii=False))


if __name__ == "__main__":
    main()
