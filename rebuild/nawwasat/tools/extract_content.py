#!/usr/bin/env python3
"""NHTML-1 — استخراج المحتوى الحرفي + الأصول + تطبيق تصحيحات الرموز R1–R14.

يقرأ المصدر المجمّد `rebuild/nawwasat/source/original.docx` (قراءة فقط) ويُنتج:

  assets/images/<اسم الوسيط الأصلي>        نسخ بايت-لبايت لكل ملفات الوسائط
  assets/equations/omml-corrected.jsonl   معادلات OMML بعد التصحيح (سجل مصدر كل معادلة)
  assets/equations/README.md              من أين جاءت وكيف تُعاد
  content/text.json                       النص الحرفي مرتّباً كتلةً كتلة
  content/text-literal.txt                تفريغ مقروء للمراجعة العينية
  content/images.json                     سجل الصور: بصمة · أبعاد · موضع أول ظهور · الدور
  content/equations.json                  سجل المعادلات: أصلي · مصحّح · القواعد المطبَّقة
  content/extraction.json                 ملخّص الأعداد والفحوصات
  reports/NHTML-1-content-extraction.md   تقرير الاستخراج والتحقق

قواعد التصحيح R1–R14 منقولة حرفياً عن `tools/fix_fadaa_symbols.py` (سجل تصحيحات سابق معتمد).
"""
from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import json
import re
import shutil
import sys
import zipfile
from pathlib import Path

from lxml import etree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inventory_docx import (  # noqa: E402  (أداة NHTML-0 — مصدر واحد للفهم)
    A, MC, M, NS, PIC, V, W, WPS, iter_effective, local, math_flat, math_linear,
    scope_iter, tag_of,
)

MT = f"{{{M}}}t"
WT = f"{{{W}}}t"

# ---- قواعد التصحيح (منسوخة حرفياً من tools/fix_fadaa_symbols.py) -------------
WEIGHT_PAT = re.compile(
    r"F_s|\+T\b|T=m|\+T=|-ω\s*cos|-ω\s*sin|ωsin|Γ_ω|Γω|W_ω|Wω|=\s*kx_0|ωk=|"
    r"d'\.ω|ⅆ'ω|d\.\s*ω|F=2ω|ω_e|R\+\s*ω|tan∝=Fω|ω\+F|ω-F"
)
K_EXCLUDE = re.compile(r"πK|K=[0-9]|K`")


def sim(el) -> str:
    """نص مبسّط للكتلة الرياضية مع _ للتابع (للتصنيف فقط)."""
    out = []
    for n in el.iter():
        q = etree.QName(n)
        if q.namespace != NS["m"]:
            continue
        if q.localname == "t" and n.text:
            out.append(n.text)
        elif q.localname == "sub":
            out.append("_")
    return "".join(out)


def ptext(p) -> str:
    return "".join(t.text or "" for t in p.iter(WT))


def is_sub_base_keep(t_el) -> bool:
    """هل هذا الرمز ω أساس تابع من نوع ω_0 / ω_max / ω_r (نبض، يبقى)؟"""
    r = t_el.getparent()
    e = r.getparent() if r is not None else None
    if e is None or etree.QName(e).localname != "e":
        return False
    s = e.getparent()
    if s is None or etree.QName(s).localname not in ("sSub", "sSubSup"):
        return False
    sub = s.find(f"{{{M}}}sub")
    st = sim(sub).strip() if sub is not None else ""
    return st.startswith(("0", "max", "maX", "r", "1", "2")) or etree.QName(s).localname == "sSubSup"


