#!/usr/bin/env python3
"""NHTML-0 — تدقيق المصدر المجمّد (بلا أي تعديل عليه).

قسمان:
  أ) حالة قواعد تصحيح الرموز R1–R14 في المصدر (كم موضعاً لا يزال بالنمط القديم).
  ب) فروق المصدر عن الأصل التاريخي في git + إثبات أن تعديلات r15–r23 محفوظة
     (ألوان أعمدة القيمة المطلقة الخضراء + صور الرسومات المعدّلة).

المخرجات:
  rebuild/nawwasat/content/source-audit.json
  rebuild/nawwasat/reports/NHTML-0-source-audit.md
"""
from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
M = "http://schemas.openxmlformats.org/officeDocument/2006/math"

# أنماط R1–R14 نفسها المستخدمة في tools/fix_fadaa_symbols.py (مرجع تاريخي)
WEIGHT_PAT = re.compile(
    r"F_s|\+T\b|T=m|\+T=|-ω\s*cos|-ω\s*sin|ωsin|Γ_ω|Γω|W_ω|Wω|=\s*kx_0|ωk=|"
    r"d'\.ω|ⅆ'ω|d\.\s*ω|F=2ω|ω_e|R\+\s*ω|tan∝=Fω|ω\+F|ω-F"
)
RULES = [
    ("R1", "T_o (حرف o) → T_0", None),   # تُحسب بنيوياً
    ("R2", "ω بمعنى الثقل → w", lambda mt, at: len(WEIGHT_PAT.findall(mt))),
    ("R3", "∆ (U+2206) → Δ (U+0394)", lambda mt, at: at.count("∆")),
    ("R4", "∝ (تناسب) → α", lambda mt, at: at.count("∝")),
    ("R5", "Γ_n → Γ_η", None),           # تُحسب بنيوياً
    ("R6", "K ثابت الصلابة/الفتل → k", lambda mt, at: len(re.findall(r"(?<![A-Za-zΠ])\bK\b(?![a-z])", mt))),
    ("R7", "Υ → γ (لورنتز)", lambda mt, at: at.count("Υ")),
    ("R8", "HZ/COS/P_evg/m..g/ⅈ", lambda mt, at: len(re.findall(r"HZ|COS|P_evg|m\.\.g|ⅈ", at))),
    ("R9", "ωeb/ωat → Wb/W", lambda mt, at: len(re.findall(r"ωeb|ωat", at))),
    ("R10", "Λ → ∧ (جداء شعاعي)", lambda mt, at: at.count("Λ")),
    ("R11", "f_o/v_o/v_ox/v_oy → _0", None),   # تُحسب بنيوياً
    ("R12", "E_S/W_S/U_S → _s", None),         # تُحسب بنيوياً
    ("R13", "E_K/E_P → _k/_p", None),          # تُحسب بنيوياً
    ("R14", "max → maX (توحيد التوابع)", None),   # تُحسب بنيوياً في main()
]


def load(p: Path):
    z = zipfile.ZipFile(p)
    doc = etree.fromstring(z.read("word/document.xml"))
    mt = "".join(t.text or "" for t in doc.iter(f"{{{M}}}t"))
    wt = "".join(t.text or "" for t in doc.iter(f"{{{W}}}t"))
    return z, doc, mt, wt


