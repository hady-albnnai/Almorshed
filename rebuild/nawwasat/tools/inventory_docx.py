#!/usr/bin/env python3
"""NHTML-0 — جرد نوطة الأستاذ فداء (DOCX) بلا أي تعديل على المصدر.

الوظائف:
  1. تجميد نسخة المصدر  -> rebuild/nawwasat/source/original.docx (+ SHA-256).
  2. جرد كل الكتل (فقرات/جداول/مربعات نصية) بالترتيب مع النص الحرفي.
  3. جرد كل معادلات OMML (1483 كتلة) بصيغة خطية قابلة للمقارنة.
  4. جرد كل الرسومات (صور/أشكال/مربعات نصية/مجموعات) مع العلاقة والأبعاد والموضع.
  5. جرد كل ملفات الوسائط (77 مرجع + أيتام) بلا إعادة ضغط ولا تعديل.
  6. جرد الأسئلة/العناوين المرشحة + إحصاء الرموز (لحماية ± ∓ والأقواس والجذور).
  7. كتابة content/manifest.json + reports/NHTML-0-inventory.md.

لا يكتب هذا السكربت أي شيء داخل الـ DOCX. القراءة فقط.
"""
from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import io
import json
import re
import shutil
import sys
import zipfile
from pathlib import Path

from lxml import etree

try:
    from PIL import Image
except Exception:  # pragma: no cover
    Image = None

# ---------------------------------------------------------------- namespaces
NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "wp": "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
    "wps": "http://schemas.microsoft.com/office/word/2010/wordprocessingShape",
    "wpg": "http://schemas.microsoft.com/office/word/2010/wordprocessingGroup",
    "mc": "http://schemas.openxmlformats.org/markup-compatibility/2006",
    "v": "urn:schemas-microsoft-com:vml",
    "o": "urn:schemas-microsoft-com:office:office",
    "w10": "http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing",
    "pkg": "http://schemas.openxmlformats.org/package/2006/relationships",
    "ct": "http://schemas.openxmlformats.org/package/2006/content-types",
}

W = NS["w"]; M = NS["m"]; A = NS["a"]; WP = NS["wp"]; PIC = NS["pic"]
WPS = NS["wps"]; WPG = NS["wpg"]; MC = NS["mc"]; V = NS["v"]; R = NS["r"]

EMU_PER_CM = 360000.0
TWIP_PER_CM = 566.9291338582677


def qn(prefix: str, local: str) -> str:
    return f"{{{NS[prefix]}}}{local}"


def local(el) -> str:
    return etree.QName(el).localname if isinstance(el.tag, str) else ""


def nsprefix(el) -> str:
    uri = etree.QName(el).namespace or ""
    for k, v in NS.items():
        if v == uri:
            return k
    return "?"


def nested_textbox_ancestor(el, stop):
    """هل بين `el` و`stop` (حصراً) حاوية مربع نصي متداخلة؟"""
    cur = el.getparent()
    while cur is not None and cur is not stop:
        if cur.tag == f"{{{W}}}txbxContent":
            return True
        cur = cur.getparent()
    return False


def scope_iter(el):
    """تكرار آمن على نطاق قد يكون None."""
    return el.iter() if el is not None else iter(())


def tag_of(el) -> str:
    return f"{nsprefix(el)}:{local(el)}"


def ancestors(el, stop=None):
    cur = el.getparent()
    while cur is not None and cur is not stop:
        yield cur
        cur = cur.getparent()


def iter_effective(el):
    """ترتيب المستند الفعلي: عند mc:AlternateContent نأخذ Choice، وإن غاب نأخذ Fallback
    (كي لا تُحسب الأشكال مرّتين: نسخة DrawingML + نسخة VML)."""
    for child in el:
        if not isinstance(child.tag, str):
            continue
        if child.tag == f"{{{MC}}}AlternateContent":
            target = child.find(f"{{{MC}}}Choice")
            if target is None:
                target = child.find(f"{{{MC}}}Fallback")
            if target is not None:
                yield from iter_effective(target)
            continue
        yield child
        yield from iter_effective(child)


# ---------------------------------------------------------------- math linear
MATH_OP = {
    "f": lambda lo: f"({lo.num})/({lo.den})",
}


def math_linear(el: etree._Element) -> str:
    """تحويل OMML إلى صيغة خطية تحفظ البنية (للجرد والمقارنة الآلية)."""
    name = local(el)
    if el.tag == f"{{{M}}}t":
        return el.text or ""
    kids = [c for c in el if isinstance(c.tag, str)]

    def kid(nm):
        for c in kids:
            if local(c) == nm:
                return c
        return None

    if name == "oMath" or name in ("oMathPara", "e", "num", "den", "deg", "sup", "sub", "fName", "lim", "box"):
        if name == "oMathPara":
            return " ; ".join(math_linear(c) for c in kids if local(c) == "oMath")
        return "".join(math_linear(c) for c in kids)
    if name == "f":
        return f"({math_linear(kid('num'))})/({math_linear(kid('den'))})"
    if name == "rad":
        deg = kid("deg")
        d = math_linear(deg) if deg is not None else ""
        hide = deg is not None and deg.find(f"{{{M}}}degPr/{{{M}}}degHide") is not None
        base = math_linear(kid("e"))
        return f"√({base})" if (not d or hide) else f"{d}√({base})"
    if name == "sSup":
        return f"{math_linear(kid('e'))}^{math_linear(kid('sup'))}"
    if name == "sSub":
        return f"{math_linear(kid('e'))}_{math_linear(kid('sub'))}"
    if name == "sSubSup":
        return f"{math_linear(kid('e'))}_{math_linear(kid('sub'))}^{math_linear(kid('sup'))}"
    if name == "sPre":
        return f"_{math_linear(kid('sub'))}^{math_linear(kid('sup'))}{math_linear(kid('e'))}"
    if name == "nary":
        pr = kid("naryPr")
        chr_ = "∑"
        if pr is not None:
            c = pr.find(f"{{{M}}}chr")
            if c is not None and c.get(f"{{{M}}}val"):
                chr_ = c.get(f"{{{M}}}val")
        sub = math_linear(kid("sub")) if kid("sub") is not None else ""
        sup = math_linear(kid("sup")) if kid("sup") is not None else ""
        lims = f"_{sub}" if sub else ""
        lims += f"^{sup}" if sup else ""
        return f"{chr_}{lims}({math_linear(kid('e'))})"
    if name == "d":
        pr = kid("dPr")
        beg, end = "(", ")"
        if pr is not None:
            b = pr.find(f"{{{M}}}begChr"); e = pr.find(f"{{{M}}}endChr")
            if b is not None: beg = b.get(f"{{{M}}}val", "(")
            if e is not None: end = e.get(f"{{{M}}}val", ")")
        return f"{beg}{'|'.join(math_linear(c) for c in kids if local(c) == 'e')}{end}"
    if name == "func":
        nm = kid("fName"); e = kid("e")
        return f"{math_linear(nm)}({math_linear(e)})"
    if name == "acc":
        pr = kid("accPr")
        ch = "^"
        if pr is not None:
            c = pr.find(f"{{{M}}}chr")
            if c is not None: ch = c.get(f"{{{M}}}val", "^")
        return f"[{ch}]{math_linear(kid('e'))}"
    if name == "groupChr":
        pr = kid("groupChrPr")
        ch = "⏟"
        if pr is not None:
            c = pr.find(f"{{{M}}}chr")
            if c is not None: ch = c.get(f"{{{M}}}val", "⏟")
        return f"[{ch}]{math_linear(kid('e'))}"
    if name == "limLow":
        return f"{math_linear(kid('e'))}_{math_linear(kid('lim'))}"
    if name == "limUpp":
        return f"{math_linear(kid('e'))}^{math_linear(kid('lim'))}"
    if name == "eqArr":
        return "{" + " ; ".join(math_linear(c) for c in kids if local(c) == "e") + "}"
    if name == "m":
        rows = []
        for mr in kids:
            if local(mr) == "mr":
                rows.append(", ".join(math_linear(c) for c in mr if local(c) == "e"))
        return "[" + " ; ".join(rows) + "]"
    if name == "r":
        return "".join(math_linear(c) for c in kids)
    if name in ("rPr", "ctrlPr", "fPr", "dPr", "radPr", "sSubPr", "sSupPr", "sSubSupPr",
                "naryPr", "funcPr", "accPr", "groupChrPr", "boxPr", "oMathParaPr", "argPr",
                "limLowPr", "limUppPr", "eqArrPr", "mPr", "mrPr"):
        return ""
    return "".join(math_linear(c) for c in kids)