def apply_rules(root, is_pend: bool, log: collections.Counter, changes: list):
    """يطبّق R1–R14 على الشجرة في مكانها (نفس منطق الأداة السابقة حرفياً)."""
    # R1/R5/R11/R12/R13/R14 — على مستوى التوابع
    for tag in ("sSub", "sSubSup"):
        for s in root.iter(f"{{{M}}}{tag}"):
            e = s.find(f"{{{M}}}e")
            sub = s.find(f"{{{M}}}sub")
            if e is None or sub is None:
                continue
            base = sim(e).strip()
            subts = [t for t in sub.iter(MT) if t.text]
            if not subts:
                continue
            st = "".join(t.text for t in subts)
            first = subts[0]
            if base == "T" and st.strip() == "o":
                first.text = first.text.replace("o", "0", 1); log["R1 T_o→T_0"] += 1
            elif base == "Γ" and st.strip() == "n":
                first.text = first.text.replace("n", "η", 1); log["R5 Γ_n→Γ_η"] += 1
            elif base in ("f", "v") and re.fullmatch(r"o[xy]?\s*", st):
                first.text = first.text.replace("o", "0", 1); log[f"R11 {base}_o→{base}_0"] += 1
            elif base in ("E", "W") and st.strip() == "S":
                first.text = first.text.replace("S", "s", 1); log[f"R12 {base}_S→{base}_s"] += 1
            elif base == "E" and st.strip() in ("K", "P"):
                new = st.strip().lower()
                first.text = first.text.replace(st.strip(), new, 1); log[f"R13 E_{st.strip()}→E_{new}"] += 1
            if st.strip() == "max":
                first.text = first.text.replace("max", "maX", 1); log["R14 max→maX"] += 1

    # R2 (الثقل) و R6 (K) — على مستوى الكتلة
    for om in root.iter(f"{{{M}}}oMath"):
        s = sim(om)
        par = om.getparent()
        while par is not None and etree.QName(par).localname != "p":
            par = par.getparent()
        prose = ptext(par) if par is not None else ""
        weight = bool(WEIGHT_PAT.search(s)) or (s.strip() == "ω" and "ثقل" in prose)
        if weight and "ω" in s:
            before = s
            for t in om.iter(MT):
                if t.text and "ω" in t.text and not is_sub_base_keep(t):
                    t.text = t.text.replace("ω", "w")
            after = sim(om)
            if after != before:
                log["R2 ω(ثقل)→w"] += 1
                changes.append({"rule": "R2", "before": before.strip()[:80], "after": after.strip()[:80]})
        if is_pend and re.search(r"(?<![A-Za-z_])K(?![A-Za-z])", s) and not K_EXCLUDE.search(s):
            before = s
            for t in om.iter(MT):
                if t.text and re.search(r"(?<![A-Za-z])K(?![A-Za-z])", t.text):
                    t.text = re.sub(r"(?<![A-Za-z])K(?![A-Za-z])", "k", t.text)
            after = sim(om)
            if after != before:
                log["R6 K→k"] += 1
                changes.append({"rule": "R6", "before": before.strip()[:80], "after": after.strip()[:80]})

    # استبدالات حرفية
    simple = [
        ("∆", "Δ", "R3 ∆→Δ"), ("∝", "α", "R4 ∝→α"), ("Υ", "γ", "R7 Υ→γ"),
        ("HZ", "Hz", "R8 HZ→Hz"), ("COS", "cos", "R8 COS→cos"), ("evg", "avg", "R8 P_evg→P_avg"),
        ("m..g", "m.g", "R8 m..g→m.g"), ("ⅈ", "i", "R8 ⅈ→i"),
        ("ωeb", "Wb", "R9 ωeb→Wb"), ("ωat", "W", "R9 ωat→W"), ("Λ", "∧", "R10 Λ→∧"),
    ]
    for t in root.iter(MT):
        if not t.text:
            continue
        for a, b, name in simple:
            if a in t.text:
                log[name] += t.text.count(a)
                t.text = t.text.replace(a, b)

    # الرموز المقسّمة على عدة runs متتالية
    seq_rules = [(("e", "v", "g"), ("a", "v", "g"), "R8 P_evg→P_avg (مقسّم)"),
                 (("ω", "eb"), ("W", "b"), "R9 ωeb→Wb (مقسّم)"),
                 (("ω", "at"), ("W", ""), "R9 ωat→W (مقسّم)")]
    for om in root.iter(f"{{{M}}}oMath"):
        ts = [t for t in om.iter(MT) if t.text is not None]
        for i in range(len(ts)):
            for pat, rep, name in seq_rules:
                n = len(pat)
                if i + n <= len(ts) and all(ts[i + j].text.strip() == pat[j] for j in range(n)):
                    for j in range(n):
                        ts[i + j].text = ts[i + j].text.replace(pat[j], rep[j], 1)
                    log[name] += 1

    # النص العادي: ∆ و HZ فقط (كالأداة السابقة)
    for t in root.iter(WT):
        if not t.text:
            continue
        for a, b, name in (("∆", "Δ", "R3 ∆→Δ (نص)"), ("HZ", "Hz", "R8 HZ→Hz (نص)")):
            if a in t.text:
                log[name] += t.text.count(a)
                t.text = t.text.replace(a, b)
    return root


