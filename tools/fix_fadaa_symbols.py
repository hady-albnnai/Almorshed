#!/usr/bin/env python3
"""تصحيح الرموز في نوط الأستاذ فداء (docx) — تعديل نصوص المعادلات فقط، بلا مسّ بالتنسيق.

القواعد (كل قاعدة موثقة بمرجعها من الكتاب الوزاري):
  R1  T_o (حرف o)            → T_0                      الكتاب: T₀
  R2  ω بمعنى الثقل           → w                        الكتاب ص٢٢: «قوّة الثقل w»
  R3  ∆ (رمز الزيادة U+2206) → Δ (دلتا اليونانية)        الكتاب: I_Δ
  R4  ∝ (رمز التناسب)        → α (التسارع الزاوي / الزاوية)  الكتاب: α
  R5  Γ_n (n لاتينية)        → Γ_η                      الكتاب ص٢٢ (η)
  R6  K ثابت الصلابة/الفتل   → k                        الكتاب ص٢١، ص٢٥: «ثابت فتله k»، «ثابت الصلابة k»
  R7  Υ (أبسلون كبيرة)       → γ (معامل لورنتز)          النوطة نفسها تستعمل γ في مواضع أخرى
  R8  HZ → Hz · COS → cos · P_evg → P_avg · m..g → m.g · ⅈ → i  (أخطاء طباعية)
  R9  ωeb → Wb · ωat → W    (وحدتا الويبر والواط كُتبتا بحرف ω)
  R10 Λ (لامدا كبيرة)        → ∧ (الجداء الشعاعي)
  R11 f_o / v_o / v_ox / v_oy → f_0 / v_0 / v_0x / v_0y  الكتاب: f₀
  R12 E_S / W_S              → E_s / W_s                الكتاب ص٢٣٢: E_s، W_s، U_s
  R13 E_K / E_P              → E_k / E_p                الكتاب: E_k، E_p
  R14 توحيد الكتابة max → maX (الصيغة الغالبة في النوطة نفسها)
"""
from __future__ import annotations

import collections
import re
import shutil
import sys
import zipfile
from pathlib import Path

from lxml import etree

M = "http://schemas.openxmlformats.org/officeDocument/2006/math"
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
MT = f"{{{M}}}t"
WT = f"{{{W}}}t"

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
        if q.namespace != M:
            continue
        if q.localname == "t" and n.text:
            out.append(n.text)
        elif q.localname == "sub":
            out.append("_")
    return "".join(out)


def ptext(p) -> str:
    return "".join(t.text or "" for t in p.iter(WT))


def is_sub_base_keep(t_el) -> bool:
    """هل هذا الرمز ω هو أساس تابع من نوع ω_0 / ω_max / ω_r (نبض، يبقى)؟"""
    r = t_el.getparent()          # m:r
    e = r.getparent() if r is not None else None   # m:e ?
    if e is None or etree.QName(e).localname != "e":
        return False
    s = e.getparent()
    if s is None or etree.QName(s).localname not in ("sSub", "sSubSup"):
        return False
    sub = s.find(f"{{{M}}}sub")
    st = sim(sub).strip() if sub is not None else ""
    return st.startswith(("0", "max", "maX", "r", "1", "2")) or etree.QName(s).localname == "sSubSup"


def fix_document(xml: bytes, fname: str, log: collections.Counter, changes: list) -> bytes:
    root = etree.fromstring(xml)
    is_pend = "النواسات" in fname

    # ---- R1/R5/R11/R12/R13/R14: تعديلات على مستوى التوابع ----
    for tag in ("sSub", "sSubSup"):
        for s in root.iter(f"{{{M}}}{tag}"):
            e = s.find(f"{{{M}}}e"); sub = s.find(f"{{{M}}}sub")
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

    # ---- R2 (الثقل) و R6 (K) على مستوى الكتلة ----
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
                log["R2 ω(ثقل)→w"] += 1; changes.append((fname, "R2", before.strip()[:60], after.strip()[:60]))
        if is_pend and re.search(r"(?<![A-Za-z_])K(?![A-Za-z])", s) and not K_EXCLUDE.search(s):
            before = s
            for t in om.iter(MT):
                if t.text and re.search(r"(?<![A-Za-z])K(?![A-Za-z])", t.text):
                    t.text = re.sub(r"(?<![A-Za-z])K(?![A-Za-z])", "k", t.text)
            after = sim(om)
            if after != before:
                log["R6 K→k"] += 1; changes.append((fname, "R6", before.strip()[:60], after.strip()[:60]))

    # ---- استبدالات حرفية في نصوص المعادلات ----
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
                log[name] += t.text.count(a); t.text = t.text.replace(a, b)
    # ---- الرموز المقسّمة على عدة runs متتالية (P|e|v|g ، ω|eb ، ω|at) ----
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
    # ---- النص العادي: ∆ و HZ فقط ----
    for t in root.iter(WT):
        if not t.text:
            continue
        for a, b, name in (("∆", "Δ", "R3 ∆→Δ (نص)"), ("HZ", "Hz", "R8 HZ→Hz (نص)")):
            if a in t.text:
                log[name] += t.text.count(a); t.text = t.text.replace(a, b)
    return etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone=True)


def process(src: Path, dst: Path, dry: bool):
    log = collections.Counter(); changes = []
    zin = zipfile.ZipFile(src)
    new_doc = fix_document(zin.read("word/document.xml"), src.name, log, changes)
    if not dry:
        dst.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = new_doc if item.filename == "word/document.xml" else zin.read(item.filename)
                zout.writestr(item, data)
    return log, changes


if __name__ == "__main__":
    dry = "--dry" in sys.argv
    src_dir = Path("/home/user/fadaa_src"); out_dir = Path("/home/user/fadaa_notes_corrected")
    total = collections.Counter()
    for f in sorted(src_dir.glob("*.docx")):
        stem = f.stem.split(" م_")[0]
        log, changes = process(f, out_dir / f"{stem} — نوطة الأستاذ فداء (رموز مصحّحة).docx", dry)
        print(f"\n===== {stem}")
        for k, v in sorted(log.items()):
            print(f"   {v:4}  {k}")
        for c in changes:
            print(f"      [{c[1]}] {c[2]!r}  →  {c[3]!r}")
        total.update(log)
    print("\n===== المجموع"); [print(f"   {v:4}  {k}") for k, v in sorted(total.items())]