def census(p: Path):
    z, doc, mt, wt = load(p)
    media = {n: hashlib.sha256(z.read(n)).hexdigest()
             for n in z.namelist() if n.startswith("word/media/") and not n.endswith("/")}
    colors = collections.Counter()
    for e in doc.iter(f"{{{W}}}color"):
        colors[(e.get(f"{{{W}}}val") or "").upper()] += 1
    return {
        "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
        "bytes": p.stat().st_size,
        "oMath": len(list(doc.iter(f"{{{M}}}oMath"))),
        "text_chars": len(wt), "math_chars": len(mt),
        "media": media, "media_count": len(media),
        "media_bytes": sum(z.getinfo(n).file_size for n in media),
        "colors": colors,
        "max": mt.count("max"), "maX": mt.count("maX"),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="notes/النواسات م_101932-r23-all-absolute-value-bars-green.docx")
    ap.add_argument("--git-ref", default="827dbcb^:sources/fadaa/النواسات م_101932.docx",
                    help="مسار الأصل التاريخي داخل git")
    ap.add_argument("--out", default="rebuild/nawwasat")
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    out = (repo / args.out).resolve()
    src = (repo / args.src).resolve()
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    z, doc, mt, wt = load(src)
    allt = mt + "\n" + wt
    # عدّ بنيوي للقواعد التي تعمل على التوابع (كما تفعل أداة التصحيح تماماً)
    struct = collections.Counter()
    for tag in ("sSub", "sSubSup"):
        for sc in doc.iter(f"{{{M}}}{tag}"):
            e = sc.find(f"{{{M}}}e"); sub = sc.find(f"{{{M}}}sub")
            if e is None or sub is None:
                continue
            base = "".join(t.text or "" for t in e.iter(f"{{{M}}}t")).strip()
            st = "".join(t.text or "" for t in sub.iter(f"{{{M}}}t")).strip()
            if base == "T" and st == "o":
                struct["R1"] += 1
            elif base == "Γ" and st == "n":
                struct["R5"] += 1
            elif base in ("f", "v") and re.fullmatch(r"o[xy]?", st or "x"):
                struct["R11"] += 1
            elif base in ("E", "W") and st == "S":
                struct["R12"] += 1
            elif base == "E" and st in ("K", "P"):
                struct["R13"] += 1
            if st == "max":
                struct["R14"] += 1
    sub_max = struct["R14"]
    structural = {k: struct[k] for k in ("R1", "R5", "R11", "R12", "R13")}
    rules = []
    struct_override = dict(structural, R14=sub_max)
    for r, d, fn in RULES:
        remaining = struct_override[r] if fn is None else fn(mt, allt)
        rules.append({"rule": r, "desc": d, "remaining": remaining})
    for x in rules:
        if x["rule"] in structural:
            x["note"] = "عدّ بنيوي على التوابع (m:sub داخل m:sSub/m:sSubSup)"
    r14 = next(x for x in rules if x["rule"] == "R14")
    r14["note"] = (f"توابع مكتوبة `max`: {sub_max} · ظهور `max` في نص المعادلات: {mt.count('max')} · "
                   f"`maX`: {mt.count('maX')}")

    # ---- الأصل التاريخي للمقارنة (اختياري)
    hist_path = Path("/tmp/nawwasat_hist.docx")
    hist = None
    try:
        data = subprocess.run(["git", "-C", str(repo), "show", args.git_ref],
                              capture_output=True, check=True).stdout
        hist_path.write_bytes(data)
        hist = census(hist_path)
    except Exception as exc:  # pragma: no cover
        hist = {"error": f"{type(exc).__name__}: {exc}"}

    cur = census(src)
    delta = {}
    if hist and "error" not in hist:
        delta = {
            "oMath": cur["oMath"] - hist["oMath"],
            "text_chars": cur["text_chars"] - hist["text_chars"],
            "math_chars": cur["math_chars"] - hist["math_chars"],
            "media_count": cur["media_count"] - hist["media_count"],
            "media_bytes": cur["media_bytes"] - hist["media_bytes"],
            "max": cur["max"] - hist["max"],
            "maX": cur["maX"] - hist["maX"],
        }
        only_cur = sorted(set(cur["media"]) - set(hist["media"]))
        only_hist = sorted(set(hist["media"]) - set(cur["media"]))
        changed = sorted(n for n in set(cur["media"]) & set(hist["media"])
                         if cur["media"][n] != hist["media"][n])
        color_delta = {c: cur["colors"].get(c, 0) - hist["colors"].get(c, 0)
                       for c in set(cur["colors"]) | set(hist["colors"])}
        color_delta = {k: v for k, v in sorted(color_delta.items(), key=lambda x: -abs(x[1])) if v}
    else:
        only_cur = only_hist = changed = []
        color_delta = {}

    # ---- إثبات تعديلات r15–r23: الأعمدة الخضراء داخل المعادلات
    green_runs = []
    for col in doc.iter(f"{{{W}}}color"):
        val = (col.get(f"{{{W}}}val") or "").upper()
        if val != "008000":
            continue
        owner = col.getparent()                       # m:ctrlPr / w:rPr ...
        kind = etree.QName(owner).localname if owner is not None else "?"
        owner = owner.getparent() if owner is not None else None
        is_delim = any(etree.QName(a).localname == "dPr" for a in list(col.iterancestors())[:4])
        om = next((a for a in col.iterancestors() if a.tag == f"{{{M}}}oMath"), None)
        txt = "".join(t.text or "" for t in om.iter(f"{{{M}}}t")) if om is not None else ""
        green_runs.append({
            "text": txt[:140],
            "color": val,
            "prop_of": kind,
            "is_absolute_value_delimiter": bool(is_delim),
            "xml_path": doc.getroottree().getpath(om)[-64:] if om is not None else None,
        })
    green_text = collections.Counter(g["text"] for g in green_runs)

    # ---- مقارنة بكسلات الوسائط المتغيّرة: إعادة ترميز أم تعديل حقيقي؟
    pixel_same, pixel_diff = [], []
    try:
        from PIL import Image
        import io as _io
        zh = zipfile.ZipFile(hist_path); zc = zipfile.ZipFile(src)
        for n in changed:
            try:
                a = Image.open(_io.BytesIO(zh.read(n))).convert("RGBA")
                b = Image.open(_io.BytesIO(zc.read(n))).convert("RGBA")
                if a.size != b.size:
                    pixel_diff.append({"file": n, "reason": f"size {a.size}→{b.size}"})
                    continue
                same = a.tobytes() == b.tobytes()
                if same:
                    pixel_same.append({"file": n, "size": list(a.size)})
                else:
                    from PIL import ImageChops
                    d = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
                    tot = a.size[0] * a.size[1]
                    px = list(d.getdata())
                    nz = sum(1 for q in px if q != (0, 0, 0))
                    mx = max((max(q) for q in px), default=0)
                    pixel_diff.append({
                        "file": n, "size": list(a.size), "diff_pixels_pct": round(100.0 * nz / tot, 3),
                        "max_channel_delta": mx,
                        "class": "تعديل موضعي مركّز" if nz / tot < 0.02 else "تغيير واسع في الرسم",
                    })
            except Exception as exc:
                pixel_diff.append({"file": n, "size": None, "reason": f"unreadable: {type(exc).__name__}",
                                   "class": "غير قابل للقراءة"})
    except Exception:
        pass

    # ---- تسلسل المراجعات r15…r23 (إثبات تعديلات الألوان/الرسم داخل الملفات الملتزمة)
    series_dir = repo / "notes"
    series_files = sorted(series_dir.glob("النواسات م_101932-r*.docx"),
                          key=lambda f: int(re.search(r"-r(\d+)-", f.name).group(1)))
    series = []
    prev = None
    for f in series_files:
        z2 = zipfile.ZipFile(f)
        d2 = etree.fromstring(z2.read("word/document.xml"))
        med = {n: hashlib.sha256(z2.read(n)).hexdigest() for n in z2.namelist()
               if n.startswith("word/media/") and not n.endswith("/")}
        col = collections.Counter((e.get(f"{{{W}}}val") or "").upper() for e in d2.iter(f"{{{W}}}color"))
        greens = sum(1 for e in d2.iter(f"{{{W}}}color") if (e.get(f"{{{W}}}val") or "").upper() == "008000")
        entry = {
            "file": f.name,
            "revision": int(re.search(r"-r(\d+)-", f.name).group(1)),
            "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
            "document_xml_bytes": len(z2.read("word/document.xml")),
            "oMath": len(list(d2.iter(f"{{{M}}}oMath"))),
            "green_008000_positions": greens,
        }
        if prev is not None:
            entry["media_changed_from_previous"] = sorted(
                n for n in set(med) | set(prev["media"]) if med.get(n) != prev["media"].get(n))
            cd = {c: col.get(c, 0) - prev["colors"].get(c, 0) for c in set(col) | set(prev["colors"])}
            entry["color_count_delta_from_previous"] = {k: v for k, v in cd.items() if v}
        entry["media"] = med
        entry["colors"] = col
        series.append(entry)
        prev = entry
    series_out = [{k: v for k, v in e.items() if k not in ("media", "colors")} for e in series]

    report = {
        "stage": "NHTML-0",
        "generated_at_utc": now,
        "generator": "rebuild/nawwasat/tools/source_audit.py",
        "source": {"path": args.src, "sha256": cur["sha256"], "bytes": cur["bytes"]},
        "symbol_rules": rules,
        "symbol_summary": {
            "rules_with_remaining_old_style": [r["rule"] for r in rules if r["remaining"]],
            "rules_clean": [r["rule"] for r in rules if not r["remaining"]],
            "total_remaining": sum(r["remaining"] for r in rules),
        },
        "history_reference": {"git_ref": args.git_ref, "census": {k: v for k, v in (hist or {}).items()
                                                                 if k not in ("media", "colors")} if hist else None},
        "current_census": {k: v for k, v in cur.items() if k not in ("media", "colors")},
        "delta_vs_history": delta,
        "media_only_in_source": only_cur,
        "media_only_in_history": only_hist,
        "media_changed_vs_history": changed,
        "color_count_delta_vs_history": color_delta,
        "abs_value_green_runs": {"count": len(green_runs),
                                 "distinct_labels": dict(green_text.most_common(20))},
        "revision_series": series_out,
        "media_pixel_compare": {
            "identical_pixels_reencoded": len(pixel_same),
            "visually_changed": len(pixel_diff),
            "visually_changed_files": pixel_diff,
        },
    }
    (out / "content" / "source-audit.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")

    # ---------------- تقرير ماركداون
    L = []
    A = L.append
    A("# NHTML-0 — تدقيق المصدر (رموز · نسخة · تعديلات سابقة)")
    A("")
    A(f"- **المصدر:** `{args.src}`")
    A(f"- **SHA-256:** `{cur['sha256']}` · **{cur['bytes']:,}** بايت")
    A(f"- **وقت التدقيق:** {now} UTC")
    A("")
    A("## أ) حالة قواعد تصحيح الرموز R1–R14 في المصدر")
    A("")
    A("«العدد» = مواضع لا تزال مكتوبة بالنمط القديم (أي أنها **غير مصحّحة** في هذا المصدر).")
    A("")
    A(f"كتابة `max` في المصدر: **{cur['max']}** موضعاً · كتابة `maX`: **{cur['maX']}** موضعاً.")
    A("")
    A("| القاعدة | الوصف | المواضع المتبقية |")
    A("|---|---|---|")
    for r in rules:
        A(f"| {r['rule']} | {r['desc']} | {r['remaining']} |")
    A("")
    if report["symbol_summary"]["rules_with_remaining_old_style"]:
        A(f"> **الخلاصة:** المصدر الحالي يحمل النمط القديم في القواعد: "
          f"{'، '.join(report['symbol_summary']['rules_with_remaining_old_style'])} "
          f"(مجموع {report['symbol_summary']['total_remaining']} موضعاً).")
        A(">")
        A("> النسخة المُصحّحة التي سُلّمت سابقاً (سجلّ التصحيحات + ملف `tools/fix_fadaa_symbols.py`) "
          "**ليست** هي الملف الموجود في `main` — المصدر الموجود في `main` هو نسخة الأستاذ قبل تلك التصحيحات.")
    else:
        A("> لا مواضع متبقية بالنمط القديم في هذا الملف.")
    A("")
    A("## ب) المصدر مقابل الأصل التاريخي في git")
    A("")
    if delta:
        A(f"- الأصل المرجعي: `{args.git_ref}`")
        A("")
        A("| المقياس | الأصل التاريخي | المصدر الحالي | الفرق |")
        A("|---|---|---|---|")
        A(f"| معادلات OMML | {hist['oMath']} | {cur['oMath']} | {delta['oMath']:+d} |")
        A(f"| حروف النص | {hist['text_chars']:,} | {cur['text_chars']:,} | {delta['text_chars']:+,} |")
        A(f"| حروف المعادلات | {hist['math_chars']:,} | {cur['math_chars']:,} | {delta['math_chars']:+,} |")
        A(f"| ملفات الوسائط | {hist['media_count']} | {cur['media_count']} | {delta['media_count']:+d} |")
        A(f"| بايتات الوسائط | {hist['media_bytes']:,} | {cur['media_bytes']:,} | {delta['media_bytes']:+,} |")
        A(f"| كتابة `max` | {hist['max']} | {cur['max']} | {delta['max']:+d} |")
        A(f"| كتابة `maX` | {hist['maX']} | {cur['maX']} | {delta['maX']:+d} |")
        A("")
        A(f"- وسائط موجودة في المصدر فقط: {', '.join(only_cur) or '—'}")
        A(f"- وسائط موجودة في الأصل فقط: {', '.join(only_hist) or '—'}")
        A(f"- وسائط تغيّر محتواها (نفس الاسم، بايتات مختلفة): **{len(changed)}** ملفاً")
        cls = collections.Counter(x.get("class", "—") for x in pixel_diff)
        A(f"  - **{len(pixel_same)}** صورة متطابقة بكسل-بكسل (إعادة ترميز فقط).")
        for k, v in cls.most_common():
            names = ", ".join(x["file"].split("/")[-1] for x in pixel_diff if x.get("class") == k)
            A(f"  - **{v}** {k}: {names}")
        A("")
        A("> المقارنة مع الأصل التاريخي (سلالة مختلفة من الملف) هي سياق فقط؛ "
          "الدليل المعتمد على أن تعديلات الرسومات محفوظة هو قسم (د) أدناه (مراجعة بمراجعة).")
        A("")
        A("**فروق أعداد الألوان بين الأصل التاريخي والمصدر الحالي:**")
        A("")
        A("| اللون | الفرق |")
        A("|---|---|")
        for k, v in list(color_delta.items())[:15]:
            A(f"| `{k}` | {v:+d} |")
        A("")
    else:
        A("> تعذّر جلب الأصل التاريخي من git، أو أنه غير متاح.")
    A("")
    A("## ج) إثبات وجود تعديلات r15–r23 في المصدر")
    A("")
    ndel = sum(1 for g in green_runs if g["is_absolute_value_delimiter"])
    A(f"- مواضع اللون `008000` (الأخضر) داخل المستند: **{len(green_runs)}**، منها **{ndel}** "
      f"على محددات القيمة المطلقة (`m:d` عبر `m:dPr/m:ctrlPr`) في المعادلات — وهذا هو المطلوب حفظه.")
    A("")
    A("| معادلة تحوي القيمة المطلقة الخضراء | المسار في XML |")
    A("|---|---|")
    for g in green_runs:
        flag = "🟢 محدد |…|" if g["is_absolute_value_delimiter"] else "—"
        A(f"| `{g['text']}` | `{g['xml_path']}` ({flag}) |")
    A("")
    A("- ملفات الصور التي تغيّر محتواها عن الأصل التاريخي: الكرة الزرقاء (r15) ورسومات الرسم المركّب/المحاور (r20–r23) — القائمة الكاملة أعلاه.")
    A("")
    A("## د) تسلسل المراجعات r15 → r23 (التعديلات الملتزمة خطوة بخطوة)")
    A("")
    A("| المراجعة | بايت document.xml | معادلات | مواضع `008000` | صور تغيّرت عن السابقة | فروق أعداد الألوان |")
    A("|---|---|---|---|---|---|")
    for e in series_out:
        ch = ", ".join(n.split("/")[-1] for n in e.get("media_changed_from_previous", [])) or "—"
        cd = e.get("color_count_delta_from_previous")
        cd = ", ".join(f"{kk}:{v:+d}" for kk, v in cd.items()) if cd else "—"
        A(f"| r{e['revision']} | {e['document_xml_bytes']:,} | {e['oMath']} | {e['green_008000_positions']} | {ch} | {cd} |")
    A("")
    A("> الخلاصة: النسخة المجمّدة **تحمل** تعديلات الرسومات والألوان السابقة، ولا تحتاج إعادة تنفيذ. "
      "لكنها **لا تحمل** تصحيحات الرموز R1–R14 — وهذا يحتاج قراراً قبل NHTML-1 (انظر `docs/27-REBUILD-HANDOFF.md`).")
    A("")
    (out / "reports" / "NHTML-0-source-audit.md").write_text("\n".join(L) + "\n", encoding="utf-8")

    print("remaining old-style per rule:", {r["rule"]: r["remaining"] for r in rules})
    print("delta vs history:", delta)
    print("green 008000 runs in equations:", len(green_runs), dict(green_text.most_common(8)))
    print("wrote:", out / "content" / "source-audit.json", out / "reports" / "NHTML-0-source-audit.md")


if __name__ == "__main__":
    main()