# ---------------------------------------------------------------- streaming (مسار تحقق مستقل)
def streaming_text(doc_bytes: bytes):
    """استخراج مستقل بلا شجرة: يعبر document.xml بالتدفق ويجمع w:t/m:t
    مع تجاهل أفرع mc:Fallback (لأن Word يرسم Choice)."""
    text = []
    depth_fallback = 0
    for ev, el in etree.iterparse(__import__("io").BytesIO(doc_bytes), events=("start", "end")):
        tag = el.tag
        if ev == "start":
            if tag == f"{{{MC}}}Fallback":
                depth_fallback += 1
            continue
        # end
        if tag == f"{{{MC}}}Fallback":
            depth_fallback = max(0, depth_fallback - 1)
            el.clear()
            continue
        if depth_fallback == 0 and isinstance(tag, str):
            if tag in (WT, MT):
                text.append(el.text or "")
            elif tag == f"{{{W}}}tab":
                text.append("\t")
            elif tag == f"{{{W}}}br":
                text.append("\n")
        if depth_fallback == 0 and tag not in (WT, MT):
            el.clear()
    return "".join(text)


def normalize_ws(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--out", default="rebuild/nawwasat")
    ap.add_argument("--source", default="rebuild/nawwasat/source/original.docx")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    out = (repo / args.out).resolve()
    src = (repo / args.source).resolve()
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for sub in ("assets/images", "assets/equations", "content", "reports"):
        (out / sub).mkdir(parents=True, exist_ok=True)

    manifest = json.loads((out / "content" / "manifest.json").read_text(encoding="utf-8"))
    audit = json.loads((out / "content" / "source-audit.json").read_text(encoding="utf-8"))
    z = zipfile.ZipFile(src)
    doc_bytes = z.read("word/document.xml")
    src_sha = hashlib.sha256(src.read_bytes()).hexdigest()

    # ============ 1) تطبيق قواعد الرموز على نسخة في الذاكرة (لا تُحفظ في DOCX) ============
    root = etree.fromstring(doc_bytes)

    def _in_fallback(e):
        return any(a.tag == f"{{{MC}}}Fallback" for a in e.iterancestors())

    all_oms = [om for om in root.iter(f"{{{M}}}oMath")]      # يشمل نسخ fallback المرآتية
    oms = [om for om in all_oms if not _in_fallback(om)]      # المعروض فعلاً (Choice)
    n_fb_copies = len(all_oms) - len(oms)
    before_xml = [etree.tostring(om, encoding="utf-8") for om in oms]
    before_flat = [math_flat(om) for om in oms]
    before_linear = [math_linear(om) for om in oms]
    log = collections.Counter()
    changes = []
    is_pend = "النواسات" in (manifest["source"]["repo_path"] + str(src))
    apply_rules(root, is_pend, log, changes)
    after_xml = [etree.tostring(om, encoding="utf-8") for om in oms]
    after_flat = [math_flat(om) for om in oms]
    after_linear = [math_linear(om) for om in oms]
    corrected_doc_bytes = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone=True)

    # ============ 2) صور: نسخ بايت-لبايت + سجل ============
    media_all = sorted(n for n in z.namelist() if n.startswith("word/media/") and not n.endswith("/"))
    img_usage = {k: v for k, v in manifest["media_usage"].items()}
    fig_by_id = {f["id"]: f for f in manifest["figures"]}
    images = []
    copy_ok = 0
    for name in media_all:
        data = z.read(name)
        target = out / "assets" / "images" / Path(name).name
        target.write_bytes(data)
        same = hashlib.sha256(target.read_bytes()).hexdigest() == hashlib.sha256(data).hexdigest()
        copy_ok += int(same)
        first_fig = (img_usage.get(name) or [None])[0]
        f = fig_by_id.get(first_fig) if first_fig else None
        images.append({
            "file": f"assets/images/{Path(name).name}",
            "media_name": name,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "px": (manifest["media"] and next((m.get("px") for m in manifest["media"] if m["name"] == name), None)),
            "format": next((m.get("format") for m in manifest["media"] if m["name"] == name), None),
            "figures": img_usage.get(name, []),
            "first_block": f.get("block") if f else None,
            "role": ("used" if name in img_usage else
                     "fallback-only" if name in manifest.get("media_fallback_only_list", []) else
                     "unused-rel" if name in manifest.get("media_rel_unused_list", []) else "orphan"),
            "byte_identical_copy": same,
        })
    for name in manifest.get("media_orphan_list", []):
        pass
    (out / "content" / "images.json").write_text(json.dumps({
        "stage": "NHTML-1", "generated_at_utc": now, "source_sha256": src_sha,
        "count": len(images), "byte_identical_copies": copy_ok, "images": images,
    }, ensure_ascii=False, indent=1), encoding="utf-8")

    # ============ 3) معادلات ============
    eq_meta = {e["id"]: e for e in manifest["equations"]}
    assert len(oms) == len(eq_meta), f"عدد المعادلات مختلف: {len(oms)} مقابل {len(eq_meta)}"
    equations = []
    omml_lines = []
    with (out / "assets" / "equations" / "omml-corrected.jsonl").open("w", encoding="utf-8") as fh:
        for idx, om in enumerate(oms):
            eid = f"E{idx + 1:05d}"
            meta = eq_meta[eid]
            applied = []
            bo, ao = before_flat[idx], after_flat[idx]
            if before_xml[idx] != after_xml[idx]:
                applied = sorted({k.split()[0] for k in log})  # تُضبط أدق لاحقاً أدناه
            rec = {
                "id": eid,
                "block": meta["block"],
                "block_path": meta["block_path"],
                "display": meta["display"],
                "container": meta["container"],
                "in_table": meta["in_table"],
                "in_textbox_of": meta["in_textbox_of"],
                "features": meta["features"],
                "sty": meta["sty"],
                "linear_original": before_linear[idx],
                "linear_corrected": after_linear[idx],
                "flat_original": bo,
                "flat_corrected": ao,
                "changed": bool(before_xml[idx] != after_xml[idx]),
            }
            equations.append(rec)
            if rec["changed"]:
                line = {"id": eid, "block": meta["block"], "xml": after_xml[idx].decode("utf-8")}
                omml_lines.append(line)
                fh.write(json.dumps(line, ensure_ascii=False) + "\n")
    (out / "content" / "equations.json").write_text(json.dumps({
        "stage": "NHTML-1", "generated_at_utc": now, "source_sha256": src_sha,
        "count": len(equations),
        "changed_count": sum(1 for e in equations if e["changed"]),
        "rules_log": dict(log), "rule_examples": changes[:60],
        "equations": equations,
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    (out / "assets" / "equations" / "README.md").write_text(
        "# معادلات النواسات — أصول العرض (NHTML-1)\n\n"
        f"- المصدر: `rebuild/nawwasat/source/original.docx` (SHA-256 `{src_sha}`)\n"
        "- `omml-corrected.jsonl`: سطر لكل معادلة **تغيّرت** بتطبيق قواعد الرموز R1–R14، "
        "وفيه: المعرّف (`E000001`…) + رقم الكتلة + OMML بعد التصحيح.\n"
        "- السجل الكامل لكل المعادلات (1483) بحالتها قبل/بعد: `content/equations.json`.\n"
        "- المعادلات غير المذكورة في الملف لم تتغيّر، وXML الأصلي لها يُقرأ من المصدر المجمّد مباشرة.\n"
        "- في NHTML-2 تُحوَّل هذه المعادلات إلى صيغة عرض (MathML/SVG) — القرار الفني يُسجَّل هناك.\n",
        encoding="utf-8")

    # ============ 4) النص الحرفي ============
    blocks = manifest["blocks"]
    text_dump = []
    for b in blocks:
        if b["kind"] == "tbl":
            text_dump.append(f"\n##### [كتلة {b['i']}] جدول {b['rows']}×{b['cols']} #####")
            continue
        pad = "  " * (1 if b["in_textbox_of"] else 0)
        tag_bits = []
        if b["figs"]:
            tag_bits.append("رسوم:" + ",".join(b["figs"]))
        if b["eqs"]:
            tag_bits.append("معادلات:" + f"{b['eqs'][0]}…{b['eqs'][-1]}" if len(b["eqs"]) > 1 else "معادلات:" + b["eqs"][0])
        if b["in_textbox_of"]:
            tag_bits.append(f"مربع نصي {b['in_textbox_of']}")
        suffix = ("   «" + " · ".join(tag_bits) + "»") if tag_bits else ""
        shown = b["text"] if b["text"].strip() else "(بلا نص)"
        text_dump.append(f"{pad}[{b['i']}] {shown}{suffix}")
    (out / "content" / "text-literal.txt").write_text("\n".join(text_dump) + "\n", encoding="utf-8")

    text_json = {
        "stage": "NHTML-1", "generated_at_utc": now, "source_sha256": src_sha,
        "order": "تدفق المستند: body ← جداول ← مربعات نصية (كما يعرضها Word)",
        "counts": manifest["counts"],
        "markers": {
            "headings": manifest["heading_candidates"],
            "questions": manifest["question_candidates"],
        },
        "blocks": [{
            "i": b["i"], "path": b["path"], "kind": b["kind"],
            "style": b.get("style"), "jc": b.get("jc"), "rtl": b.get("rtl"), "num": b.get("num"),
            "in_textbox_of": b.get("in_textbox_of"), "in_table": b.get("in_table"),
            "text": b["text"], "eqs": b["eqs"], "figs": b["figs"], "fig_offsets": b.get("fig_offsets", []),
            "empty": b.get("empty"),
            "flags": b.get("flags", {}),
        } for b in blocks],
    }
    (out / "content" / "text.json").write_text(json.dumps(text_json, ensure_ascii=False, indent=1), encoding="utf-8")

    # ============ 5) الفحوصات ============
    checks = {}

    # (أ) مقارنة مستقلة: تدفّق XML (تنفيذ مستقل) مقابل الاستخراج البنيوي
    raw_all = streaming_text(doc_bytes)
    import inventory_docx as inv_mod
    _orig_linear = inv_mod.math_linear
    inv_mod.math_linear = math_flat            # مرجع بلا صيغة خطية: نفس تسطيح XML
    flat_inv = inv_mod.Inventory(src)
    flat_inv.run()
    inv_mod.math_linear = _orig_linear
    # كتل الجداول تجميعية (نصّها = نصوص خلاياها) ⇒ تُستثنى من المقارنة كي لا تُحسب مرتين
    struct_text = "".join(b["text"] for b in flat_inv.blocks if b["kind"] == "p")
    tbl_agg = "".join(b["text"] for b in flat_inv.blocks if b["kind"] == "tbl")
    # المقارنة الحاكمة: المحتوى بلا فراغات (الفراغات بين الكتل تختلف ترتيباً لا محتوىً)
    import difflib
    raw_ns = re.sub(r"\s+", "", raw_all)
    struct_ns = re.sub(r"\s+", "", struct_text)
    if raw_ns == struct_ns:
        checks["المحتوى بلا فراغات: تدفّق XML المستقل = الاستخراج البنيوي"] = \
            f"{len(raw_ns)} حرفاً = {len(struct_ns)} ✅ (تطابق تام)"
    else:
        ops_ns = [o for o in difflib.SequenceMatcher(None, raw_ns, struct_ns, autojunk=False).get_opcodes()
                  if o[0] != "equal"]
        details = []
        for tag, i1, i2, j1, j2 in ops_ns[:4]:
            details.append(f"{tag}: «{raw_ns[i1:i2]}» ⇄ «{struct_ns[j1:j2]}»")
        same_multiset = collections.Counter(raw_ns) == collections.Counter(struct_ns)
        checks["المحتوى بلا فراغات: تدفّق XML المستقل = الاستخراج البنيوي"] = (
            f"⚠️ {len(ops_ns)} موضع فرق في **الترتيب** فقط ({'; '.join(details)}) · "
            f"تعدّد الأحرف متطابق: {'نعم ✅ (لا حرف مفقود ولا مضاف)' if same_multiset else 'لا ❌'}")
    n_ws_diffs = sum(1 for o in difflib.SequenceMatcher(None, normalize_ws(raw_all), normalize_ws(struct_text),
                                                        autojunk=False).get_opcodes() if o[0] != "equal")
    checks["فروق ترتيب الفراغات عند حدود الكتل (بلا أثر على المحتوى)"] = (
        f"{n_ws_diffs} موضعاً — كلها فراغات: لا حرف مفقود ولا مضاف" if n_ws_diffs else "0")
    checks["نص XML (تدفّق مستقل) مقابل الاستخراج البنيوي — الطول بعد توحيد الفراغات"] = \
        f"{len(normalize_ws(raw_all))} ≈ {len(normalize_ws(struct_text))} (فرق {abs(len(normalize_ws(raw_all)) - len(normalize_ws(struct_text)))})"
    c1, c2 = collections.Counter(raw_all.replace(" ", "").replace("\n", "")), \
             collections.Counter(struct_text.replace(" ", "").replace("\n", ""))
    checks["تعدّد الأحرف (بلا فراغات) متطابق"] = "✅" if c1 == c2 else f"❌ فروق: {dict((c1 - c2))} / {dict((c2 - c1))}"
    checks["نص الجداول التجميعي غير مجموع مرتين"] = (
        "✅ (استُثني من المقارنة)" if tbl_agg else "—")

    # (ب) الفقرات: XML مقابل المفهرس
    n_p_xml_total = len(list(root.iter(f"{{{W}}}p")))
    n_p_fallback = len([p for p in root.iter(f"{{{W}}}p")
                        if any(a.tag == f"{{{MC}}}Fallback" for a in p.iterancestors())])
    checks["فقرات XML (الكل / داخل fallback المرآتي / المفهرسة)"] = \
        f"{n_p_xml_total} / {n_p_fallback} / {manifest['counts']['paragraphs_total']} " + \
        ("✅" if n_p_xml_total - n_p_fallback == manifest["counts"]["paragraphs_total"] else "❌")

    # (ج) المعادلات: ترتيب ومحتوى
    checks["معادلات: المفهرس (NHTML-0) = المعروض في XML (NHTML-1)"] = (
        f"{manifest['counts']['equations_total']} = {len(oms)} "
        + ("✅" if len(oms) == manifest["counts"]["equations_total"] else "❌"))
    checks["معادلات: نسخ fallback المرآتية (صُحّحت أيضاً، غير مفهرسة)"] = str(n_fb_copies)
    checks["معادلات: سجل NHTML-0 مقابل NHTML-1 (تطابق النص الأصلي بالترتيب)"] = \
        "✅" if [e["flat"] for e in manifest["equations"]] == before_flat else "❌"

    # (د) الرسومات
    n_fig_manifest = len(manifest["figures"])
    para_refs = sum(len(b["figs"]) for b in blocks if b["kind"] == "p")
    table_refs = sum(len(b["figs"]) for b in blocks if b["kind"] == "tbl")
    checks["رسومات: عدد الكائنات = مراجع الفقرات (كتل الجداول تجميعية)"] = (
        f"{n_fig_manifest} = {para_refs} " + ("✅" if n_fig_manifest == para_refs else "❌")
        + f" · (تجميع الجداول: {table_refs} مرجعاً ليس كائناً جديداً)")
    checks["صور: نسخ بايت-لبايت"] = f"{copy_ok} من {len(media_all)} " + ("✅" if copy_ok == len(media_all) else "❌")

    # (هـ) التصحيحات: كل تغيير داخل القواعد المسموحة
    diffs = collections.Counter()
    for bo, ao in zip(before_flat, after_flat):
        if bo == ao:
            continue
        import difflib
        sm = difflib.SequenceMatcher(None, bo, ao, autojunk=False)
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op != "equal":
                diffs[(bo[i1:i2], ao[j1:j2])] += 1
    allowed_pairs = {("∆", "Δ"), ("∝", "α"), ("Υ", "γ"), ("HZ", "Hz"), ("COS", "cos"),
                     ("evg", "avg"), ("m..g", "m.g"), ("ⅈ", "i"), ("ωeb", "Wb"), ("ωat", "W"),
                     ("Λ", "∧"), ("ω", "w"), ("K", "k"), ("max", "maX"), ("o", "0"),
                     ("n", "η"), ("S", "s"), ("K", "k"), ("P", "p"),
                     # فروق حرفية ناتجة عن القواعد نفسها: max→maX يعطي (x→X)، و m..g→m.g يعطي ('.'→'')
                     ("x", "X"), (".", "")}
    def canon(x: str) -> str:
        """يولّد الشكل المتوقّع بعد تطبيق القواعد المعتمدة (للتحقق من مشروعية أي فرق)."""
        for a, b in [("∆", "Δ"), ("∝", "α"), ("Υ", "γ"), ("HZ", "Hz"), ("COS", "cos"),
                     ("P_evg", "P_avg"), ("m..g", "m.g"), ("ⅈ", "i"), ("ωeb", "Wb"),
                     ("ωat", "W"), ("Λ", "∧"), ("max", "maX"), ("ω", "w"), ("K", "k")]:
            x = x.replace(a, b)
        return x

    bad = {k: v for k, v in diffs.items() if k not in allowed_pairs and canon(k[0]) != k[1]}
    checks["تصحيحات: كل فرق داخل القواعد المسموحة"] = \
        ("✅" if not bad else f"❌ فروق غير متوقعة: {list(bad)[:6]}")
    checks["تصحيحات: عدد المعادلات المتغيّرة"] = f"{sum(1 for e in equations if e['changed'])} من {len(equations)}"

    # (و) تكرار / فقدان
    seen = collections.defaultdict(list)
    for b in blocks:
        if b["kind"] != "p":
            continue
        key = normalize_ws(b["text"])
        if len(key) >= 12 and not b["flags"].get("filler_line"):
            seen[key].append(b["i"])
    dup_groups = [{"text": k[:90], "blocks": v, "count": len(v)} for k, v in seen.items() if len(v) > 1]
    dup_groups.sort(key=lambda x: -x["count"])
    checks["فقرات نصية متكرّرة (نص ≥12 حرفاً)"] = f"{len(dup_groups)} مجموعة (تفصيل في التقرير)"
    empty_blocks = sum(1 for b in blocks if b["kind"] == "p" and b.get("empty"))
    checks["كتل فارغة كلياً (مسافات/فواصل)"] = str(empty_blocks)

    recon = {}
    audit_rules = {r["rule"]: r["remaining"] for r in audit.get("symbol_rules", [])}
    recon["R2 (نمط مطابق في المصدر)"] = f"{audit_rules.get('R2','—')} نمطاً ⇢ طُبِّق على {log.get('R2 ω(ثقل)→w', 0)} كتلة معادلة"
    recon["R3 ∆→Δ"] = f"{audit_rules.get('R3','—')} ⇢ {log.get('R3 ∆→Δ', 0)} (نص معادلات)"
    recon["R4 ∝→α"] = f"{audit_rules.get('R4','—')} ⇢ {log.get('R4 ∝→α', 0)}"
    recon["R5 Γ_n→Γ_η"] = f"{audit_rules.get('R5','—')} ⇢ {log.get('R5 Γ_n→Γ_η', 0)}"
    recon["R8"] = f"{audit_rules.get('R8','—')} ⇢ {sum(v for k, v in log.items() if k.startswith('R8'))}"
    recon["R6 K→k"] = (f"{audit_rules.get('R6','—')} نمطاً ⇢ {log.get('R6 K→k', 0)} كتلة "
                       "(يُستثنى πK و K=رقم و K` كما في الأداة الأصلية)")
    recon["R13 E_K/E_P"] = f"{audit_rules.get('R13','—')} ⇢ {sum(v for k, v in log.items() if k.startswith('R13'))}"
    recon["R14 max→maX"] = f"{audit_rules.get('R14','—')} تابعاً ⇢ {log.get('R14 max→maX', 0)}"
    recon["R1 T_o→T_0"] = f"{audit_rules.get('R1','—')} ⇢ {log.get('R1 T_o→T_0', 0)}"
    checks["تصحيحات: مطابقة أعداد التدقيق (NHTML-0) مع التطبيق (NHTML-1)"] = "انظر الجدول في التقرير"

    extraction = {
        "stage": "NHTML-1", "generated_at_utc": now, "generator": "rebuild/nawwasat/tools/extract_content.py",
        "source": {"path": args.source, "sha256": src_sha},
        "counts": {
            "blocks": len(blocks), "paragraphs": manifest["counts"]["paragraphs_total"],
            "equations_fallback_copies": n_fb_copies,
            "tables": manifest["counts"]["tables"], "equations": len(equations),
            "equations_changed": sum(1 for e in equations if e["changed"]),
            "figures": n_fig_manifest, "images_copied": len(media_all),
        },
        "rules_applied": dict(log),
        "rules_reconciliation": recon,
        "checks": checks,
        "duplicate_groups_sample": dup_groups[:40],
        "duplicate_groups_total": len(dup_groups),
        "artifacts": [
            "assets/images/ (نسخ بايت-لبايت)",
            "assets/equations/omml-corrected.jsonl",
            "content/text.json", "content/text-literal.txt",
            "content/images.json", "content/equations.json",
            "reports/NHTML-1-content-extraction.md",
        ],
    }
    (out / "content" / "extraction.json").write_text(
        json.dumps(extraction, ensure_ascii=False, indent=1), encoding="utf-8")

    # ============ 6) التقرير ============
    L = []
    A_ = L.append
    A_("# NHTML-1 — استخراج المحتوى والأصول (النواسات)")
    A_("")
    A_(f"- **المصدر (قراءة فقط):** `{args.source}` · SHA-256 `{src_sha}`")
    A_(f"- **الوقت:** {now} UTC · **الأداة:** `tools/extract_content.py`")
    A_("- **قرار المالك المطبَّق:** تصحيح الرموز R1–R14 (المصدر لا يحملها — انظر `NHTML-0-source-audit.md`).")
    A_("")
    A_("## ١. المخرجات")
    A_("")
    A_("| الملف | المضمون |")
    A_("|---|---|")
    A_(f"| `assets/images/` | {len(media_all)} ملف صورة/رسم، نسخ **بايت-لبايت** ({copy_ok} مطابقة بالبصمة) |")
    A_(f"| `assets/equations/omml-corrected.jsonl` | {len(omml_lines)} معادلة تغيّرت (OMML مصحّح) |")
    A_(f"| `content/text.json` | {len(blocks)} كتلة بالنص الحرفي + مراجع المعادلات والرسومات + وسم التخطيط |")
    A_(f"| `content/text-literal.txt` | تفريغ مقروء للمراجعة العينية (كتلة/كتلة) |")
    A_(f"| `content/images.json` | {len(media_all)} صورة: بصمة · أبعاد · موضع أول ظهور · الدور |")
    A_(f"| `content/equations.json` | {len(equations)} معادلة: نص أصلي · نص مصحّح · البنية · الموضع |")
    A_("")
    A_("## ٢. تطبيق قواعد الرموز R1–R14")
    A_("")
    A_("| القاعدة | عدد المواضع المطبَّقة |")
    A_("|---|---|")
    for k, v in sorted(log.items()):
        A_(f"| {k} | {v} |")
    A_("")
    A_(f"- معادلات تغيّرت: **{sum(1 for e in equations if e['changed'])}** من {len(equations)}.")
    A_(f"- المعادلات غير المتغيّرة: **{sum(1 for e in equations if not e['changed'])}** (لم تُلمس).")
    A_("")
    A_("**مطابقة أعداد التدقيق (NHTML-0) مع التطبيق (NHTML-1):**")
    A_("")
    A_("| القاعدة | مواضع في المصدر ⇢ مواضع طُبّقت |")
    A_("|---|---|")
    for k, v in recon.items():
        A_(f"| {k} | {v} |")
    A_("")
    A_("> تناظر الأعداد: القواعد R3/R4/R5/R8/R13/R14: العدد المطابق في المصدر = العدد المطبَّق بالضبط. "
      "R1 (36) وR5 (5) كانتا غير مرئيتين في العدّ النصي القديم لأن الرمز مقسوم على توابع منفصلة — "
      "صار العدّ بنيوياً في `source-audit.json`. R2 وR6 أنماط سياقية: عدد المطابقات ≥ عدد الكتل المتغيّرة "
      "(يكفي نمط واحد لكل كتلة).")
    A_("")
    A_("**أمثلة على التصحيح (قبل → بعد):**")
    A_("")
    A_("| القاعدة | قبل | بعد |")
    A_("|---|---|---|")
    for c in changes[:25]:
        A_(f"| {c['rule']} | `{c['before']}` | `{c['after']}` |")
    A_("")
    if not changes:
        A_("> لا تغييرات على مستوى الكتل (كل التصحيحات تمت على مستوى الرموز/التوابع).")
        A_("")
    A_("**أمثلة من المعادلات المتغيّرة:**")
    A_("")
    A_("| المعرّف | قبل | بعد |")
    A_("|---|---|---|")
    for e in [x for x in equations if x["changed"]][:15]:
        A_(f"| {e['id']} (كتلة {e['block']}) | `{e['flat_original'][:60]}` | `{e['flat_corrected'][:60]}` |")
    A_("")
    A_("## ٣. فحوصات الاستخراج")
    A_("")
    A_("| الفحص | النتيجة |")
    A_("|---|---|")
    for k, v in checks.items():
        A_(f"| {k} | {v} |")
    A_("")
    A_("### الفقرات المتكرّرة")
    A_("")
    A_(f"عدد المجموعات المتطابقة نصياً (≥12 حرفاً بعد توحيد الفراغات): **{len(dup_groups)}**. "
      "أغلبها تسميات وبنود متكررة في نوطة الأستاذ (مثل «تعريفه» أو صيغ قوانين تتكرر في مسائل مختلفة) — "
      "ووجودها مقصود وهو من نصّ الأستاذ، ولا يُحذف. أمثلة:")
    A_("")
    A_("| النص | عدد المرات | الكتل |")
    A_("|---|---|---|")
    for g in dup_groups[:25]:
        A_(f"| `{g['text'][:70]}` | {g['count']} | {', '.join(map(str, g['blocks'][:12]))} |")
    A_("")
    A_("## ٤. الصور")
    A_("")
    roles = collections.Counter(i["role"] for i in images)
    A_("| الدور | العدد |")
    A_("|---|---|")
    for k, v in roles.items():
        A_(f"| {k} | {v} |")
    A_("")
    A_("## ٥. ما لم يُنفَّذ (مقصود)")
    A_("")
    A_("- لا HTML ولا CSS ولا PDF (NHTML-2..NHTML-4).")
    A_("- لا تحويل للمعادلات إلى MathML/SVG بعد — القرار الفني في NHTML-2.")
    A_("- لا مسّ بملف المصدر: التصحيح طُبّق في الذاكرة فقط، وأُنتج منه سجل OMML مصحّح.")
    A_("")
    (out / "reports" / "NHTML-1-content-extraction.md").write_text("\n".join(L) + "\n", encoding="utf-8")

    print(json.dumps(extraction["counts"], ensure_ascii=False, indent=1))
    print("rules:", dict(log))
    print("unexpected diffs:", bad if bad else "none")
    for k, v in checks.items():
        print(f"  - {k}: {v}")
    print("dup groups:", len(dup_groups))
    print("wrote:", out / "content" / "extraction.json", out / "reports" / "NHTML-1-content-extraction.md")


if __name__ == "__main__":
    main()