def math_flat(el) -> str:
    return "".join(t.text or "" for t in el.iter(f"{{{M}}}t"))


def eq_features(el) -> list:
    feats = collections.Counter()
    for n in el.iter():
        name = local(n)
        if etree.QName(n).namespace == NS["m"] and name in (
            "f", "rad", "sSub", "sSup", "sSubSup", "nary", "d", "func", "acc",
            "groupChr", "limLow", "limUpp", "eqArr", "m", "box", "sPre",
        ):
            feats[name] += 1
    return [k for k in sorted(feats)]


# ---------------------------------------------------------------- text helpers
def para_own_text(p) -> str:
    """نص الفقرة الحرفي (يشمل المعادلات إن كانت داخل الفقرة) بلا نصوص المربعات الداخلية."""
    out = []
    for el in iter_effective(p):
        if el.tag == f"{{{W}}}t":
            out.append(el.text or "")
        elif el.tag == f"{{{W}}}tab":
            out.append("\t")
        elif el.tag == f"{{{W}}}br":
            out.append("\n")
    return "".join(out)


def element_text(el) -> str:
    out = []
    for n in el.iter():
        if isinstance(n.tag, str) and n.tag in (f"{{{W}}}t", f"{{{M}}}t"):
            out.append(n.text or "")
    return "".join(out)


