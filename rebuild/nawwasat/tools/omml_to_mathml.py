#!/usr/bin/env python3
"""OMML → MathML Core (بلا مكتبات خارجية) — يخدم NHTML-2.

يُستخدم لتحويل معادلات Word (OMML) إلى MathML Core الذي يرسمه Chromium أصلياً،
مع الحفاظ على:
  • الألوان (مثل الأخضر 008000 على محددات القيمة المطلقة، والأحمر EE0000 للنصوص الأساسية)
  • الغامق/المائل/الحجم النسبي لكل مقطع
  • الكسور والجذور والمحددات (|…|) والأقواس والتوابع والرموز اليونانية
  • الكلمات العربية داخل المعادلات (mtext باتجاه RTL معزول)
"""
from __future__ import annotations

import re
from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
M = "http://schemas.openxmlformats.org/officeDocument/2006/math"

# أدوات تُكتب قائمة (upright) لا مائلة
FUNCS = {"sin", "cos", "tan", "cot", "sec", "csc", "sinh", "cosh", "tanh",
         "log", "ln", "exp", "lim", "max", "min", "det", "mod", "gcd"}
# أوقات/رموز تُعرض كعوامل
OPS = set("+-−=<>≤≥≠≈≡∓±×÷⋅·∙∘∗*/\\^_|,;:!()[]{}⟨⟩→←↔⟹⟸⇒⇐∑∏∫√∞∂∇'′″″")
GREEK = set("αβγδεζηθικλμνξπρστυφχψωΓΔΘΛΞΠΣΦΨΩ")


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def attr_esc(s: str) -> str:
    return esc(s).replace('"', "&quot;")


def _local(el) -> str:
    return etree.QName(el).localname


def _kids(el):
    return [c for c in el if isinstance(c.tag, str)]


def _find(el, name):
    for c in _kids(el):
        if _local(c) == name:
            return c
    return None


def _findall(el, name):
    return [c for c in _kids(el) if _local(c) == name]


def _color_of(el) -> str | None:
    """لون مقطع/محدد من w:rPr/w:color (يخدم الأخضر 008000 على |…|)."""
    for wrpr in el.iter(f"{{{W}}}rPr"):
        c = wrpr.find(f"{{{W}}}color")
        if c is not None:
            v = (c.get(f"{{{W}}}val") or "").strip()
            if v and v.lower() not in ("auto",):
                return "#" + v.lstrip("#").upper()
    return None


def _run_props(run) -> dict:
    """خصائص مقطع OMML: غامق/مائل/حجم/لون/نمط."""
    props = {}
    col = _color_of(run)
    if col:
        props["color"] = col
    wrpr = None
    for c in _kids(run):
        if _local(c) == "rPr" and etree.QName(c).namespace == W:
            wrpr = c
    if wrpr is not None:
        if wrpr.find(f"{{{W}}}b") is not None and wrpr.find(f"{{{W}}}b").get(f"{{{W}}}val", "1") != "0":
            props["bold"] = True
        if wrpr.find(f"{{{W}}}i") is not None and wrpr.find(f"{{{W}}}i").get(f"{{{W}}}val", "1") != "0":
            props["italic"] = True
        sz = wrpr.find(f"{{{W}}}sz")
        if sz is not None and sz.get(f"{{{W}}}val", "").isdigit():
            props["sz"] = int(sz.get(f"{{{W}}}val"))
    # نمط رياضي: p=عادي، b=غامق، i=مائل
    mrpr = None
    for c in _kids(run):
        if _local(c) == "rPr" and etree.QName(c).namespace == M:
            mrpr = c
    if mrpr is not None:
        sty = _find(mrpr, "sty")
        if sty is not None:
            v = sty.get(f"{{{M}}}val")
            if v == "b":
                props["bold"] = True
            elif v == "i":
                props["italic"] = True
            elif v == "p":
                props["upright"] = True
    return props


def _style_attr(props: dict) -> str:
    css = []
    if props.get("color"):
        css.append(f"color:{props['color']}")
    if props.get("bold"):
        css.append("font-weight:700")
    if props.get("italic"):
        css.append("font-style:italic")
    if props.get("sz"):
        base = 28.0  # الحجم الغالب في نوطة الأستاذ (14pt)
        scale = max(0.8, min(1.45, props["sz"] / base))
        if abs(scale - 1.0) > 0.06:
            css.append(f"font-size:{scale:.2f}em")
    return ";".join(css)


def _wrap(inner: str, props: dict, tag: str = "mstyle") -> str:
    style = _style_attr(props)
    if not style:
        return inner
    return f'<{tag} style="{attr_esc(style)}">{inner}</{tag}>'


AR = re.compile(r"[\u0600-\u06FF\u0750-\u077F]+")
NUM = re.compile(r"\d+(?:[.,]\d+)?")
NAME = re.compile(r"[A-Za-z]+")


