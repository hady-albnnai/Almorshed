#!/usr/bin/env python3
"""NHTML-2 — بناء HTML دلالي RTL من المصدر المجمّد (بلا أي تعديل على المصدر).

يقرأ: source/original.docx + content/manifest.json (جرد NHTML-0)
ويُنتج: html/index.html  +  content/structure.json  +  reports/NHTML-2-structure.md

مبادئ البناء:
  • النص العربي rtl، والمعادلات ورموزها داخل حاويات ltr معزولة (MathML).
  • كل رسم داخل <figure>، وكل معادلة في عنصر مستقل — بلا float وبلا position:absolute.
  • الرسومات العائمة في Word تُعاد كعناصر ساكنة في التدفق بعد فقرتها المرجعية.
  • «العمودان» في Word (فراغات/تابات) تُعاد كشبكة CSS عمودين بالنص نفسه.
  • ترقيم القوائم من `word/numbering.xml` (فعلية بأشكالها: 1) · a) · • · -).
  • الشبكة الحقيقية (a:xfrm/profXMil) تُعطى كعرض SVG بلا ×1.59 (المصدر يرسم بتحويل، والشبكة تُحقّق النسبة).
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
import inventory_docx as inv_mod                      # noqa: E402
from inventory_docx import (Inventory, iter_effective, local, tag_of,   # noqa: E402
                            NS, W, M, A, MC, PIC, V, WPS, WPG, math_flat)
from omml_to_mathml import omml_to_mathml, wrap_math, esc, attr_esc      # noqa: E402
from extract_content import apply_rules                                   # noqa: E402

EMU_PER_CM = 360000.0
EMU_PER_MM = 36000.0


# ----------------------------------------------------------------- utilities
def cm(emu) -> float:
    try:
        return round(int(emu) / EMU_PER_CM, 3)
    except (TypeError, ValueError):
        return 0.0


def mm(emu) -> float:
    try:
        return round(int(emu) / EMU_PER_MM, 1)
    except (TypeError, ValueError):
        return 0.0


AR_RE = re.compile(r"[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]")


def has_ar(s: str) -> bool:
    return bool(AR_RE.search(s))


def style_of(run) -> dict:
    """خصائص مقطع نص عادي (w:r)."""
    st = {}
    if run is None:
        return st
    rpr = run.find(f"{{{W}}}rPr")
    if rpr is None:
        return st
    c = rpr.find(f"{{{W}}}color")
    if c is not None:
        v = (c.get(f"{{{W}}}val") or "").strip()
        if v and v.lower() != "auto":
            st["color"] = "#" + v.lstrip("#").upper()
    for tag, key in (("b", "bold"), ("i", "italic"), ("u", "underline")):
        e = rpr.find(f"{{{W}}}{tag}")
        if e is not None and e.get(f"{{{W}}}val", "1") not in ("0", "false"):
            st[key] = True
    sz = rpr.find(f"{{{W}}}sz")
    if sz is not None and (sz.get(f"{{{W}}}val") or "").isdigit():
        st["pt"] = int(sz.get(f"{{{W}}}val")) / 2
    va = rpr.find(f"{{{W}}}vertAlign")
    if va is not None:
        st["vert"] = va.get(f"{{{W}}}val")
    rtl = rpr.find(f"{{{W}}}rtl")
    if rtl is not None and rtl.get(f"{{{W}}}val", "1") != "0":
        st["rtl"] = True
    hl = rpr.find(f"{{{W}}}highlight")
    if hl is not None:
        st["highlight"] = hl.get(f"{{{W}}}val")
    return st


def style_css(st: dict) -> str:
    css = []
    if st.get("color"):
        css.append(f"color:{st['color']}")
    if st.get("bold"):
        css.append("font-weight:700")
    if st.get("italic"):
        css.append("font-style:italic")
    if st.get("underline"):
        css.append("text-decoration:underline")
    if st.get("pt"):
        css.append(f"font-size:{st['pt'] / 14:.3f}em")
    if st.get("vert") == "superscript":
        css.append("font-size:.72em;vertical-align:super")
    elif st.get("vert") == "subscript":
        css.append("font-size:.72em;vertical-align:sub")
    if st.get("highlight"):
        css.append(f"background-color:var(--hl-{attr_esc(st['highlight']).lower()},#fff3bf)")
    return ";".join(css)


# ----------------------------------------------------------------- numbering
class Numbering:
    """يقرأ numbering.xml ويولّد علامات القوائم الفعلية (كما يعرضها Word)."""

    def __init__(self, zf: zipfile.ZipFile):
        self.fmt = {}          # (numId, ilvl) -> (numFmt, lvlText, start)
        try:
            root = etree.fromstring(zf.read("word/numbering.xml"))
        except KeyError:
            return
        abstract = {}
        for a in root.iter(f"{{{W}}}abstractNum"):
            aid = a.get(f"{{{W}}}abstractNumId")
            lv = {}
            for lvl in a.findall(f"{{{W}}}lvl"):
                f_ = lvl.find(f"{{{W}}}numFmt")
                t_ = lvl.find(f"{{{W}}}lvlText")
                s_ = lvl.find(f"{{{W}}}start")
                lv[lvl.get(f"{{{W}}}ilvl")] = (
                    f_.get(f"{{{W}}}val") if f_ is not None else "decimal",
                    t_.get(f"{{{W}}}val") if t_ is not None else "%1.",
                    int(s_.get(f"{{{W}}}val")) if s_ is not None and (s_.get(f"{{{W}}}val") or "").isdigit() else 1,
                )
            abstract[aid] = lv
        for n in root.iter(f"{{{W}}}num"):
            a = n.find(f"{{{W}}}abstractNumId")
            aid = a.get(f"{{{W}}}val") if a is not None else None
            for ilvl, v in abstract.get(aid, {}).items():
                self.fmt[(n.get(f"{{{W}}}numId"), ilvl)] = v

    _LETTERS = "abcdefghijklmnopqrstuvwxyz"

    def marker(self, num_id, ilvl, counter: int):
        fmt, text, _start = self.fmt.get((num_id, ilvl), ("decimal", "%1.", 1))
        if fmt == "bullet":
            m = {"o": "○", "": "•", "-": "-", "\uf0b7": "•"}.get(text, "•")
            return m, "bullet"
        if fmt == "lowerLetter":
            v = self._LETTERS[(counter - 1) % 26]
        elif fmt == "upperLetter":
            v = self._LETTERS[(counter - 1) % 26].upper()
        elif fmt == "lowerRoman":
            v = _roman(counter).lower()
        else:
            v = str(counter)
        return text.replace("%1", v), fmt

    def start(self, num_id, ilvl) -> int:
        return self.fmt.get((num_id, ilvl), ("decimal", "%1.", 1))[2]


def _roman(n: int) -> str:
    vals = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
            (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
    out = ""
    for v, s in vals:
        while n >= v:
            out += s
            n -= v
    return out


# ----------------------------------------------------------------- shapes → SVG
APP_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"


def custgeom_svg(cg):
    """يحوّل a:custGeom إلى SVG بمساحة إحداثياته الأصلية (viewBox من a:path).
    يُعيد (مسار d، عرض المساحة، ارتفاعها) — لا يعتمد على الامتداد فلا يحدث عدم تطابق."""
    path0 = cg.find(f".//{{{APP_NS}}}pathLst/{{{APP_NS}}}path")
    try:
        cw = float(path0.get("w")) if path0 is not None and path0.get("w") else 0.0
        ch = float(path0.get("h")) if path0 is not None and path0.get("h") else 0.0
    except Exception:
        cw = ch = 0.0
    out = []
    for path in cg.iter(f"{{{APP_NS}}}path"):
        for cmd in path:
            nm = local(cmd)
            pts = cmd.findall(f"{{{APP_NS}}}pt")
            coords = [f"{float(p.get('x', 0)):.1f},{float(p.get('y', 0)):.1f}" for p in pts]
            if nm == "moveTo" and coords:
                out.append("M" + coords[0])
            elif nm == "lnTo" and coords:
                out.append("L" + coords[0])
            elif nm == "cubicBezTo" and len(coords) == 3:
                out.append(f"C{coords[0]} {coords[1]} {coords[2]}")
            elif nm == "quadBezTo" and len(coords) == 2:
                out.append(f"Q{coords[0]} {coords[1]}")
            elif nm == "close":
                out.append("Z")
    if not cw or not ch:
        nums = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", " ".join(out)) or ["0"]]
        cw = cw or (max(nums[::2]) if nums else 100.0)
        ch = ch or (max(nums[1::2]) if len(nums) > 1 else 100.0)
    return " ".join(out), cw, ch


def _old_custgeom_to_svg_path(cg, w_emu, h_emu, scale=1.0):
    out = []
    for path in cg.iter(f"{{{APP_NS}}}path"):
        for cmd in path:
            nm = local(cmd)
            pts = cmd.findall(f"{{{APP_NS}}}pt")
            coords = [f"{float(p.get('x', 0)) * sx:.1f},{float(p.get('y', 0)) * sy:.1f}" for p in pts]
            if nm == "moveTo" and coords:
                out.append("M" + coords[0])
            elif nm == "lnTo" and coords:
                out.append("L" + coords[0])
            elif nm == "cubicBezTo" and len(coords) == 3:
                out.append(f"C{coords[0]} {coords[1]} {coords[2]}")
            elif nm == "quadBezTo" and len(coords) == 2:
                out.append(f"Q{coords[0]} {coords[1]}")
            elif nm == "close":
                out.append("Z")
    return " ".join(out)


def shape_svg(shape, w_mm: float, h_mm: float) -> str:
    """يرسم شكلاً (خط/وصلة/سهم/منحنى) كـ SVG ساكن."""
    prst = None
    pg = shape.find(f".//{{{APP_NS}}}prstGeom")
    if pg is not None:
        prst = pg.get("prst")
    cg = shape.find(f".//{{{APP_NS}}}custGeom")
    ln = shape.find(f".//{{{APP_NS}}}spPr/{{{APP_NS}}}ln") or shape.find(f".//{{{APP_NS}}}ln")
    color = "#333"
    width = 0.6
    dash = None
    head = tail = False
    if ln is not None:
        c = ln.find(f"{{{APP_NS}}}solidFill/{{{APP_NS}}}srgbClr")
        if c is not None:
            color = "#" + c.get("val", "333333")
        wv = ln.get("w")
        if wv and str(wv).isdigit():
            width = max(0.5, min(3.0, int(wv) / 12700.0 * 0.75))
        if ln.find(f"{{{APP_NS}}}prstDash") is not None:
            dash = "4 3"
        head = ln.find(f"{{{APP_NS}}}headEnd") is not None
        tail = ln.find(f"{{{APP_NS}}}tailEnd") is not None
    w = max(1.0, w_mm)
    h = max(1.0, h_mm)
    sattrs = (f'viewBox="0 0 {w:.1f} {h:.1f}" width="{w:.1f}mm" height="{h:.1f}mm" '
              f'preserveAspectRatio="none" class="shape-svg"')
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    mid = h / 2
    if cg is not None:
        d, cw, ch = custgeom_svg(cg)
        if not d:
            d = f"M0,{ch / 2:.1f} L{cw:.1f},{ch / 2:.1f}"
        cw = max(cw, 1.0); ch = max(ch, 1.0)
        sw = max(min(cw, ch) * 0.012, 1.0)
        vb = (f'viewBox="0 0 {cw:.1f} {ch:.1f}" width="{w:.1f}mm" height="{h:.1f}mm" '
              f'preserveAspectRatio="none" class="shape-svg"')
        return (f'<svg {vb}><path d="{d}" fill="none" stroke="{color}" '
                f'stroke-width="{sw:.1f}" vector-effect="non-scaling-stroke" '
                f'stroke-linecap="round"{dash_attr}/></svg>')
    if prst in ("straightConnector1", "line"):
        y = mid if h_mm > 2 else h / 2
        markers = []
        heads = ""
        if tail:
            heads += ' marker-end="url(#ah)"'
        if head:
            heads += ' marker-start="url(#ah)"'
        return (f'<svg {sattrs}><line x1="0" y1="{y:.1f}" x2="{w:.1f}" y2="{y:.1f}" '
                f'stroke="{color}" stroke-width="{width:.2f}"{dash_attr}{heads}/>{markers}</svg>')
    if prst and prst.startswith("curvedConnector"):
        # قوس بسيط
        return (f'<svg {sattrs}><path d="M0,{h:.1f} C{w*0.6:.1f},{h:.1f} {w*0.4:.1f},0 {w:.1f},0" '
                f'fill="none" stroke="{color}" stroke-width="{width:.2f}"{dash_attr}'
                f'{" marker-end=\"url(#ah)\"" if tail else ""}/></svg>')
    # افتراضي: خط أفقي
    return (f'<svg {sattrs}><line x1="0" y1="{mid:.1f}" x2="{w:.1f}" y2="{mid:.1f}" '
            f'stroke="{color}" stroke-width="{width:.2f}"{dash_attr}/></svg>')


# ----------------------------------------------------------------- builder
class Builder:
    def __init__(self, repo: Path, out: Path, manifest: dict):
        self.repo = repo
        self.out = out
        self.man = manifest
        self.src = out / "source" / "original.docx"
        self.zip = zipfile.ZipFile(self.src)
        doc_bytes = self.zip.read("word/document.xml")
        self.doc = etree.fromstring(doc_bytes)
        log = collections.Counter()
        apply_rules(self.doc, "النواسات" in str(self.src), log, [])
        self.rules_log = log
        self.inv = Inventory(self.src)
        self.inv.doc = self.doc
        self.inv.body = self.doc.find(f"{{{W}}}body")
        self.inv.run()
        self.blocks = {b["i"]: b for b in self.inv.blocks}
        self.figs = {f["id"]: f for f in self.inv.figures}
        self.num = Numbering(self.zip)
        self.counters = collections.defaultdict(int)
        self.prev_num = None
        self.eq_ids = collections.defaultdict(list)     # block -> [eq ids]
        for b in self.inv.blocks:
            if b["kind"] == "p":
                self.eq_ids[b["i"]] = list(b["eqs"])
        self.stats = collections.Counter()
        self.rendered_blocks = set()
        self.rendered_eqs = set()
        self.rendered_figs = set()
        self.notes = []

    # ------------------------------------------------ segments of a paragraph
    def segments(self, p, block_i):
        """يفكّ الفقرة إلى مقاطع: نص · معادلة · رسوم — بترتيب المستند."""
        segs = []
        eq_queue = list(self.eq_ids.get(block_i, []))
        fig_queue_assigned = []

        def effective_children(el):
            """أبناء مباشرون، مع فتح mc:AlternateContent على فرعه الفعّال (Choice) فقط."""
            for c in el:
                if not isinstance(c.tag, str):
                    continue
                if c.tag == f"{{{MC}}}AlternateContent":
                    t = c.find(f"{{{MC}}}Choice")
                    if t is None:
                        t = c.find(f"{{{MC}}}Fallback")
                    if t is not None:
                        yield from effective_children(t)
                    continue
                yield c

        def rec(el, run=None, top=True):
            for c in effective_children(el):
                if not isinstance(c.tag, str):
                    continue
                tag = c.tag
                if tag == f"{{{W}}}txbxContent":
                    continue                       # كتل داخلية (تُعرض مع مربعها)
                if tag == f"{{{W}}}r":
                    rec(c, run=c, top=False)
                    continue
                if tag == f"{{{W}}}t":
                    segs.append(("text", c.text or "", style_of(run)))
                    continue
                if tag == f"{{{W}}}tab":
                    segs.append(("text", "\t", style_of(run)))
                    continue
                if tag == f"{{{W}}}br":
                    segs.append(("br", "", None))
                    continue
                if tag == f"{{{M}}}oMath":
                    eid = eq_queue.pop(0) if eq_queue else None
                    segs.append(("math", eid, None))
                    if eid:
                        self.eq_note(eid)
                    continue
                if tag == f"{{{A}}}graphicData":
                    ids = self.inv._handled_objs.get(c) or []
                    if ids:
                        segs.append(("figs", list(ids), None))
                        fig_queue_assigned.extend(ids)
                    continue
                if etree.QName(c).namespace == V and local(c) in (
                        "shape", "group", "rect", "oval", "line", "roundrect", "polyline"):
                    has_dml = any(local(a) == "graphicData" for a in c.iterancestors())
                    if has_dml:
                        continue
                    ids = self.inv._handled_objs.get(c) or []
                    if ids:
                        segs.append(("figs", list(ids), None))
                        fig_queue_assigned.extend(ids)
                    continue
                if tag == f"{{{V}}}imagedata":
                    has_dml = any(local(a) == "graphicData" for a in c.iterancestors())
                    if has_dml:
                        continue
                if etree.QName(c).namespace in (NS["v"], NS["wps"], NS["wpg"], APP_NS) and not top:
                    rec(c, run=run, top=False)
                    continue
                if tag in (f"{{{M}}}oMathPara",):
                    rec(c, run=run, top=False)
                    continue
                rec(c, run=run, top=False)

        rec(p)
        # احتياط: معادلات لم تُطابق بالترتيب
        while eq_queue:
            eid = eq_queue.pop(0)
            segs.append(("math", eid, None))
            self.eq_note(eid)
        return segs

    def eq_note(self, eid):
        self.rendered_eqs.add(eid)

    def math_html(self, eid, display=False) -> str:
        om = self._omath_of.get(eid)
        if om is None:
            return ""
        flat = math_flat(om)
        inner = omml_to_mathml(om)
        return wrap_math(inner, display=display, alttext=flat)

    # ------------------------------------------------ figures
    def figure_html(self, fid) -> str:
        f = self.figs.get(fid)
        if f is None:
            return ""
        self.rendered_figs.add(fid)
        kind = f["kind"]
        ext = f.get("extent_cm") or {}
        w_mm = mm(f.get("extent_emu", {}).get("cx")) if f.get("extent_emu") else 0
        h_mm = mm(f.get("extent_emu", {}).get("cy")) if f.get("extent_emu") else 0
        text_html = ""
        for bi in f.get("text_blocks") or []:
            text_html += self.block_html(bi, in_figure=True)
        if kind == "picture":
            media = f.get("media")
            name = Path(media).name if media else None
            if not name:
                return ""
            style = f"width:{min(w_mm, 170):.1f}mm" if w_mm > 6 else ""
            return (f'<figure class="fig fig-picture" data-fig="{fid}">'
                    f'<img src="../assets/images/{attr_esc(name)}" alt="{attr_esc(f.get("docPr", {}).get("name") or "رسم")}"'
                    f'{" style=\"" + style + "\"" if style else ""}></figure>')
        if kind == "textbox":
            if not text_html.strip():
                self.stats["textbox_empty"] += 1
                return ""
            cls = "fig fig-label"
            if f.get("docPr", {}).get("name", "").find("إطار") >= 0:
                cls += " fig-frame"
            return f'<figure class="{cls}" data-fig="{fid}">{text_html}</figure>'
        if kind == "group":
            kids = [self.figure_html(k) for k in self._group_children(fid)]
            kids = [k for k in kids if k.strip()]
            return f'<figure class="fig fig-group" data-fig="{fid}">{"".join(kids)}</figure>' if kids else ""
        # أشكال (shape / wps:wsp) — بسقف أبعاد يحفظ التدفق (النسبة داخل الصندوق كما هي)
        w_mm = min(max(w_mm, 0.0), 175.0)
        h_mm = min(max(h_mm, 0.0), 55.0)
        return self.shape_html(fid, w_mm, h_mm, text_html)

    def _group_children(self, fid):
        f = self.figs[fid]
        out = []
        for other in self.inv.figures:
            if other.get("parent_fig") == fid:
                out.append(other["id"])
        return out

    def shape_html(self, fid, w_mm, h_mm, text_html) -> str:
        f = self.figs[fid]
        el = f.get("_elem")
        prst = None
        if el is not None:
            pg = el.find(f".//{{{APP_NS}}}prstGeom")
            prst = pg.get("prst") if pg is not None else None
        if text_html.strip():
            cls = "fig fig-callout"
            if prst in ("roundRect", "rect", "round2DiagRect"):
                cls += " callout-box"
            elif prst == "cloud":
                cls += " callout-cloud"
            elif prst in ("leftBrace", "rightBrace"):
                cls += " callout-brace"
            cls += " callout-plain" if prst is None else f" callout-{attr_esc(prst or 'none')}"
            return f'<figure class="{cls}" data-fig="{fid}">{text_html}</figure>'
        if prst in ("leftBrace", "rightBrace"):
            ch = "}" if prst == "leftBrace" else "{"
            return f'<span class="fig fig-brace" data-fig="{fid}">{ch}</span>'
        if prst == "ellipse":
            return f'<span class="fig fig-dot" data-fig="{fid}"></span>'
        if prst in ("rect", "roundRect", "round2DiagRect", "bevel", "cloud"):
            style = f"min-width:{min(max(w_mm, 3), 120):.1f}mm" if w_mm > 3 else ""
            return f'<span class="fig fig-box" data-fig="{fid}" style="{style}"></span>'
        if el is not None and (el.find(f".//{{{APP_NS}}}custGeom") is not None or prst in (
                "straightConnector1", "line", "curvedConnector3", "bentConnector3", "bentConnector2")):
            if w_mm < 1.2 or h_mm < 1.2:
                w_mm, h_mm = max(w_mm, 8.0), max(h_mm, 1.5)
            return f'<span class="fig fig-arrow" data-fig="{fid}">{shape_svg(el, w_mm, h_mm)}</span>'
        if w_mm > 3 or h_mm > 3:
            return f'<span class="fig fig-box" data-fig="{fid}"></span>'
        self.stats["shape_dropped"] += 1
        if len(self.notes) < 12:
            self.notes.append(f"شكل صغير جداً {fid} ({prst}) لم يُرسم ({w_mm}×{h_mm} مم)")
        return ""

    # ------------------------------------------------ text with styles
    TAB_RUN = re.compile(r"\t+")

    def text_html(self, s: str, st: dict) -> str:
        """نص مقطع مع الحفاظ على تنسيقه. التابات تُبنى عناصر ثابتة العرض،
        وسلاسل التابات الطويلة تُطوى إلى مسافة بادئة محدودة (الشكل كما في الورقة، بلا تجاوز)."""
        if not s:
            return ""
        css = style_css(st)
        parts = []
        pos = 0
        for mt in self.TAB_RUN.finditer(s):
            if mt.start() > pos:
                parts.append(esc(s[pos:mt.start()]))
            n = mt.end() - mt.start()
            if n == 1:
                parts.append('<span class="tab"></span>')
            else:
                width = min(n * 1.6, 6.0)
                parts.append(f'<span class="tab tab-run" style="width:{width:.1f}em"></span>')
            pos = mt.end()
        if pos < len(s):
            parts.append(esc(s[pos:]))
        body = "".join(parts)
        if not body:
            return ""
        if not has_ar(s) and re.search(r"[A-Za-z]", s):
            body = f'<bdi dir="ltr">{body}</bdi>'
        return (f'<span class="t" style="{attr_esc(css)}">{body}</span>' if css
                else f'<span class="t">{body}</span>')

    # ------------------------------------------------ paragraph
    GAP_RE = re.compile(r"(?: {3,}|\t{2,})")

    def paragraph_html(self, block_i, in_figure=False, extra_class="") -> str:
        b = self.blocks.get(block_i)
        if b is None or b["kind"] != "p":
            return ""
        el = self.inv.block_elems[block_i - 1]
        segs = self.segments(el, block_i)
        self.rendered_blocks.add(block_i)
        figs = [i for i in b["figs"] if self.figs.get(i, {}).get("parent_fig") is None]
        visible = "".join(s[1] for s in segs if s[0] == "text").strip()
        has_math = any(s[0] == "math" for s in segs)

        # فقرة بلا محتوى مرئي (مسافات/فواصل تصميم): تُترك لتُدار بالمسافات في CSS
        if not visible and not has_math and not figs:
            self.stats["empty_paragraph"] += 1
            return ""

        marker_html = self.marker_for(b)
        is_question = bool(re.match(r"^\s*س\s*[0-9]", visible))
        is_star = visible.startswith("*") and len(visible) < 90

        # معادلة معروضة (فقرة فيها معادلات فقط)
        if not visible and has_math and not is_question:
            inner = "".join(self.math_html(s[1], display=True) for s in segs if s[0] == "math" and s[1])
            self.stats["display_equation_par"] += 1
            return (f'<div class="equation" data-block="{block_i}">{inner}</div>'
                    + self.figs_after(figs, block_i))

        # نص + معادلات مضمّنة (مع إمكانية شبكة عمودين)
        cells, gaps = self.split_cells(segs)
        nonempty = [c for c in cells if self._cell_has_content(c)]
        # الخلايا الفارغة لا تحمل محتوى: تُحذف من الشبكة فلا تُنتج فراغاً رأسيّاً (لا يُفقد أي حرف)
        dense = [c for c in cells if self._cell_has_content(c)] if 2 <= len(nonempty) <= 4 else cells
        if 2 <= len(nonempty) <= 4 and len(cells) > 4:
            self.stats["empty_cells_dropped"] += len(cells) - len(dense)
        cells = dense
        if len(nonempty) >= 2 and len(cells) <= 4:
            cols = "".join(f'<div class="col">{self.cell_html(c, block_i)}</div>' for c in cells)
            self.stats["two_column_paragraph"] += 1
            html = (f'<div class="cols cols-{len(cells)}" '
                    f'style="grid-template-columns:{self.grid_template(cells)}">{cols}</div>')
        else:
            # سطر واحد: تُحفظ الفواصل الأصلية كعروض (لا يُسقط أي نص)
            piece = []
            for idx, cell in enumerate(cells):
                if idx:
                    piece.append(self.gap_span(gaps[idx - 1] if idx - 1 < len(gaps) else "   "))
                piece.append(self.cell_html(cell, block_i))
            html = f'<p class="text text-spaced">{"".join(piece)}</p>'
            if len(nonempty) >= 2:
                self.stats["spaced_line_paragraph"] += 1

        cls = "text"
        if is_question:
            cls += " q-line"
        elif is_star:
            cls += " star-line"
        if extra_class:
            cls += " " + extra_class
        if html.startswith('<p class="text">'):
            html = html.replace('<p class="text">', f'<p class="{cls}">', 1)
        if marker_html:
            html = f'<div class="li">{marker_html}<div class="li-body">{html}</div></div>'
        return html + self.figs_after(figs, block_i)

    def figs_after(self, figs, block_i) -> str:
        if not figs:
            return ""
        roots = [f for f in figs if self.figs.get(f, {}).get("parent_fig") is None]
        if not roots:
            return ""
        parts = []
        for fid in roots:
            if fid in self.rendered_figs:
                continue
            f = self.figs.get(fid, {})
            kind = f.get("kind")
            # عناقيد: صور + أشكال في نفس الفقرة ⇒ مجمّعة في كتلة واحدة
            parts.append(self.figure_html(fid))
        if not parts:
            return ""
        kept = [p for p in parts if p and p.strip()]
        if not kept:
            return ""
        big = sum(1 for fid in roots if self.figs.get(fid, {}).get("kind") == "picture")
        cls = "fig-cluster" + (" fig-cluster-heavy" if len(kept) > 3 else "")
        return f'<div class="cluster {cls}" data-block="{block_i}">{"".join(kept)}</div>'

    def split_cells(self, segs):
        """يقسّم المقاطع إلى خلايا + الفواصل التي كانت بينها (بناء العمودين في Word)."""
        cells = [[]]
        gaps = []
        for kind, val, st in segs:
            if kind == "text":
                parts = self.GAP_RE.split(val)
                seps = self.GAP_RE.findall(val)
                for idx, part in enumerate(parts):
                    if idx > 0:
                        gaps.append(seps[idx - 1] if idx - 1 < len(seps) else "   ")
                        cells.append([])
                    if part:
                        cells[-1].append(("text", part, st))
            elif kind in ("math", "figs"):
                cells[-1].append((kind, val, st))
            elif kind == "br":
                cells[-1].append(("br", "", None))
        return cells, gaps

    @staticmethod
    def _cell_has_content(cell) -> bool:
        return any((k == "text" and v.strip()) or k in ("math", "figs") for k, v, _ in cell)

    def grid_template(self, cells) -> str:
        """نسب الأعمدة بحسب كثافة نصّ كل خلية (أقرب إلى توزيع الورقة الأصلي)."""
        weights = []
        for c in cells:
            n = sum(len(v) for k, v, _ in c if k == "text")
            has_fig = any(k == "figs" for k, _, _ in c)
            weights.append(max(1.0, min(6.0, n / 9.0 + (0.0 if not has_fig else 0.5))))
        total = sum(weights) or 1.0
        return " ".join(f"{max(1.0, w / total * 100):.0f}fr" for w in weights)

    def gap_span(self, gap: str) -> str:
        """يعيد الفراغ الأصلي كعرض محسوب (بلا حذف أي حرف)."""
        tabs = gap.count("\t")
        if tabs:
            n = max(2, tabs * 3)
        else:
            n = len(gap)
        return f'<span class="gap" style="min-width:{min(n, 24)}ch"></span>' 

    def cell_html(self, cell, block_i) -> str:
        out = []
        for kind, val, st in cell:
            if kind == "text":
                out.append(self.text_html(val, st or {}))
            elif kind == "math":
                if val:
                    out.append(self.math_html(val))
            elif kind == "br":
                out.append("<br>")
            elif kind == "figs":
                roots = [f for f in val if self.figs.get(f, {}).get("parent_fig") is None]
                # الصور الفعلية والأعناقيد تُعرض في عنقود بعد الفقرة كي لا تُحدِث فراغاً في الشبكة
                inline_kinds = ("textbox", "shape")
                inner = "".join(self.figure_html(f) for f in roots
                                if f not in self.rendered_figs
                                and self.figs.get(f, {}).get("kind") in inline_kinds)
                if inner.strip():
                    out.append(f'<span class="inline-figs">{inner}</span>')
        return "".join(out)

    def marker_for(self, b) -> str:
        num = b.get("num")
        if not num:
            self.prev_num = None
            return ""
        key = (num.get("numId"), num.get("ilvl"))
        if self.prev_num != key:
            self.counters[key] = self.num.start(*key) - 1
        self.counters[key] += 1
        self.prev_num = key
        text, fmt = self.num.marker(num.get("numId"), num.get("ilvl"), self.counters[key])
        self.stats["list_item"] += 1
        return f'<span class="li-marker" data-fmt="{attr_esc(fmt)}">{esc(text)}</span>'

    # ------------------------------------------------ table
    def table_html(self, block_i) -> str:
        b = self.blocks.get(block_i)
        if b is None or b["kind"] != "tbl":
            return ""
        rows = []
        cells = collections.defaultdict(dict)
        for cell in b["cell_blocks"]:
            cells[cell["row"]][cell["cell"]] = cell["blocks"]
        for r in range(1, b["rows"] + 1):
            tds = []
            for c in range(1, b["cols"] + 1):
                inner = "".join(self.block_html(bi) for bi in cells[r].get(c, []))
                tds.append(f"<td>{inner}</td>")
            rows.append(f"<tr>{''.join(tds)}</tr>")
        self.stats["table"] += 1
        for bi in b["all_blocks"]:
            self.rendered_blocks.add(bi)
        for f in b.get("figs", []):
            self.rendered_figs.add(f)
        return (f'<div class="table-wrapper" data-block="{block_i}">'
                f'<table class="data-table">{"".join(rows)}</table></div>')

    # ------------------------------------------------ dispatch
    def block_html(self, block_i, in_figure=False) -> str:
        b = self.blocks.get(block_i)
        if b is None:
            return ""
        if block_i in self.rendered_blocks:
            return ""
        if b["kind"] == "tbl":
            return self.table_html(block_i)
        return self.paragraph_html(block_i, in_figure=in_figure)

    # ------------------------------------------------ document
    def build(self):
        # خريطة المعرّف ⇒ عنصر oMath (المصحّح في الذاكرة)
        self._omath_of = {}
        idx = 0
        for om in self.doc.iter(f"{{{M}}}oMath"):
            if any(a.tag == f"{{{MC}}}Fallback" for a in om.iterancestors()):
                continue
            idx += 1
            self._omath_of[f"E{idx:05d}"] = om
        # ربط عناصر الأشكال المسجّلة (للرسم SVG)
        for f in self.inv.figures:
            f["_elem"] = None
        for el, ids in self.inv._handled_objs.items():
            for fid in ids:
                for f in self.inv.figures:
                    if f["id"] == fid:
                        f["_elem"] = el
        # عنوان الدرس: أول مربع نصي في المستند
        self.title = ""
        first = self.inv.figures[0] if self.inv.figures else None
        if first and first.get("text_blocks"):
            tb = self.inv.blocks[first["text_blocks"][0] - 1]
            self.title = tb["text"].strip()

        body_parts = []
        open_q = False
        for b in self.inv.blocks:
            if b["kind"] != "p":
                if b["i"] in self.rendered_blocks:
                    continue
                body_parts.append(self.table_html(b["i"]))
                continue
            if b.get("in_textbox_of"):
                owner = b["in_textbox_of"]
                if owner in self.rendered_figs or b["i"] in self.rendered_blocks:
                    continue
                # مربع نصي لم يُصيَّر (مربع فارغ أو بلا نص ظاهر): يُعرض نصه مستقلاً كي لا يُفقد
                body_parts.append(self.paragraph_html(b["i"], extra_class="orphan-label"))
                continue
            txt = b["text"].strip()
            is_plain_heading = (txt.startswith("*") and len(txt) < 90
                                and not b["eqs"] and not b["figs"])
            if is_plain_heading:
                if open_q:
                    body_parts.append("</section>")
                    open_q = False
                body_parts.append('<h2 class="section-title">'
                                  + self.text_html(txt.lstrip("* ").strip(), {}) + "</h2>")
                self.rendered_blocks.add(b["i"])
                self.stats["heading"] += 1
                continue
            if re.match(r"^\s*س\s*[0-9]", txt):
                if open_q:
                    body_parts.append("</section>")
                qnum = re.match(r"^\s*(س\s*[0-9]+\s*[)]?)", txt)
                label = qnum.group(1) if qnum else "س"
                body_parts.append(f'<section class="question"><h3 class="q-head">{esc(label)}</h3>')
                open_q = True
                self.stats["question"] += 1
                # نص السؤال يبدأ بعلامة السؤال نفسها: تُترك كما كتبها الأستاذ
                body_parts.append(self.paragraph_html(b["i"]))
                continue
            body_parts.append(self.block_html(b["i"]))
        if open_q:
            body_parts.append("</section>")

        return "\n".join(p for p in body_parts if p and p.strip())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--out", default="rebuild/nawwasat")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    out = (repo / args.out).resolve()
    (out / "html").mkdir(parents=True, exist_ok=True)
    (out / "reports").mkdir(parents=True, exist_ok=True)
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    man = json.loads((out / "content" / "manifest.json").read_text(encoding="utf-8"))
    b = Builder(repo, out, man)
    body = b.build()

    html = f'''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>نوطة النواسات — الأستاذ فداء البني</title>
<link rel="stylesheet" href="styles.css">
<link rel="stylesheet" href="print.css" media="print">
<script src="fit-math.js" defer></script>
</head>
<body>
<main dir="rtl" lang="ar" class="notebook">
<header class="doc-head">
  <h1 class="doc-title">{esc(b.title or "النواسات")}</h1>
  <p class="doc-sub">نوطة الأستاذ فداء البني — منقولة حرفياً بتخطيط جديد</p>
</header>
{body}
</main>
<svg width="0" height="0" aria-hidden="true" focusable="false" style="position:absolute">
  <defs>
    <marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="currentColor"></path>
    </marker>
  </defs>
</svg>
</body>
</html>
'''
    (out / "html" / "index.html").write_text(html, encoding="utf-8")

    # ---- ملخّص بنيوي + فحوصات
    struct = {
        "stage": "NHTML-2", "generated_at_utc": now,
        "generator": "rebuild/nawwasat/tools/build_html.py",
        "source_sha256": man["source"]["sha256"],
        "rules_applied": dict(b.rules_log),
        "stats": dict(b.stats),
        "coverage": {
            "blocks_total": len(b.inv.blocks),
            "paragraphs_total": sum(1 for x in b.inv.blocks if x["kind"] == "p"),
            "paragraphs_visited": len(b.rendered_blocks),
            "paragraphs_skipped_empty": b.stats.get("empty_paragraph", 0),
            "tables_rendered": b.stats.get("table", 0),
            "equations_total": len(b._omath_of),
            "equations_rendered": len(b.rendered_eqs),
            "figures_total": len(b.inv.figures),
            "figures_rendered": len(b.rendered_figs),
        },
        "notes": b.notes,
        "html_bytes": len(html.encode("utf-8")),
    }
    (out / "content" / "structure.json").write_text(
        json.dumps(struct, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(struct["coverage"], ensure_ascii=False, indent=1))
    print("stats:", json.dumps(dict(b.stats), ensure_ascii=False))
    print("notes:", b.notes[:6])
    print("html:", len(html.encode('utf-8')), "bytes")


if __name__ == "__main__":
    main()