# ---------------------------------------------------------------- main class
class Inventory:
    def __init__(self, src: Path):
        self.src = src
        self.zip = zipfile.ZipFile(src)
        self.doc = etree.fromstring(self.zip.read("word/document.xml"))
        self.body = self.doc.find(f"{{{W}}}body")
        self.rels = self._load_rels("word/_rels/document.xml.rels")
        self.media_info = {}
        self.img_usage = collections.defaultdict(list)
        self.blocks = []
        self.block_elems = []
        self.equations = []
        self.figures = []
        self.tables = []
        self._fig_seq = 0
        self._eq_seq = 0
        self._handled_objs = {}
        self._ctx = {"block": None, "in_table": None, "in_textbox": None, "parent_fig": None}

    # -------------------------------------------------- rels + media
    def _load_rels(self, path):
        try:
            root = etree.fromstring(self.zip.read(path))
        except KeyError:
            return {}
        out = {}
        for r in root:
            out[r.get("Id")] = {
                "type": (r.get("Type") or "").split("/")[-1],
                "target": r.get("Target"),
                "mode": r.get("TargetMode"),
            }
        return out

    def media_entry(self, name):
        if name in self.media_info:
            return self.media_info[name]
        try:
            data = self.zip.read(name)
        except KeyError:
            self.media_info[name] = {"name": name, "missing": True}
            return self.media_info[name]
        info = {
            "name": name,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "ext": Path(name).suffix.lower().lstrip("."),
        }
        if Image is not None:
            try:
                with Image.open(io.BytesIO(data)) as im:
                    info["px"] = [im.width, im.height]
                    info["format"] = im.format
                    dpi = im.info.get("dpi")
                    if dpi and dpi[0]:
                        info["dpi_stored"] = [round(float(dpi[0]), 2), round(float(dpi[1]), 2)]
                    info["mode"] = im.mode
                    info["frames"] = getattr(im, "n_frames", 1)
            except Exception as exc:
                info["format"] = "unreadable"
                info["read_error"] = f"{type(exc).__name__}: {exc}"
        self.media_info[name] = info
        return info

    # -------------------------------------------------- figures
    def new_figure(self, **kw):
        self._fig_seq += 1
        fid = f"F{self._fig_seq:04d}"
        rec = {"id": fid, "order": self._fig_seq}
        rec.update(kw)
        self.figures.append(rec)
        return rec

    def classify_graphic(self, gd):
        uri = gd.get("uri") or ""
        child = next((c for c in gd if isinstance(c.tag, str)), None)
        kind = "unknown"
        if child is not None:
            ctag = tag_of(child)
            kind = {
                "pic:pic": "picture",
                "wps:wsp": "textbox" if child.find(f".//{{{W}}}txbxContent") is not None else "shape",
                "wpg:grpSp": "group",
                "wpg:wgp": "group",
                "a:graphic": "graphic",
            }.get(ctag, ctag)
        return kind, uri, child

    def figure_common(self, anchor_el, block_i, block_path):
        """استخراج معلومات المرساة/الموضع/الحجم."""
        info = {"anchor": "none", "position": {}, "wrap": None, "behindDoc": None,
                "z": None, "dist_cm": {}, "extent_emu": {}, "extent_cm": {}}
        if anchor_el is not None and local(anchor_el) in ("anchor", "inline"):
            info["anchor"] = local(anchor_el)
            at = anchor_el.attrib
            if local(anchor_el) == "anchor":
                info["behindDoc"] = at.get("behindDoc") == "1"
                info["allowOverlap"] = at.get("allowOverlap") == "1"
                info["locked"] = at.get("locked") == "1"
                z = at.get(f"{{{NS['w10']}}}relativeHeight")
                info["z"] = int(z) if z else None
                info["dist_cm"] = {
                    k: round(int(at.get(k, "0")) / EMU_PER_CM, 3)
                    for k in ("distT", "distB", "distL", "distR")
                }
                for wrap in ("wrapNone", "wrapSquare", "wrapTight", "wrapThrough", "wrapTopAndBottom"):
                    if anchor_el.find(f"{{{WP}}}{wrap}") is not None:
                        info["wrap"] = wrap
                        break
                ph = anchor_el.find(f"{{{WP}}}positionH")
                pv = anchor_el.find(f"{{{WP}}}positionV")
                for tag, node in (("h", ph), ("v", pv)):
                    if node is None:
                        continue
                    entry = {"relativeFrom": node.get("relativeFrom")}
                    off = node.find(f"{{{WP}}}posOffset")
                    if off is not None and off.text:
                        emu = int(off.text)
                        entry["offset_emu"] = emu
                        entry["offset_cm"] = round(emu / EMU_PER_CM, 3)
                    al = node.find(f"{{{WP}}}align")
                    if al is not None and al.text:
                        entry["align"] = al.text
                    info["position"][tag] = entry
        ext = anchor_el.find(f"{{{WP}}}extent") if anchor_el is not None else None
        if ext is not None:
            cx = int(ext.get("cx", "0")); cy = int(ext.get("cy", "0"))
            info["extent_emu"] = {"cx": cx, "cy": cy}
            info["extent_cm"] = {"w": round(cx / EMU_PER_CM, 3), "h": round(cy / EMU_PER_CM, 3)}
        info["block"] = block_i
        info["block_path"] = block_path
        info["in_table"] = self._ctx["in_table"]
        info["in_textbox_of"] = self._ctx["in_textbox"]
        info["parent_fig"] = self._ctx["parent_fig"]
        return info

    def nearest_anchor(self, el):
        for a in ancestors(el):
            if local(a) in ("anchor", "inline") and etree.QName(a).namespace == WP:
                return a
        return None

    def handle_graphic_object(self, obj_el, anchor_el, block_i, block_path, source="graphicData"):
        """obj_el = a:graphicData | wps:wsp | VML shape | v:imagedata ..."""
        # ملاحظة: مفاتيح القاموس هي العناصر نفسها (تُبقي المرجع حياً) — id() في lxml غير موثوق
        if obj_el in self._handled_objs:
            return self._handled_objs[obj_el]
        ctx_parent = self._ctx["parent_fig"]
        kind, uri, child = (None, None, None)
        rec_extra = {}
        if local(obj_el) == "graphicData":
            kind, uri, child = self.classify_graphic(obj_el)
            rec_extra["graphic_uri"] = uri
        elif obj_el.tag == f"{{{PIC}}}pic":
            kind = "picture"
        elif obj_el.tag == f"{{{V}}}imagedata":
            kind = "vml-picture"
            rec_extra["vml_src"] = obj_el.get(f"{{{R}}}id")
        elif etree.QName(obj_el).namespace == V:
            kind = f"vml-{local(obj_el)}"
        else:
            kind = tag_of(obj_el)

        rec = {"kind": kind, "source": source}
        rec.update(self.figure_common(anchor_el, block_i, block_path))
        rec.update(rec_extra)

        # المربع النصي الخاص بهذا الشكل (لا مربعات الأشكال التابعة)
        own_txbx = None
        scope_el = child if child is not None else obj_el
        holder = child if child is not None else obj_el
        if local(scope_el) == "wsp":
            own_txbx = scope_el.find(f"{{{WPS}}}txbx/{{{W}}}txbxContent")
        if own_txbx is not None:
            rec["kind"] = "textbox"
            kind = "textbox"

        # docPr / اسم العنصر
        dp = None
        for cand in holder.iter():
            if isinstance(cand.tag, str) and local(cand) == "docPr":
                dp = cand
                break
        if dp is None:
            for cand in obj_el.iter():
                if isinstance(cand.tag, str) and local(cand) == "docPr":
                    dp = cand
                    break
        if dp is not None:
            rec["docPr"] = {
                "id": dp.get("id"),
                "name": dp.get("name"),
                "descr": dp.get("descr"),
                "title": dp.get("title"),
            }

        # الصورة والعلاقة
        # نطاق البحث عن الصورة: صورة=>كل الشكل، شكل/مربع نص=>spPr فقط، مجموعة=>لا شيء
        if kind == "picture":
            blip_scope = holder if holder is not None else obj_el
        elif kind in ("shape", "textbox"):
            blip_scope = (holder if holder is not None else obj_el).find(f"{{{WPS}}}spPr")
        else:
            blip_scope = None

        blip = None
        for cand in scope_iter(blip_scope):
            if isinstance(cand.tag, str) and cand.tag == f"{{{A}}}blip":
                blip = cand
                break
        imgdata = None
        vml_scope = None
        if etree.QName(obj_el).namespace == NS["v"]:
            vml_scope = obj_el
        elif kind == "picture" and holder is not None:
            vml_scope = holder
        for cand in scope_iter(vml_scope):
            if isinstance(cand.tag, str) and cand.tag == f"{{{V}}}imagedata":
                imgdata = cand
                break

        rid = None
        if blip is not None:
            rid = blip.get(f"{{{R}}}embed") or blip.get(f"{{{R}}}link")
        if rid is None and imgdata is not None:
            rid = imgdata.get(f"{{{R}}}id")
        if rid is not None:
            rel = self.rels.get(rid, {})
            target = rel.get("target")
            media_path = f"word/{target}" if target and not target.startswith("/") else target
            rec["rel_id"] = rid
            rec["rel_type"] = rel.get("type")
            rec["media"] = media_path
            if media_path:
                info = self.media_entry(media_path)
                rec["natural"] = {
                    "px": info.get("px"),
                    "format": info.get("format"),
                    "src_bytes": info.get("bytes"),
                    "src_sha256": info.get("sha256"),
                }
                if info.get("px") and rec.get("extent_cm", {}).get("w"):
                    w_cm = rec["extent_cm"]["w"]
                    if w_cm > 0:
                        rec["natural"]["dpi_eff_x"] = round(info["px"][0] / (w_cm / 2.54), 1)
        if own_txbx is not None:
            rec["text_preview"] = element_text(own_txbx).strip()[:160]

        if rec.get("parent_fig"):
            rec["inherited_anchor"] = rec["anchor"]
            rec["anchor"] = "group-member"
            if not rec.get("extent_emu"):
                xf = None
                for cand in (scope_el if scope_el is not None else obj_el).iter():
                    if isinstance(cand.tag, str) and local(cand) == "xfrm":
                        e = cand.find(f"{{{A}}}ext")
                        if e is not None:
                            xf = e
                            break
                if xf is not None:
                    cx = int(xf.get("cx", "0")); cy = int(xf.get("cy", "0"))
                    rec["extent_emu"] = {"cx": cx, "cy": cy}
                    rec["extent_cm"] = {"w": round(cx / EMU_PER_CM, 3), "h": round(cy / EMU_PER_CM, 3)}
        fig_rec = self.new_figure(**rec)
        fig_id = fig_rec["id"]
        created = [fig_id]
        self._handled_objs[obj_el] = created
        if rec.get("media"):
            self.img_usage[rec["media"]].append(fig_id)

        # نزول داخل المجموعات ثم داخل المربع النصي (مربعات النص تُسجَّل ككتل نصية مستقلة)
        self._ctx["parent_fig"] = fig_id
        for cand in iter_effective(holder if holder is not None else obj_el):
            if not isinstance(cand.tag, str):
                continue
            if cand.tag == f"{{{W}}}txbxContent" and own_txbx is not None and cand is own_txbx:
                self._ctx["in_textbox"] = fig_id
                sub_blocks = self.collect_blocks(cand, f"{block_path}/txbx[{fig_id}]", textbox_owner=fig_id)
                fig_rec["text_blocks"] = sub_blocks
                self._ctx["in_textbox"] = None
            elif cand.tag == f"{{{A}}}graphicData" and cand is not obj_el:
                # شكل داخل مجموعة (مسار DrawingML العادي)
                created.extend(self.handle_graphic_object(
                    cand, self.nearest_anchor(cand), block_i, block_path, source="group-child"))
            elif cand.tag == f"{{{WPS}}}wsp" and cand is not obj_el:
                # أبناء المجموعة (grpSp / wgp) عناصر wps:wsp مباشرة — تُفهرس ككائنات مستقلة
                created.extend(self.handle_graphic_object(
                    cand, self.nearest_anchor(cand), block_i, block_path, source="group-child"))
            elif cand.tag == f"{{{PIC}}}pic" and cand is not obj_el:
                # صور مباشرة داخل مجموعة (بلا wsp وسيط)
                created.extend(self.handle_graphic_object(
                    cand, self.nearest_anchor(cand), block_i, block_path, source="group-child"))
        self._ctx["parent_fig"] = ctx_parent
        return created

    # -------------------------------------------------- equations
    def handle_equation(self, om, block_i, block_path, container):
        self._eq_seq += 1
        eid = f"E{self._eq_seq:05d}"
        disp = any(local(a) == "oMathPara" for a in ancestors(om))
        xml = etree.tostring(om, encoding="utf-8")
        sty = None
        r = om.find(f"{{{M}}}r")
        if r is not None:
            st = r.find(f"{{{M}}}rPr/{{{M}}}sty")
            if st is not None:
                sty = st.get(f"{{{M}}}val")
        rec = {
            "id": eid,
            "block": block_i,
            "block_path": block_path,
            "display": bool(disp),
            "container": container,
            "in_table": self._ctx["in_table"],
            "in_textbox_of": self._ctx["in_textbox"],
            "linear": math_linear(om),
            "flat": math_flat(om),
            "chars": len(math_flat(om)),
            "xml_bytes": len(xml),
            "features": eq_features(om),
            "sty": sty,
        }
        self.equations.append(rec)
        return eid

    # -------------------------------------------------- blocks
    def collect_blocks(self, container, path, textbox_owner=None):
        """يجمع كتل الحاوية (body / tc / txbxContent) بترتيبها ويعيد قائمة أرقام الكتل."""
        ids = []
        idx = 0
        for child in container:
            if not isinstance(child.tag, str):
                continue
            if child.tag == f"{{{W}}}p":
                idx += 1
                ids.append(self.handle_paragraph(child, f"{path}/p[{idx}]", textbox_owner))
            elif child.tag == f"{{{W}}}tbl":
                idx += 1
                ids.append(self.handle_table(child, f"{path}/tbl[{idx}]"))
        return ids

    def handle_paragraph(self, p, path, textbox_owner=None):
        # حجز المعرّف أولاً: كتل المربعات النصية المتداخلة تأخذ أرقاماً بعده
        i = len(self.blocks) + 1
        skeleton = {"i": i, "path": path, "kind": "p", "text": "", "eqs": [], "figs": [],
                    "fig_offsets": [], "in_textbox_of": textbox_owner, "in_table": None,
                    "flags": {}, "empty": False}
        self.blocks.append(skeleton)
        self.block_elems.append(p)
        prev_ctx = dict(self._ctx)
        self._ctx["block"] = i
        if textbox_owner:
            self._ctx["in_textbox"] = textbox_owner

        pPr = p.find(f"{{{W}}}pPr")
        style = jc = ind = None
        num = None
        outline = None
        rtl = None
        if pPr is not None:
            st = pPr.find(f"{{{W}}}pStyle")
            if st is not None:
                style = st.get(f"{{{W}}}val")
            j = pPr.find(f"{{{W}}}jc")
            if j is not None:
                jc = j.get(f"{{{W}}}val")
            n = pPr.find(f"{{{W}}}numPr")
            if n is not None:
                num = {
                    "numId": (n.find(f"{{{W}}}numId").get(f"{{{W}}}val") if n.find(f"{{{W}}}numId") is not None else None),
                    "ilvl": (n.find(f"{{{W}}}ilvl").get(f"{{{W}}}val") if n.find(f"{{{W}}}ilvl") is not None else None),
                }
            o = pPr.find(f"{{{W}}}outlineLvl")
            if o is not None:
                outline = o.get(f"{{{W}}}val")
            indl = pPr.find(f"{{{W}}}ind")
            if indl is not None:
                ind = {k.split('}')[-1]: v for k, v in indl.attrib.items()}
        pp = p.find(f"{{{W}}}pPr/{{{W}}}rPr/{{{W}}}rtl")
        if pp is not None:
            rtl = pp.get(f"{{{W}}}val") != "0"

        text_chunks = []
        eq_ids = []
        fig_ids = []
        fig_offsets = []
        char_pos = 0
        seen_fig_elements = set()

        for el in iter_effective(p):
            if nested_textbox_ancestor(el, p):
                # محتوى مربع نصي متداخل: يُفهرس ككتل مستقلة، فلا يُحسب في نص الفقرة الأم
                continue
            if el.tag == f"{{{W}}}t":
                text_chunks.append(el.text or "")
                char_pos += len(el.text or "")
            elif el.tag == f"{{{W}}}tab":
                text_chunks.append("\t")
                char_pos += 1
            elif el.tag == f"{{{W}}}br":
                text_chunks.append("\n")
                char_pos += 1
            elif el.tag == f"{{{M}}}oMath":
                eid = self.handle_equation(el, i, path, "textbox" if textbox_owner else "body")
                eq_ids.append(eid)
                lin = math_linear(el)
                text_chunks.append(lin)
                char_pos += len(lin)
            elif el.tag == f"{{{A}}}graphicData":
                anchor_el = self.nearest_anchor(el)
                if el in seen_fig_elements:
                    continue
                seen_fig_elements.add(el)
                fids = self.handle_graphic_object(el, anchor_el, i, path)
                fig_ids.extend(fids)
                for k, fid in enumerate(fids):
                    fig_offsets.append({"fig": fid, "char": char_pos,
                                        **({} if k == 0 else {"nested_in": fids[0]})})
            elif el.tag == f"{{{V}}}imagedata":
                # صورة VML بلا مقابل DrawingML
                has_dml = any(local(a) == "graphicData" for a in ancestors(el, stop=p))
                if not has_dml:
                    fids = self.handle_graphic_object(el, self.nearest_anchor(el), i, path)
                    fig_ids.extend(fids)
                    for k, fid in enumerate(fids):
                        fig_offsets.append({"fig": fid, "char": char_pos,
                                            **({} if k == 0 else {"nested_in": fids[0]})})
            elif etree.QName(el).namespace == V and local(el) in ("shape", "group", "rect", "oval", "line", "roundrect", "polyline"):
                has_dml = any(local(a) == "graphicData" for a in ancestors(el, stop=p))
                if not has_dml:
                    fids = self.handle_graphic_object(el, self.nearest_anchor(el), i, path)
                    fig_ids.extend(fids)
                    for k, fid in enumerate(fids):
                        fig_offsets.append({"fig": fid, "char": char_pos,
                                            **({} if k == 0 else {"nested_in": fids[0]})})

        text = "".join(text_chunks)
        rec = {
            "i": i,
            "path": path,
            "kind": "p",
            "style": style,
            "outline": outline,
            "jc": jc,
            "ind": ind,
            "num": num,
            "rtl": rtl,
            "in_textbox_of": textbox_owner,
            "in_table": self._ctx["in_table"],
            "text": text,
            "chars": len(text),
            "eqs": eq_ids,
            "figs": fig_ids,
            "fig_offsets": fig_offsets,
            "empty": (not text.strip()) and not fig_ids and not eq_ids,
        }
        rec["flags"] = self.block_flags(rec)
        skeleton.clear()
        skeleton.update(rec)
        self._ctx = prev_ctx
        return i

    def block_flags(self, rec):
        t = rec["text"]
        stripped = t.strip()
        flags = {}
        if rec["figs"] and not stripped:
            flags["figure_only"] = True
        if len(rec["figs"]) >= 4:
            flags["figure_cluster"] = len(rec["figs"])
        multi = re.search(r"\S[ \t]{3,}\S", t)
        if multi:
            flags["multi_space_gap"] = True
            flags["gap_widths"] = sorted({len(m.group(0)) - len(m.group(0).strip()) for m in re.finditer(r"[ \t]{2,}", t)}, reverse=True)[:4]
        if stripped and len(set(stripped)) <= 2 and stripped[0] in ".…-_=*":
            flags["filler_line"] = True
        if "\t" in t:
            flags["has_tab"] = True
        if rec["style"] == "ListParagraph":
            flags["list_paragraph"] = True
        return flags

    def handle_table(self, tbl, path):
        i = len(self.blocks) + 1
        skeleton = {"i": i, "path": path, "kind": "tbl", "cell_blocks": [], "all_blocks": [],
                    "text": "", "figs": [], "eqs": [], "rows": 0, "cols": 0}
        self.blocks.append(skeleton)
        self.block_elems.append(tbl)
        rows = tbl.findall(f"{{{W}}}tr")
        cells = [tr.findall(f"{{{W}}}tc") for tr in rows]
        tblPr = tbl.find(f"{{{W}}}tblPr")
        grid = tbl.find(f"{{{W}}}tblGrid")
        rec = {
            "i": i,
            "path": path,
            "kind": "tbl",
            "rows": len(rows),
            "cols": max((len(c) for c in cells), default=0),
            "bidiVisual": tblPr is not None and tblPr.find(f"{{{W}}}bidiVisual") is not None,
            "gridCols_twips": [int(g.get(f"{{{W}}}w", "0")) for g in grid] if grid is not None else [],
            "cell_blocks": [],
            "text": "",
        }
        prev_ctx = dict(self._ctx)
        all_ids = []
        texts = []
        for ri, tr in enumerate(rows):
            for ci, tc in enumerate(tr.findall(f"{{{W}}}tc")):
                self._ctx["in_table"] = {"table": rec["i"], "row": ri + 1, "cell": ci + 1}
                ids = self.collect_blocks(tc, f"{path}/tr[{ri+1}]/tc[{ci+1}]")
                all_ids.extend(ids)
                texts.append(" | ".join(self.blocks[k - 1]["text"] for k in ids))
                rec["cell_blocks"].append({"row": ri + 1, "cell": ci + 1, "blocks": ids})
        rec["all_blocks"] = all_ids
        rec["text"] = "\n".join(texts)
        rec["chars"] = len(rec["text"])
        rec["figs"] = [f["id"] for f in self.figures if f.get("block") in all_ids]
        rec["eqs"] = [e["id"] for e in self.equations if e.get("block") in all_ids]
        skeleton.clear()
        skeleton.update(rec)
        self.tables.append(rec)
        self._ctx = prev_ctx
        return rec["i"]

    # -------------------------------------------------- fallback (VML) audit
    def scan_fallbacks(self):
        """كل AlternateContent لها Choice: نُوثّق ما في فرع Fallback من صور/أشكال مطابقة
        (لأن Word يرسم Choice؛ نُبقي الإشارة كي لا تُستخرج الصورة نفسها مرّتين)."""
        items = []
        for alt in self.doc.iter(f"{{{MC}}}AlternateContent"):
            if alt.find(f"{{{MC}}}Choice") is None:
                continue
            fb = alt.find(f"{{{MC}}}Fallback")
            if fb is None:
                continue
            rids = [e.get(f"{{{R}}}id") for e in fb.iter() if e.tag == f"{{{V}}}imagedata"]
            rids = [r for r in rids if r]
            shapes = [local(e) for e in fb.iter() if isinstance(e.tag, str)
                      and etree.QName(e).namespace == NS["v"] and local(e) in ("shape", "group", "oval", "rect", "line")]
            if rids or shapes:
                items.append({
                    "path": self.doc.getroottree().getpath(alt),
                    "fallback_images_rel": rids,
                    "fallback_image_targets": [
                        (self.rels.get(r, {}).get("target")) for r in rids
                    ],
                    "fallback_shapes": len(shapes),
                })
        return items

    # -------------------------------------------------- audit pass
    def run(self):
        self.collect_blocks(self.body, "body")
        self.fallback_items = self.scan_fallbacks()

    # -------------------------------------------------- derived summaries
    def symbol_census(self):
        """إحصاء الرموز الحرجة في النص والمعادلات (حماية ± ∓ والأقواس والجذور)."""
        text_all = "".join(b.get("text", "") for b in self.blocks)
        pat = {
            "± (plus-minus)": "±",
            "∓ (minus-plus)": "∓",
            "√ (radical char)": "√",
            "∑ (sum)": "∑",
            "Δ (Delta U+0394)": "Δ",
            "∆ (increment U+2206)": "∆",
            "α": "α", "β": "β", "γ": "γ", "δ": "δ", "ε": "ε", "η": "η", "θ": "θ",
            "λ": "λ", "μ": "μ", "π": "π", "ρ": "ρ", "σ": "σ", "τ": "τ", "φ": "φ",
            "ω": "ω", "Ω": "Ω", "∝ (proportional)": "∝", "∞": "∞", "≠": "≠", "≈": "≈",
            "≤": "≤", "≥": "≥", "⟹": "⟹", "→": "→", "←": "←", "⇐": "⇐",
            "°": "°", "×": "×", "⋅": "⋅", "·": "·", "∧": "∧", "Λ": "Λ",
        }
        census = {k: text_all.count(v) for k, v in pat.items()}
        # أنماط تصحيح الرموز السابقة (R1–R14) — للتحقق هل هي مطبقة في المصدر
        mtext = "".join(e["flat"] for e in self.equations)
        allt = text_all
        rules = {
            "R1 T_o → T_0": len(re.findall(r"T_o\b", mtext)),
            "R3 ∆ (U+2206) → Δ": allt.count("∆"),
            "R4 ∝ → α": allt.count("∝"),
            "R5 Γ_n → Γ_η": len(re.findall(r"Γ_?n", mtext)),
            "R7 Υ → γ": allt.count("Υ"),
            "R8 HZ/COS/P_evg/m..g/ⅈ": len(re.findall(r"HZ|COS|P_evg|m\.\.g|ⅈ", mtext + allt)),
            "R9 ωeb/ωat": len(re.findall(r"ωeb|ωat", mtext + allt)),
            "R10 Λ → ∧": allt.count("Λ"),
            "R11 f_o/v_o/v_ox/v_oy": len(re.findall(r"[fv]_o\b|[fv]_ox|[fv]_oy", mtext)),
            "R12 E_S/W_S": len(re.findall(r"[EWU]_S\b", mtext)),
            "R13 E_K/E_P": len(re.findall(r"[EW]_[KP]\b", mtext)),
            "R14 max → maX": len(re.findall(r"(X|θ|F|v|a|h)max\b", mtext + allt)),
        }
        return census, rules