def _tokens(text: str, props: dict) -> str:
    """تقسيم نص مقطع إلى عناصر MathML مناسبة."""
    out = []
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        m = AR.match(text, i)
        if m:
            out.append(f'<mtext dir="rtl" class="ar-in-math">{esc(m.group(0))}</mtext>')
            i = m.end()
            continue
        m = NUM.match(text, i)
        if m:
            out.append(f"<mn>{esc(m.group(0))}</mn>")
            i = m.end()
            continue
        m = NAME.match(text, i)
        if m:
            word = m.group(0)
            # كلمة لاتينية: دالة معروفة ⇒ upright، وإلا تُعرض حرفاً حرفاً (متغيّرات مائلة)
            if word.lower() in FUNCS and len(word) > 1:
                out.append(f'<mo class="fn" style="font-style:normal">{esc(word)}</mo>')
            elif len(word) == 1:
                out.append(f"<mi>{esc(word)}</mi>")
            else:
                out.append("<mrow>" + "".join(f"<mi>{esc(c)}</mi>" for c in word) + "</mrow>")
            i = m.end()
            continue
        if ch in GREEK:
            out.append(f"<mi>{esc(ch)}</mi>")
            i += 1
            continue
        if ch.isspace():
            out.append("<mspace width=\"0.28em\"></mspace>")
            i += 1
            continue
        if ch in OPS:
            # بعض الرموز تحتاج تجميعاً (⟹ ⇐ ⇒ ∓ ± ⃗)
            out.append(f"<mo>{esc(ch)}</mo>")
            i += 1
            continue
        # الحروف العربية المُشكَّلة والرموز المدمجة (مثل ⃗) والعربية الأردية
        if "\u064b" <= ch <= "\u0652" or ch == "\u20d7":  # تشكيل أو سهم فوق الحرف
            out.append(f'<mo class="accent">{esc(ch)}</mo>')
            i += 1
            continue
        out.append(f"<mo>{esc(ch)}</mo>")
        i += 1
    return "<mrow>" + "".join(out) + "</mrow>" if len(out) != 1 else out[0]


