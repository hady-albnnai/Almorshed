#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/engine_ref.py — محرّك مسائل مرجعيّ **مستقلّ** (نظير Dart بالضبط).

يقرأ app/assets/content/templates.json + expr_eval فقط (لا gen_items)، ويعيد بناء
كامل مسار from_parts (سحب/عرض/سلّم/مفتاح/خيارات/متابعة). الغاية إثبات أن منطق
المحرّك يكفي ذاتياً بالأصل الصغير (177KB)، فيصبح النقل إلى Dart نقلاً آلياً موثوقاً.

يُختبر ضدّ app/test/fixtures/gen_golden.json (المولّدة من المولّد المتحقَّق):
    python3 tools/engine_ref.py            # يشغّل الفحص الذهبيّ
كل دالّة هنا تقابل دالّة في app/lib/core/gen/*.dart بالاسم والسلوك.
"""
from __future__ import annotations

import json
import math
from fractions import Fraction
from pathlib import Path

from expr_eval import ExprError, evaluate

ROOT = Path(__file__).resolve().parents[1]
MINUS = "−"
TOL = 0.02
LINE_POINTS = {"relation": 5, "substitution": 3, "result": 1, "unit": 1}
SUP = str.maketrans("0123456789-", "⁰¹²³⁴⁵⁶⁷⁸⁹⁻")

# الفضاء الاسميّ للتقييم (يطابق _EVAL_NS + الثوابت في gen_items)
NS_FUNCS = {
    "sqrt": math.sqrt, "sin": math.sin, "cos": math.cos, "tan": math.tan,
    "acos": math.acos, "asin": math.asin, "atan": math.atan, "abs": abs,
    "log": math.log, "log10": math.log10, "exp": math.exp, "round": round,
    "min": min, "max": max, "floor": math.floor, "ceil": math.ceil,
    "int": int, "float": float, "radians": math.radians, "degrees": math.degrees,
    "pi": math.pi,
}


# ───────────────────────────── منسّقات (نظائرها في num_format.dart) ─────────────────────────────
def fmt(x, nd=4):
    if isinstance(x, str):
        return x
    if abs(x - round(x)) < 1e-9:
        s = str(int(round(x)))
    else:
        s = f"{x:.{nd}f}".rstrip("0").rstrip(".")
    return s.replace("-", MINUS)


def fmt_sci(x, sig=3):
    if x == 0:
        return "0"
    e = int(math.floor(math.log10(abs(x))))
    m = round(x / 10 ** e, sig - 1)
    if abs(m) >= 10:
        m, e = m / 10, e + 1
    ms = fmt(m)
    if e == 0:
        return ms
    if ms in ("1", "−1"):
        return f"{'−' if m < 0 else ''}10{str(e).translate(SUP)}"
    return f"{ms}×10{str(e).translate(SUP)}"


def nice(x):
    if isinstance(x, str):
        return True
    if not math.isfinite(x):
        return False
    r = round(x, 4)
    if abs(x - r) > 1e-9:
        return False
    digits = f"{abs(r):.4f}".rstrip("0").rstrip(".").replace(".", "").lstrip("0")
    return len(digits) <= 3


def nice_sci(x, sig=3):
    if x == 0 or not math.isfinite(x):
        return False
    e = math.floor(math.log10(abs(x)))
    m = x / 10 ** e
    return abs(m - round(m, sig - 1)) < 1e-9 * max(1, abs(m))


def isqrt_exact(n):
    s = math.isqrt(n)
    return s if s * s == n else None


def sqrt_str(val):
    fr = Fraction(val).limit_denominator(10000)
    p, q = fr.numerator, fr.denominator
    sp, sq = isqrt_exact(p), isqrt_exact(q)
    if sp is not None and sq is not None:
        return fmt(sp / sq)
    if q == 1:
        return f"√{p}"
    if sq is not None:
        return f"√{p}/{sq}"
    return f"√({p}/{q})"


def norm(s):
    import re
    return re.sub(r"\s+", " ", str(s)).strip()


def close(a, b):
    if a is None or b is None:
        return False
    if a == b:
        return True
    return abs(a - b) <= TOL * max(abs(a), abs(b))


# ───────────────────────────── المحرّك ─────────────────────────────
class Engine:
    def __init__(self, asset):
        self.constants = dict(asset.get("constants") or {})
        self.ns_extra = dict(asset.get("namespace") or {})     # g, pi_sq
        self.rules = dict(asset.get("distractorRules") or {})
        self.templates = {t["id"]: t for t in asset["templates"]}

    def _ns(self, env):
        ns = dict(NS_FUNCS)
        ns.update(self.constants)
        ns.update(self.ns_extra)
        ns.update(env)
        return ns

    def _ev(self, expr, env):
        if not isinstance(expr, str):
            return expr
        return evaluate(expr, self._ns(env))

    def _render(self, text, env):
        import re

        def rep(m):
            k, spec = m.group(1), m.group(2)
            if k not in env:
                return m.group(0)
            v = env[k]
            if isinstance(v, bool):
                return str(v)
            if isinstance(v, (int, float)):
                if spec == "sci":
                    return fmt_sci(float(v))
                if spec == "sqrt":
                    return sqrt_str(v)
                if spec == "pi":
                    return _pi_str(v)
                fv = float(v)
                if fv != 0 and math.isfinite(fv):
                    is_int = abs(fv - round(fv)) < 1e-9
                    if abs(fv) < 1e-4 or abs(fv) >= 1e10 or (abs(fv) >= 1e4 and not is_int):
                        return fmt_sci(fv)
                return fmt(v)
            return str(v)
        return re.sub(r"\{([A-Za-z_][A-Za-z0-9_]*)(?::(sci|pi|sqrt))?\}", rep, text)

    def _draw(self, t, base):
        env = {}
        for name, spec in (t.get("vars") or {}).items():
            if name in base:
                env[name] = base[name]
            elif isinstance(spec, dict) and "set" in spec:
                raise ValueError("المحرّك المرجعيّ يتطلّب توليفة set كاملة")
            else:
                env[name] = spec
        for name, expr in (t.get("compute") or {}).items():
            try:
                env[name] = self._ev(expr, env)
            except (ExprError, ValueError, ZeroDivisionError, OverflowError, KeyError):
                return None
        for c in t.get("constraints") or []:
            try:
                if not self._ev(c, env):
                    return None
            except (ExprError, ValueError, ZeroDivisionError, OverflowError, KeyError):
                return None
        return env

    def _part_key(self, p, penv):
        ans = p.get("answer") or {}
        unit = self._render(p.get("unit", ""), penv)
        if p.get("text"):
            val = None
            if p.get("value"):
                try:
                    v = self._ev(p["value"], penv)
                except (ExprError, ValueError, ZeroDivisionError, OverflowError, KeyError, TypeError):
                    return None
                if not isinstance(v, (int, float)) or isinstance(v, bool) or not math.isfinite(v):
                    return None
                val = float(v)
            return self._render(p["text"], penv), val, unit
        try:
            val = self._ev(p["value"], penv)
        except (ExprError, ValueError, ZeroDivisionError, OverflowError, KeyError, TypeError):
            return None
        if not isinstance(val, (int, float)) or isinstance(val, bool) or not math.isfinite(val):
            return None
        sig, mode = ans.get("sig", 3), ans.get("format", "auto")
        sci = mode == "sci" or (mode == "auto" and (abs(val) >= 1e4 or 0 < abs(val) < 1e-2))
        if ans.get("round") and val != 0:
            val = float(f"{val:.{sig - 1}e}")
        if sci:
            if not nice_sci(val, sig):
                return None
            return f"{fmt_sci(val, sig)} {unit}".strip(), float(val), unit
        if not nice(val):
            return None
        return f"{fmt(val)} {unit}".strip(), float(val), unit

    def _part_rubric(self, lines, label, key_text):
        out, total = [], 0
        for ln in lines:
            pts = dict(LINE_POINTS)
            pts.update(ln.get("points") or {})
            relation = ln.get("relation")
            if relation:
                out.append({"step": f"{label} · العلاقة: {relation}", "points": pts["relation"], "kind": "relation"})
                total += pts["relation"]
            if ln.get("subst"):
                out.append({"step": f"{label} · التعويض: {ln['subst']}", "points": pts["substitution"], "kind": "substitution"})
                total += pts["substitution"]
            if ln.get("result", True):
                out.append({"step": f"{label} · النتيجة: {ln.get('result') or key_text or 'القيمة الصحيحة'}",
                            "points": pts["result"], "kind": "result"})
                total += pts["result"]
            if ln.get("unit", True) and relation:
                out.append({"step": f"{label} · الوحدة", "points": pts["unit"], "kind": "unit"})
                total += pts["unit"]
        return out, total

    def _part_options(self, p, penv, key_text, key_val):
        ds = []
        for d in p.get("distractors") or []:
            rule = d.get("rule")
            if rule not in self.rules:
                raise ValueError(f"قاعدة مشتت غير موثّقة: {rule}")
            if "text" in d:
                ds.append((self._render(d["text"], penv), None))
                continue
            try:
                v = float(self._ev(d["value"], penv))
            except (ExprError, ValueError, ZeroDivisionError, OverflowError, KeyError, TypeError):
                continue
            if not math.isfinite(v):
                continue
            txt = self._render(d.get("value_format", "{v}"), {**penv, "v": v})
            if key_val is None:
                ds.append((txt, None))
            else:
                if not nice(v) and not d.get("allow_rough"):
                    continue
                ds.append((txt, v))
        chosen, seen, vals = [], {norm(key_text)}, [key_val]
        for txt, val in ds:
            if norm(txt) in seen:
                continue
            if val is not None and any(close(val, x) for x in vals if x is not None):
                continue
            seen.add(norm(txt))
            vals.append(val)
            chosen.append(txt)
            if len(chosen) == 3:
                break
        if len(chosen) < 3:
            return []
        return [key_text] + chosen

    def from_parts(self, t, base):
        env = self._draw(t, base)
        if env is None:
            return None
        stem = self._render(t["stem"], env)
        labels = ["١", "٢", "٣", "٤", "٥", "٦", "٧"]
        parts, weight, penv = [], 0, dict(env)
        for i, p in enumerate(t["parts"]):
            label = str(p.get("label") or labels[i])
            for k, e in (p.get("compute") or {}).items():
                try:
                    penv[k] = self._ev(e, penv)
                except (ExprError, ValueError, ZeroDivisionError, OverflowError, KeyError, TypeError):
                    return None
            got = self._part_key(p, penv)
            if got is None:
                return None
            key_text, key_val, unit = got
            lines = []
            for ln in p.get("lines") or []:
                lines.append({k: (self._render(v, penv) if isinstance(v, str)
                                  else [self._render(x, penv) for x in v] if isinstance(v, list)
                                  else v) for k, v in ln.items()})
            rb, w = self._part_rubric(lines, f"الجزء {label}", key_text)
            if not rb:
                return None
            options = self._part_options(p, penv, key_text, key_val)
            if key_val is None and not options:
                return None
            ans = p.get("answer") or {}
            parts.append({
                "n": i + 1, "label": label,
                "prompt": self._render(p.get("ask") or "", penv),
                "weight": w, "rubric": rb, "options": options,
                "answer": {"value": key_val, "unit": unit, "text": key_text,
                           "unitRequired": bool(ans.get("unit_required", True))},
                "_follow_raw": p.get("follow"),
            })
            weight += w
        # متابعة الخطأ
        follow_through = []
        for p in parts:
            fl = p["_follow_raw"]
            if not fl:
                continue
            dep = next((q for q in parts if str(q["label"]) == str(fl.get("depends_on"))
                        or q["n"] == fl.get("depends_on")), None)
            if dep is None or dep["answer"]["value"] is None or p["answer"]["value"] is None:
                return None
            acc, dbase = [], float(dep["answer"]["value"])
            for spec in ([fl] if "power" in fl else [fl] + list(fl.get("also") or [])):
                power = float(spec["power"])
                v = float(spec.get("value", p["answer"]["value"]))
                if dbase <= 0 and power != int(power):
                    return None
                try:
                    scale = v / (dbase ** power)
                except (ZeroDivisionError, OverflowError, ValueError):
                    return None
                if not math.isfinite(scale) or scale == 0:
                    return None
                acc.append({"dependsOn": dep["label"], "power": power, "scale": scale})
            if not acc:
                return None
            follow_through.append({"part": p["label"], "accept": acc})
        for p in parts:
            del p["_follow_raw"]
        return {"stem": stem, "weight": weight, "parts": parts, "followThrough": follow_through}


def _pi_str(c):
    fr = Fraction(c).limit_denominator(1000)
    sign = MINUS if fr < 0 else ""
    fr = abs(fr)
    if fr == 0:
        return "0"
    if fr == 1:
        return sign + "π"
    if fr.denominator == 1:
        return f"{sign}{fr.numerator}π"
    if fr.numerator == 1:
        return f"{sign}π/{fr.denominator}"
    return f"{sign}{fr.numerator}π/{fr.denominator}"


# ───────────────────────────── الفحص الذهبيّ ─────────────────────────────
def canon(item):
    return {
        "stem": item["stem"],
        "weight": item["weight"],
        "parts": [{
            "label": p["label"], "prompt": p["prompt"], "weight": p["weight"],
            "answerText": p["answer"]["text"], "answerValue": p["answer"]["value"],
            "answerUnit": p["answer"]["unit"], "unitRequired": p["answer"]["unitRequired"],
            "rubric": p["rubric"],
            "optionSet": sorted(p["options"]) if p["options"] else [],
            "correctText": (p["answer"]["text"] if p["options"] else None),
        } for p in item["parts"]],
        "followThrough": item["followThrough"],
    }


def _num_eq(a, b):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) <= 1e-9 * max(1, abs(a), abs(b))
    return a == b


def deep_eq(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            return f"{path}: مفاتيح مختلفة {set(a) ^ set(b)}"
        for k in a:
            r = deep_eq(a[k], b[k], f"{path}.{k}")
            if r:
                return r
        return None
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return f"{path}: أطوال {len(a)}≠{len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            r = deep_eq(x, y, f"{path}[{i}]")
            if r:
                return r
        return None
    if _num_eq(a, b):
        return None
    return f"{path}: {a!r} ≠ {b!r}"


def main():
    asset = json.load(open(ROOT / "app/assets/content/templates.json", encoding="utf-8"))
    gold = json.load(open(ROOT / "app/test/fixtures/gen_golden.json", encoding="utf-8"))
    eng = Engine(asset)
    ok = miss = 0
    errs = []
    for fx in gold["fixtures"]:
        t = eng.templates[fx["templateId"]]
        got = eng.from_parts(t, fx["vars"])
        if fx["reject"]:
            if got is None:
                ok += 1
            else:
                miss += 1
                errs.append((fx["templateId"], fx["vars"], "توقّعت رفضاً فأنتج"))
            continue
        if got is None:
            miss += 1
            errs.append((fx["templateId"], fx["vars"], "توقّعت إنتاجاً فرفض"))
            continue
        diff = deep_eq(canon(got), fx["item"])
        if diff:
            miss += 1
            errs.append((fx["templateId"], fx["vars"], diff))
        else:
            ok += 1
    print(f"الفحص الذهبيّ (Python المرجعيّ): مطابق {ok} · مختلف {miss} / {len(gold['fixtures'])}")
    for e in errs[:20]:
        print("  ✗", e)
    return 0 if miss == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