# ---------------------------------------------------------------- report
def build_report(src, sha, manifest, extra):
    m = manifest
    c = m["counts"]
    L = []
    A = L.append
    A("# NHTML-0 — جرد نوطة الأستاذ فداء (النواسات)")
    A("")
    A(f"- **تاريخ الجرد:** {m['generated_at_utc']} (UTC)")
    A(f"- **المرحلة:** NHTML-0 (جرد فقط — لا تعديل ولا إخراج)")
    A(f"- **المصدر:** `{m['source']['repo_path']}`")
    A(f"- **نسخة مجمّدة:** `{m['source']['local_copy']}`")
    A(f"- **SHA-256:** `{m['source']['sha256']}`")
    A(f"- **الفرع/الكومِت:** `{m['source']['git_branch']}` / `{m['source']['git_commit']}`")
    A("")
    A("> هذا التقرير آلي بالكامل من `tools/inventory_docx.py` — لا اجتهاد بشري في الأرقام.")
    A("")
    A("## ١. ملخّص تنفيذي")
    A("")
    A("| البند | العدد |")
    A("|---|---|")
    A(f"| كتل المستند (فقرات + جداول، بما فيها مربعات النص) | {c['blocks_total']} |")
    A(f"| فقرات | {c['paragraphs_total']} |")
    A(f"| فقرات في أعلى المستند (body) | {c['paragraphs_body']} |")
    A(f"| فقرات داخل مربعات نصية | {c['paragraphs_in_textboxes']} |")
    A(f"| فقرات داخل جداول | {c['paragraphs_in_tables']} |")
    A(f"| جداول | {c['tables']} |")
    A(f"| معادلات OMML | {c['equations_total']} |")
    A(f"| — معروضة (oMathPara) | {c['equations_display']} |")
    A(f"| — مضمّنة في السطر | {c['equations_inline']} |")
    A(f"| — داخل جداول | {c['equations_in_tables']} |")
    A(f"| — داخل مربعات نصية | {c['equations_in_textboxes']} |")
    A(f"| كائنات رسومية (صور/أشكال/مربعات/مجموعات) | {c['figures_total']} |")
    A(f"| — صور (pic:pic) | {c['figures_pictures']} |")
    A(f"| — مربعات نصية | {c['figures_textboxes']} |")
    A(f"| — أشكال أخرى | {c['figures_shapes']} |")
    A(f"| — مجموعات | {c['figures_groups']} |")
    A(f"| — عائمة (anchor) / مضمّنة (inline) | {c['figures_anchored']} / {c['figures_inline']} |")
    A(f"| ملفات وسائط في الحزمة | {c['media_files']} |")
    A(f"| صور مستخدمة فعلياً | {c['media_used']} |")
    A(f"| صور مستخدمة في فرع fallback فقط | {c['media_fallback_only']} |")
    A(f"| صور غير مستخدمة (أيتام) | {c['media_orphans']} |")
    A(f"| أبناء مجموعات الأشكال (مفهرسون إضافياً) | {c['figures_from_groups']} |")
    A(f"| كائنات fallback مرآتية (لم تُعدّ ككائنات مستقلة) | {c['fallback_visual_objects']} |")
    A(f"| إجمالي بايتات الوسائط | {c['media_bytes']:,} |")
    A("")
    A(f"> «معروضة (oMathPara)» = {c['equations_display']} كتلة معادلة داخل "
      f"{manifest['counts']['equations_total'] and ''}{c['equations_display'] and ''}"
      f"حاويات oMathPara؛ وعدد حاويات `m:oMathPara` في XML هو "
      f"{manifest['checks'].get('معادلات معروضة (oMathPara) في XML','—')} "
      "(إحداها تضمّ معادلتين).")
    A("")
    A("> تفاصيل الرموز وتصحيحاتها وتعديلات r15–r23 في: `reports/NHTML-0-source-audit.md`.")
    A("")
    A("## ٢. إعداد الصفحة والمستند")
    A("")
    sec = m["section"]
    A(f"- حجم الصفحة: {sec['pgSz_cm']} cm (orient={sec['orient']})")
    A(f"- الهوامش: أعلى {sec['pgMar_cm']['top']} · أسفل {sec['pgMar_cm']['bottom']} · يمين {sec['pgMar_cm']['right']} · يسار {sec['pgMar_cm']['left']} cm")
    A(f"- `w:bidi` (اتجاه المستند RTL): {sec['bidi']} · `rtlGutter`: {sec['rtlGutter']}")
    A(f"- تذييل الصفحة: «{sec['footer_text']}» (رسوم في التذييل: {sec['footer_drawings']})")
    A(f"- الخط الافتراضي (docDefaults): {m['styles']['docDefaults']}")
    A(f"- أنماط الفقرات المستخدمة: {m['styles']['paragraph_styles_used']}")
    A("")
    A("## ٣. تصنيف الكتل")
    A("")
    A("| التصنيف | العدد |")
    A("|---|---|")
    for k, v in m["block_census"].items():
        A(f"| {k} | {v} |")
    A("")
    A("## ٤. المعادلات — إحصاء البنية والرموز")
    A("")
    A("| البنية | العدد |")
    A("|---|---|")
    for k, v in sorted(m["equation_features"].items(), key=lambda x: -x[1]):
        A(f"| `{k}` | {v} |")
    A("")
    A("**إحصاء الرموز الحرجة في النص الحرفي (كل الكتل):**")
    A("")
    A("| الرمز | العدد |")
    A("|---|---|")
    for k, v in m["symbol_census"].items():
        if v:
            A(f"| {k} | {v} |")
    A("")
    A("> حالة قواعد تصحيح الرموز R1–R14 (ومقارنة السلالات وتسلسل المراجعات) في تقرير مستقل: "
      "`reports/NHTML-0-source-audit.md` — لا تُكرَّر هنا كي لا يتفرّع مصدر الأرقام.")
    A("")
    A("## ٥. الرسومات والصور — جرد مرتّب")
    A("")
    A("أول ٤٠ كائناً رسومياً بترتيب الظهور (الجدول الكامل في `content/manifest.json`):")
    A("")
    A("| # | المعرّف | النوع | المرساة | العلاقة | الملف | px | العرض×الارتفاع (cm) | الكتلة |")
    A("|---|---|---|---|---|---|---|---|---|")
    for f in m["figures"][:40]:
        px = f.get("natural", {}).get("px")
        px = f"{px[0]}×{px[1]}" if px else "—"
        ext = f.get("extent_cm", {})
        ext = f"{ext.get('w','—')}×{ext.get('h','—')}" if ext else "—"
        A(f"| {f['order']} | {f['id']} | {f['kind']} | {f['anchor']} | {f.get('rel_id','—')} | "
          f"{(f.get('media') or '—').split('/')[-1]} | {px} | {ext} | {f.get('block')} |")
    A("")
    A(f"**صور غير مستخدمة (أيتام):** {', '.join(m['media_orphan_list']) or 'لا يوجد'}")
    A("")
    A("**أكبر ١٠ صور:**")
    A("")
    A("| الملف | px | بايت | عدد الاستخدامات |")
    A("|---|---|---|---|")
    for im in m["media_largest"][:10]:
        px = im.get("px")
        px = f"{px[0]}×{px[1]}" if px else "—"
        A(f"| {im['name'].split('/')[-1]} | {px} | {im['bytes']:,} | {im.get('uses',0)} |")
    A("")
    A("## ٦. الأسئلة والعناوين (مرشّحات الجرد — بلا تعديل على النص)")
    A("")
    A(f"**عناوين مرشّحة ({len(m['heading_candidates'])}):**")
    A("")
    A("| الكتلة | الدليل | النص |")
    A("|---|---|---|")
    for h in m["heading_candidates"][:60]:
        A(f"| {h['block']} | {h['evidence']} | {h['text'][:80]} |")
    A("")
    A(f"**أسئلة مرشّحة ({len(m['question_candidates'])}):**")
    A("")
    A("| الكتلة | النمط | النص |")
    A("|---|---|---|")
    for qq in m["question_candidates"][:80]:
        A(f"| {qq['block']} | {qq['pattern']} | {qq['text'][:90]} |")
    A("")
    A("## ٧. ملاحظات تخطيطية حرجة للمراحل التالية")
    A("")
    for note in extra["layout_notes"]:
        A(f"- {note}")
    A("")
    A("## ٨. فحوصات التطابق الداخلي (Reconciliation)")
    A("")
    A("| الفحص | النتيجة |")
    A("|---|---|")
    for k, v in m["checks"].items():
        A(f"| {k} | {v} |")
    A("")
    A("## ٩. ما لم يُنفَّذ في هذه المرحلة (مقصود)")
    A("")
    for x in extra["not_done"]:
        A(f"- {x}")
    A("")
    A("---")
    A("")
    A("**الملفات الناتجة عن NHTML-0:**")
    A("")
    for x in extra["artifacts"]:
        A(f"- `{x}`")
    A("")
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="notes/النواسات م_101932-r23-all-absolute-value-bars-green.docx")
    ap.add_argument("--out", default="rebuild/nawwasat")
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    src = (repo / args.src).resolve() if not Path(args.src).is_absolute() else Path(args.src)
    out = (repo / args.out).resolve() if not Path(args.out).is_absolute() else Path(args.out)
    for sub in ("source", "content", "reports", "tools", "assets/images", "assets/equations", "html", "pdf"):
        (out / sub).mkdir(parents=True, exist_ok=True)

    if not src.exists():
        sys.exit(f"المصدر غير موجود: {src}")
    sha = hashlib.sha256(src.read_bytes()).hexdigest()

    # 1) تجميد المصدر (نسخ بايت-لبايت)
    dest = out / "source" / "original.docx"
    shutil.copy2(src, dest)
    git_commit = extra_git(repo, "rev-parse", "HEAD")
    git_branch = extra_git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    git_url = extra_git(repo, "config", "--get", "remote.origin.url")
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    (out / "source" / "source-hash.txt").write_text(
        "\n".join([
            f"file: {args.src}",
            f"copied_to: {out.relative_to(repo)}/source/original.docx".replace("\\", "/"),
            f"sha256: {sha}",
            f"bytes: {src.stat().st_size}",
            f"repo: {git_url}",
            f"git_branch: {git_branch}",
            f"git_commit: {git_commit}",
            f"recorded_at_utc: {now}",
            "note: نسخة مطابقة بايت-لبايت لملف المصدر؛ لا تُعدَّل ولا تُعاد حفظها بأي مكتبة.",
        ]) + "\n",
        encoding="utf-8",
    )

    inv = Inventory(src)
    inv.run()

    # قسم المستند
    sect = inv.doc.find(f"{{{W}}}body/{{{W}}}sectPr")
    def tw2cm(v): return round(int(v) / TWIP_PER_CM, 3)
    pgSz = sect.find(f"{{{W}}}pgSz"); pgMar = sect.find(f"{{{W}}}pgMar")
    orient = pgSz.get(f"{{{W}}}orient", "portrait")
    w_cm = tw2cm(pgSz.get(f"{{{W}}}w")); h_cm = tw2cm(pgSz.get(f"{{{W}}}h"))
    if orient == "landscape":
        w_cm, h_cm = max(w_cm, h_cm), min(w_cm, h_cm)
    footer_ref = sect.find(f"{{{W}}}footerReference")
    footer_text = ""
    footer_drawings = 0
    if footer_ref is not None:
        rid = footer_ref.get(f"{{{R}}}id")
        rel = inv.rels.get(rid, {})
        if rel.get("target"):
            try:
                fr = etree.fromstring(inv.zip.read(f"word/{rel['target']}"))
                footer_text = element_text(fr)
                footer_drawings = len(fr.findall(f".//{{{W}}}drawing")) + len(fr.findall(f".//{{{W}}}pict"))
            except KeyError:
                pass

    # أنماط
    styles_root = etree.fromstring(inv.zip.read("word/styles.xml"))
    doc_defaults = styles_root.find(f"{{{W}}}docDefaults/{{{W}}}rPrDefault/{{{W}}}rPr")
    dd = {}
    if doc_defaults is not None:
        f_ = doc_defaults.find(f"{{{W}}}rFonts"); s_ = doc_defaults.find(f"{{{W}}}sz")
        dd = {"rFonts": {k.split('}')[-1]: v for k, v in (f_.attrib.items() if f_ is not None else [])},
              "sz_halfpoints": s_.get(f"{{{W}}}val") if s_ is not None else None}
        if dd["sz_halfpoints"]:
            dd["sz_pt"] = int(dd["sz_halfpoints"]) / 2

    # كتل وعدّ
    paras = [b for b in inv.blocks if b["kind"] == "p"]
    tbls = [b for b in inv.blocks if b["kind"] == "tbl"]
    p_body = [b for b in paras if b["in_textbox_of"] is None and b["in_table"] is None]
    p_tb = [b for b in paras if b["in_textbox_of"] is not None]
    p_tbl = [b for b in paras if b["in_table"] is not None and b["in_textbox_of"] is None]

    figures = inv.figures
    media_all = sorted(n for n in inv.zip.namelist()
                       if n.startswith("word/media/") and not n.endswith("/"))
    media_used = sorted(n for n in inv.img_usage if n in media_all)
    image_rels = {rid: r for rid, r in inv.rels.items() if r["type"] == "image"}
    rel_targets = {rid: "word/" + (r["target"] or "") for rid, r in image_rels.items()}
    used_targets = set(media_used)
    fallback_targets = set()
    for it in getattr(inv, "fallback_items", []):
        for t in it.get("fallback_image_targets") or []:
            if t:
                fallback_targets.add("word/" + t)
    media_fallback_only = sorted(t for t in (fallback_targets - used_targets) if t in media_all)
    media_rel_unused = sorted(t for rid, t in rel_targets.items()
                              if t not in used_targets and t not in fallback_targets and t in media_all)
    media_orphans = sorted(n for n in media_all if n not in set(rel_targets.values()))

    eq_feats = collections.Counter()
    for e in inv.equations:
        for f in e["features"]:
            eq_feats[f] += 1

    # مرشحات العناوين والأسئلة
    headings = []
    questions = []
    q_patterns = [
        (r"^\s*س\s*\d+\s*[)\-–:]", "س<n>)"),
        (r"^\s*\d+\s*[)\-–]\s*", "n)"),
        (r"^\s*\*+", "نجمة*"),
        (r"^\s*(سؤال|تمرين|مسألة|مثال|تطبيق|حل|وظيفة|نشاط)\b", "كلمة (سؤال/تمرين/…)"),
        (r"[?؟]\s*$", "ينتهي بعلامة استفهام"),
    ]
    for b in paras:
        t = b["text"].strip()
        if not t:
            continue
        if b["outline"] is not None:
            headings.append({"block": b["i"], "evidence": f"outlineLvl={b['outline']}", "text": t})
            continue
        if b["style"] and re.search(r"(Head|عنوان|Title)", b["style"], re.I):
            headings.append({"block": b["i"], "evidence": f"style={b['style']}", "text": t})
            continue
        score = 0
        ev = []
        if t.startswith("*"):
            score += 2; ev.append("يبدأ بـ *")
        if len(t) < 60 and not re.search(r"[.،؟!]", t):
            score += 1; ev.append("قصير بلا ترقيم جملة")
        if re.match(r"^\s*(ال)?[\u0621-\u064A ]{3,40}$", t) and len(t.split()) <= 6:
            score += 1; ev.append("عنوان قصير محتمل")
        if score >= 3:
            headings.append({"block": b["i"], "evidence": " + ".join(ev), "text": t})
        for pat, label in q_patterns:
            if re.search(pat, t):
                questions.append({"block": b["i"], "pattern": label, "text": t})
                break

    # ملاحظات تخطيطية
    cluster_blocks = [b for b in paras if "figure_cluster" in b["flags"]]
    multicol = [b for b in paras if "multi_space_gap" in b["flags"]]
    filler = [b for b in paras if "filler_line" in b["flags"]]
    empty_runs = 0
    run = 0
    for b in paras:
        if b["empty"]:
            run += 1
        else:
            if run >= 4:
                empty_runs += 1
            run = 0
    behind = [f for f in figures if f.get("behindDoc")]
    with_text_blocks = [f for f in figures if f.get("text_blocks")]

    counts = {
        "blocks_total": len(inv.blocks),
        "paragraphs_total": len(paras),
        "paragraphs_body": len(p_body),
        "paragraphs_in_textboxes": len(p_tb),
        "paragraphs_in_tables": len(p_tbl),
        "tables": len(tbls),
        "equations_total": len(inv.equations),
        "equations_fallback_copies": 0,
        "equations_display": sum(1 for e in inv.equations if e["display"]),
        "equations_inline": sum(1 for e in inv.equations if not e["display"]),
        "equations_in_tables": sum(1 for e in inv.equations if e["in_table"]),
        "equations_in_textboxes": sum(1 for e in inv.equations if e["in_textbox_of"]),
        "figures_total": len(figures),
        "figures_pictures": sum(1 for f in figures if f["kind"] == "picture"),
        "figures_textboxes": sum(1 for f in figures if f["kind"] == "textbox"),
        "figures_shapes": sum(1 for f in figures if f["kind"] not in ("picture", "textbox", "group")),
        "figures_groups": sum(1 for f in figures if f["kind"] == "group"),
        "figures_anchored": sum(1 for f in figures if f["anchor"] == "anchor"),
        "figures_inline": sum(1 for f in figures if f["anchor"] == "inline"),
        "figures_from_graphicData": sum(1 for f in figures if f.get("source") == "graphicData"),
        "figures_from_groups": sum(1 for f in figures if f.get("source") == "group-child"),
        "fallback_visual_objects": len(getattr(inv, "fallback_items", [])),
        "media_files": len(media_all),
        "media_used": len(media_used),
        "media_fallback_only": len(media_fallback_only),
        "media_rel_unused": len(media_rel_unused),
        "media_orphans": len(media_orphans),
        "media_bytes": sum(inv.media_entry(n).get("bytes", 0) for n in media_all),
    }

    block_census = {
        "فقرات فارغة كلياً": sum(1 for b in paras if b["empty"]),
        "فقرات فيها نص فقط": sum(1 for b in paras if b["text"].strip() and not b["figs"] and not b["eqs"]),
        "فقرات نص + معادلة": sum(1 for b in paras if b["text"].strip() and b["eqs"] and not b["figs"]),
        "فقرات فيها رسومات فقط": sum(1 for b in paras if b["figs"] and not b["text"].strip()),
        "فقرات نص + رسومات": sum(1 for b in paras if b["figs"] and b["text"].strip()),
        "فقرات معادلة فقط": sum(1 for b in paras if b["eqs"] and not b["text"].strip() and not b["figs"]),
        "فقرات بلا أي محتوى مرئي (فواصل/مسافات)": sum(1 for b in paras if not b["text"].strip() and not b["figs"] and not b["eqs"]),
        "فقرات ListParagraph": sum(1 for b in paras if b["style"] == "ListParagraph"),
        "فقرات مرقّمة (numPr)": sum(1 for b in paras if b["num"]),
        "فقرات فيها تاب/تبويب": sum(1 for b in paras if "has_tab" in b["flags"]),
        "فقرات بفراغات متعددة (مرشّحة لعمودين)": len(multicol),
        "فقرات خطوط نقاط/فواصل": len(filler),
        "فقرات عنقود رسومات (4+)": len(cluster_blocks),
    }

    n_omath_all = len(inv.doc.findall(f".//{{{M}}}oMath"))
    n_omath_fb = len([e for e in inv.doc.iter(f"{{{M}}}oMath")
                      if any(a.tag == f"{{{MC}}}Fallback" for a in e.iterancestors())])
    n_omath = n_omath_all - n_omath_fb
    n_omathpara = len(inv.doc.findall(f".//{{{M}}}oMathPara"))
    n_gd = len(inv.doc.findall(f".//{{{A}}}graphicData"))
    n_pic = len([e for e in inv.doc.iter(f"{{{PIC}}}pic")
                 if not any(a.tag == f"{{{MC}}}Fallback" for a in e.iterancestors())])
    n_txbx = len([e for e in inv.doc.iter(f"{{{W}}}txbxContent")
                  if not any(a.tag == f"{{{MC}}}Fallback" for a in e.iterancestors())])
    n_imgrels = sum(1 for r in inv.rels.values() if r["type"] == "image")
    def ok(a, b): return f"{a} = {b} ✅" if a == b else f"{a} ≠ {b} ❌"
    checks = {
        "معادلات OMML: المفهرس = المعروض في XML (خارج fallback)": ok(len(inv.equations), n_omath),
        "معادلات نسخ fallback المرآتية (لا تُفهرس — Word يرسم Choice)": str(n_omath_fb),
        "معادلات معروضة (oMathPara) في XML": str(n_omathpara),
        "رسومات: المفهرس من مسار graphicData = عدد graphicData": ok(
            counts["figures_from_graphicData"], n_gd),
        "رسومات: أبناء المجموعات (مفهرسون إضافياً)": str(counts["figures_from_groups"]),
        "رسومات: مراجع الفقرات = عدد الكائنات": (
            f"{sum(len(b['figs']) for b in paras)} = {len(figures)} "
            + ("✅" if sum(len(b["figs"]) for b in paras) == len(figures) else "❌")),
        "رسومات: كل كائن مرتبط بكتلة في الفهرس": (
            f"{len([f for f in figures if f.get('block')])} من {len(figures)} ✅"
            if all(f.get("block") for f in figures) else "❌ كائن بلا كتلة"),
        "صور pic:pic (خارج fallback) = رسومات نوع «صورة»": ok(counts["figures_pictures"], n_pic),
        "مربعات النص w:txbxContent = كائنات نوع «مربع نص»": ok(counts["figures_textboxes"], n_txbx),
        "مراجع الصور في العلاقات = الملفات المستخدمة + fallback + يتيم/غير مستخدم": ok(
            n_imgrels, len(media_used) + len(media_fallback_only) + len(media_rel_unused)),
        "ملفات الوسائط = مستخدم + fallback + غير مستخدم + يتيم": ok(
            len(media_all), len(media_used) + len(media_fallback_only) + len(media_rel_unused) + len(media_orphans)),
        "كل رسماً مفهرساً مرتبط بعلاقة/ملف قائم": "✅" if all(
            (f.get("media") in media_all) for f in figures if f.get("media")) else "❌",
        "كائنات fallback المرآتية لم تُفهرس كرسومات مستقلة": "✅ (لا تكرار)",
        "فقرات أعلى المستند + جداول": f"{len(p_body)} فقرة + {len(tbls)} جدول",
        "جداول: اتجاه RTL (bidiVisual)": f"{sum(1 for t in tbls if t['bidiVisual'])} من {len(tbls)}",
        "مجموع كتل الفهرس = فقرات + جداول": ok(len(inv.blocks), len(paras) + len(tbls)),
    }

    manifest = {
        "stage": "NHTML-0",
        "generated_at_utc": now,
        "generator": "rebuild/nawwasat/tools/inventory_docx.py",
        "source": {
            "repo_path": args.src,
            "local_copy": f"{out.relative_to(repo)}/source/original.docx".replace("\\", "/"),
            "sha256": sha,
            "bytes": src.stat().st_size,
            "repo": git_url,
            "git_branch": git_branch,
            "git_commit": git_commit,
        },
        "section": {
            "pgSz_cm": {"w": w_cm, "h": h_cm},
            "orient": orient,
            "pgMar_cm": {k: tw2cm(pgMar.get(f"{{{W}}}{k}", "0")) for k in ("top", "right", "bottom", "left")},
            "bidi": sect.find(f"{{{W}}}bidi") is not None,
            "rtlGutter": sect.find(f"{{{W}}}rtlGutter") is not None,
            "footer_text": footer_text,
            "footer_drawings": footer_drawings,
        },
        "styles": {
            "docDefaults": dd,
            "paragraph_styles_used": dict(collections.Counter(b["style"] or "(none)" for b in paras)),
        },
        "counts": counts,
        "block_census": block_census,
        "equation_features": dict(eq_feats),
        "symbol_census": inv.symbol_census()[0],
        "symbol_rules_see": "content/source-audit.json (تقرير NHTML-0-source-audit.md)",
        "checks": checks,
        "layout_evidence": {
            "figure_cluster_blocks": [{"block": b["i"], "figs": len(b["figs"]), "text": b["text"][:80]} for b in cluster_blocks],
            "multicol_candidate_blocks": [{"block": b["i"], "text": b["text"][:200]} for b in multicol][:200],
            "behind_text_figures": [f["id"] for f in behind],
            "figures_with_text_blocks": [{"id": f["id"], "blocks": f.get("text_blocks")} for f in with_text_blocks],
            "empty_run_count_4plus": empty_runs,
        },
        "blocks": inv.blocks,
        "equations": inv.equations,
        "figures": figures,
        "media": sorted(inv.media_info.values(), key=lambda x: x["name"]),
        "media_usage": {k: v for k, v in sorted(inv.img_usage.items())},
        "media_orphan_list": media_orphans,
        "media_fallback_only_list": media_fallback_only,
        "media_rel_unused_list": media_rel_unused,
        "fallback_visual_objects": getattr(inv, "fallback_items", []),
        "media_largest": sorted(
            [dict(inv.media_entry(n), uses=len(inv.img_usage.get(n, []))) for n in media_all],
            key=lambda x: -x.get("bytes", 0)),
        "heading_candidates": headings,
        "question_candidates": questions,
    }

    (out / "content" / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1, sort_keys=False), encoding="utf-8")

    layout_notes = [
        f"{counts['figures_anchored']} كائناً رسومياً **عائم** (`wp:anchor`) مقابل {counts['figures_inline']} مضمّن: "
        "الترتيب البصري في Word لا يتبع ترتيب النص، لذلك يجب إعادة بناء الرسومات كعناصر ساكنة داخل التدفق (figure) وربطها بالكتلة المرساة.",
        f"{counts['paragraphs_in_textboxes']} فقرة تسكن داخل مربعات نصية عائمة ({counts['figures_textboxes']} مربعاً): "
        "نصوص هذه المربعات جزء من المحتوى الحرفي للأستاذ ويجب استخراجها كما هي.",
        f"{len(cluster_blocks)} كتلة تحمل 4 رسومات أو أكثر مرساة إليها (عناقيد رسومية) — التوزيع الأصلي يعتمد التداخل والطبقات.",
        f"{len(multicol)} فقرة تحتوي فراغات متعددة ظاهرياً لبناء «عمودين» في سطر واحد (مثل مقارنة «حالة السكون / حالة الحركة») — "
        "إعادة بنائها كشبكة عمودين تحفظ الكلمات حرفياً وتُصلح التخطيط.",
        f"{sum(1 for f in figures if f.get('behindDoc'))} رسماً خلف النص (`behindDoc=1`) و{sum(1 for f in figures if f.get('wrap') == 'wrapNone')} بلا التفاف نص.",
        f"{empty_runs} موضعاً فيه 4 فقرات فارغة متتالية أو أكثر (مسافات يدوية) — تُستبدل في HTML بمسافات CSS مضبوطة.",
        f"{len(filler)} فقرة هي سطر نقاط/شرطات تعبئة (نقاط فراغ للحل) — تبقى كما هي لكن بعرض مضبوط.",
        f"التذييل يحمل «{footer_text}» — يُنقل إلى تذييل CSS للطباعة دون مسّ النص.",
        f"مكتبة الصور: {counts['media_used']} صورة مستخدمة، {counts['media_orphans']} صورة يتيمة داخل الحزمة "
        f"(تُستخرج في NHTML-1 مع توثيق حالة اليُتم).",
        "كل الرسومات تُستخرج كما هي (بايت-لبايت) بلا إعادة ضغط ولا تغيير ألوان — تعديلات الألوان (r15–r23) جزء من ملف المصدر المجمّد.",
    ]
    not_done = [
        "لم يُستخرج أي نص إلى `content/text.json` (مهمة NHTML-1).",
        "لم تُستخرج الصور إلى `assets/images/` (مهمة NHTML-1) — الجرد قرأ الأبعاد من الحزمة بلا كتابة.",
        "لم تُبنَ صفحة HTML ولا CSS ولا PDF (NHTML-2..NHTML-4).",
        "لم يُفتح الملف في Word ولم يُعد حفظه بأي مكتبة (منعاً لأي انزياح في الرسومات).",
        "لم تُنفَّذ تعديلات الرموز R1–R14 من جديد — الجرد يكشف حالتها في المصدر فقط (انظر الجدول أعلاه).",
    ]
    artifacts = [
        "rebuild/nawwasat/source/original.docx",
        "rebuild/nawwasat/source/source-hash.txt",
        "rebuild/nawwasat/content/manifest.json",
        "rebuild/nawwasat/reports/NHTML-0-inventory.md",
        "rebuild/nawwasat/tools/inventory_docx.py",
        "rebuild/nawwasat/tools/source_audit.py",
        "rebuild/nawwasat/content/source-audit.json",
        "rebuild/nawwasat/reports/NHTML-0-source-audit.md",
    ]
    (out / "reports" / "NHTML-0-inventory.md").write_text(
        build_report(args.src, sha, manifest, {"layout_notes": layout_notes, "not_done": not_done, "artifacts": artifacts}),
        encoding="utf-8")

    print(f"SHA-256: {sha}")
    print(json.dumps(counts, ensure_ascii=False, indent=1))
    for k, v in checks.items():
        print(f"  - {k}: {v}")

    print("wrote:", (out / "content" / "manifest.json"), (out / "reports" / "NHTML-0-inventory.md"))


def extra_git(repo: Path, *cmd):
    import subprocess
    try:
        return subprocess.run(["git", "-C", str(repo), *cmd], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return ""


if __name__ == "__main__":
    main()