def omml_to_mathml(el) -> str:
    """يحوّل عنصر OMML (m:oMath أو عنصر فرعي) إلى MathML Core (سلسلة)."""
    name = _local(el)

    if name in ("oMath", "oMathPara", "e", "num", "den", "deg", "sup", "sub", "fName", "lim", "box"):
        parts = [omml_to_mathml(c) for c in _kids(el)]
        return "<mrow>" + "".join(parts) + "</mrow>"

    if name == "r":
        text = "".join(t.text or "" for t in el.iter(f"{{{M}}}t"))
        if text == "":
            return ""
        return _wrap(_tokens(text, _run_props(el)), _run_props(el))

    if name == "f":
        num, den = _find(el, "num"), _find(el, "den")
        return f"<mfrac>{omml_to_mathml(num)}{omml_to_mathml(den)}</mfrac>"

    if name == "rad":
        deg, e = _find(el, "deg"), _find(el, "e")
        degpr = _find(el, "radPr")
        hidden = degpr is not None and _find(degpr, "degHide") is not None
        if deg is None or hidden or not (deg.text or "").strip() and not _kids(deg):
            return f"<msqrt>{omml_to_mathml(e)}</msqrt>"
        return f"<mroot>{omml_to_mathml(e)}{omml_to_mathml(deg)}</mroot>"

    if name == "sSup":
        return f"<msup>{omml_to_mathml(_find(el,'e'))}{omml_to_mathml(_find(el,'sup'))}</msup>"
    if name == "sSub":
        return f"<msub>{omml_to_mathml(_find(el,'e'))}{omml_to_mathml(_find(el,'sub'))}</msub>"
    if name == "sSubSup":
        return (f"<msubsup>{omml_to_mathml(_find(el,'e'))}"
                f"{omml_to_mathml(_find(el,'sub'))}{omml_to_mathml(_find(el,'sup'))}</msubsup>")
    if name == "sPre":
        return (f"<mmultiscripts>{omml_to_mathml(_find(el,'e'))}<mprescripts></mprescripts>"
                f"{omml_to_mathml(_find(el,'sub'))}{omml_to_mathml(_find(el,'sup'))}</mmultiscripts>")

    if name == "d":
        pr = _find(el, "dPr")
        beg, end = "(", ")"
        if pr is not None:
            b, e_ = _find(pr, "begChr"), _find(pr, "endChr")
            if b is not None:
                beg = b.get(f"{{{M}}}val", "(")
            if e_ is not None:
                end = e_.get(f"{{{M}}}val", ")")
        inner = [_kids(e) for e in _findall(el, "e")]
        inner_html = "".join(f"<mrow>{''.join(omml_to_mathml(c) for c in cs)}</mrow>" if len(cs) > 1
                             else "".join(omml_to_mathml(c) for c in cs)
                             for cs in inner)
        # لون المحدد (الأخضر على |…|) يعيش في dPr/ctrlPr
        dcol = None
        if pr is not None:
            ctrl = _find(pr, "ctrlPr")
            if ctrl is not None:
                dcol = _color_of(ctrl)
        if dcol:
            style = f"color:{dcol}"
            return (f'<mrow><mstyle style="{style}"><mo>{esc(beg)}</mo></mstyle>{inner_html}'
                    f'<mstyle style="{style}"><mo>{esc(end)}</mo></mstyle></mrow>')
        return f"<mrow><mo>{esc(beg)}</mo>{inner_html}<mo>{esc(end)}</mo></mrow>"

    if name == "func":
        fname, e = _find(el, "fName"), _find(el, "e")
        return (f"<mrow>{omml_to_mathml(fname)}<mo>&#x2061;</mo>"
                f"{omml_to_mathml(e) if e is not None else ''}</mrow>")

    if name == "nary":
        pr = _find(el, "naryPr")
        chr_ = "∑"
        limloc = None
        if pr is not None:
            c = _find(pr, "chr")
            if c is not None and c.get(f"{{{M}}}val"):
                chr_ = c.get(f"{{{M}}}val")
            ll = _find(pr, "limLoc")
            if ll is not None:
                limloc = ll.get(f"{{{M}}}val")
        sub, sup, e = _find(el, "sub"), _find(el, "sup"), _find(el, "e")
        base = f'<mo class="nary" style="font-size:1.25em">{esc(chr_)}</mo>'
        und = (limloc == "undOvr")
        if sub is not None and sup is not None and und:
            op = f"<munderover>{base}{omml_to_mathml(sub)}{omml_to_mathml(sup)}</munderover>"
        elif sub is not None and sup is not None:
            op = f"<msubsup>{base}{omml_to_mathml(sub)}{omml_to_mathml(sup)}</msubsup>"
        elif sub is not None:
            op = f"<munder>{base}{omml_to_mathml(sub)}</munder>"
        elif sup is not None:
            op = f"<mover>{base}{omml_to_mathml(sup)}</mover>"
        else:
            op = base
        return f"<mrow>{op}{omml_to_mathml(e) if e is not None else ''}</mrow>"

    if name == "acc":
        pr = _find(el, "accPr")
        chr_ = "\u0302"
        if pr is not None:
            c = _find(pr, "chr")
            if c is not None:
                chr_ = c.get(f"{{{M}}}val", chr_)
        e = _find(el, "e")
        mark = {"\u0304": "\u00AF", "\u0305": "\u00AF", "\u0307": ".", "\u0302": "^",
                "\u20d7": "\u2192", "\u0303": "~"}.get(chr_, chr_)
        return (f'<mover accent="true">{omml_to_mathml(e)}'
                f'<mo class="accent">{esc(mark)}</mo></mover>')

    if name == "groupChr":
        pr = _find(el, "groupChrPr")
        chr_ = "\u23DF"   # ⏟
        pos = "bot"
        if pr is not None:
            c, p = _find(pr, "chr"), _find(pr, "pos")
            if c is not None:
                chr_ = c.get(f"{{{M}}}val", chr_)
            if p is not None:
                pos = p.get(f"{{{M}}}val", pos)
        e = _find(el, "e")
        char = "⏟" if chr_ in ("\u23DF", "\u23DE") else chr_
        if pos == "top":
            return f'<mover>{omml_to_mathml(e)}<mo>{esc(char)}</mo></mover>'
        return f'<munder>{omml_to_mathml(e)}<mo>{esc(char)}</mo></munder>'

    if name == "limLow":
        return f"<munder>{omml_to_mathml(_find(el,'e'))}{omml_to_mathml(_find(el,'lim'))}</munder>"
    if name == "limUpp":
        return f"<mover>{omml_to_mathml(_find(el,'e'))}{omml_to_mathml(_find(el,'lim'))}</mover>"

    if name == "eqArr":
        rows = "".join(f"<mtr><mtd>{omml_to_mathml(e)}</mtd></mtr>" for e in _findall(el, "e"))
        return f"<mtable>{rows}</mtable>"

    if name == "m":
        rows = []
        for mr in _findall(el, "mr"):
            cells = "".join(f"<mtd>{omml_to_mathml(c)}</mtd>" for c in _findall(mr, "e"))
            rows.append(f"<mtr>{cells}</mtr>")
        return f"<mtable>{''.join(rows)}</mtable>"

    # عناصر خصائص: تُتجاهل
    if name in ("rPr", "ctrlPr", "fPr", "dPr", "radPr", "sSubPr", "sSupPr", "sSubSupPr",
                "naryPr", "funcPr", "accPr", "groupChrPr", "boxPr", "oMathParaPr", "argPr",
                "limLowPr", "limUppPr", "eqArrPr", "mPr", "mrPr", "sty", "brk", "aln",
                "degHide", "chr", "limLoc", "type", "baseJc"):
        return ""

    # افتراضي: اجمع الأبناء
    return "<mrow>" + "".join(omml_to_mathml(c) for c in _kids(el)) + "</mrow>"


def wrap_math(inner: str, display: bool = False, alttext: str = "") -> str:
    cls = "math-display" if display else "math-inline"
    alt = f' alttext="{attr_esc(alttext)}"' if alttext else ""
    d = ' display="block"' if display else ""
    return f'<math class="{cls}" xmlns="http://www.w3.org/1998/Math/MathML"{d}{alt}>{inner}</math>'
