#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/gen_items.py — المادة ١٠: مولّد البنود من قوالب content/authoring/templates/U1.yaml

المبادئ (docs/14 §ب–§د · docs/22 §٤ البند ١٠):
  • الإجابة تُحسب بالكود؛ المشتتات من قواعد الأخطاء الموثّقة فقط (schema.distractor_rules)
    ولكل خيار مسوّغ يظهر في solutionSteps.
  • تحقق آلي: حل وحيد، أرقام نظيفة، لا خيارين متطابقين، لا مشتت ضمن ±٢٪ من المفتاح،
    لا مصطلح محظور (glossary.banned)، لا قاعدة مشتت خارج الفهرس.
  • لا ذكاء اصطناعي في وقت التشغيل: المخرجات JSON ثابتة قابلة للتكرار بالبذرة.
  • approved: false دائماً — الاعتماد للأستاذ فداء البني.
  • القوالب التي تحتاج شكلاً (needs_figure) أو حلاً غير مبرمج بعد تُذكر في التقرير ولا تُولَّد.

الاستخدام:
  python3 tools/gen_items.py                       # مجمّع كامل + عيّنة ١٠٠ في content/generated/
  python3 tools/gen_items.py --seed 7 --n 100 --per-template 8
  python3 tools/gen_items.py --pack                # يدمج العيّنة في app/assets/content/pack.json تحت "items"
"""
from __future__ import annotations

import argparse
import json
import math
import random
import re
import sys
from fractions import Fraction
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML مطلوب: pip install pyyaml")

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / "content/authoring/templates/U1.yaml"
GLOSSARY = ROOT / "app/assets/content/glossary.json"
PACK = ROOT / "app/assets/content/pack.json"
OUT_DIR = ROOT / "content/generated"

G, PI2 = 10, 10                         # ثوابت الامتحان (تُقرأ من constants في YAML عند التشغيل)
CHAPTER_WEIGHTS = {"U1C1": 80, "U1C2": 60, "U1C3": 50}   # أوزان دورة ٢٠٢٥ (docs/23)
TOL = 0.02
MINUS = "−"
FIRST_ID = 20001
COS = {0: 1.0, 37: 0.8, 60: 0.5, 90: 0.0}
SIN = {0: 0.0, 37: 0.6, 60: math.sqrt(3) / 2, 90: 1.0}
# صفوف جداول معلّقة بقرار review_queue (لا تُولَّد حتى يبتّ الأستاذ)
ROW_SKIP = {"U1.L2.T03": {"C_wire"}}
MULT = {0.25: "ربع", 0.5: "نصف", 0.75: "ثلاثة أرباع", 2: "ضعف", 3: "ثلاثة أمثال",
        4: "أربعة أمثال", 5: "خمسة أمثال", 6: "ستة أمثال"}


# ───────────────────────────── أدوات تنسيق وأرقام ─────────────────────────────
def fmt(x, nd: int = 4) -> str:
    """تنسيق عدد بلا أصفار زائدة وبإشارة سالبة مطبعية (−)."""
    if isinstance(x, str):
        return x
    if isinstance(x, Fraction):
        x = float(x)
    if abs(x - round(x)) < 1e-9:
        s = str(int(round(x)))
    else:
        s = f"{x:.{nd}f}".rstrip("0").rstrip(".")
    return s.replace("-", MINUS)


def sig3(x: float) -> float:
    """تقريب مشتت إلى ٣ أرقام معنوية (شكل امتحاني)."""
    if x == 0 or not math.isfinite(x):
        return x
    return round(x, 2 - int(math.floor(math.log10(abs(x)))))


def hazza(n: int) -> str:
    return "هزات" if 3 <= n <= 10 else "هزة"


def nice(x) -> bool:
    """عدد «نظيف»: ≤ ٤ منازل عشرية و≤ ٣ أرقام معنوية (قابل للحساب يدوياً في الامتحان)."""
    if isinstance(x, str):
        return True
    if isinstance(x, Fraction):
        x = float(x)
    if not math.isfinite(x):
        return False
    r = round(x, 4)
    if abs(x - r) > 1e-9:
        return False
    digits = f"{abs(r):.4f}".rstrip("0").rstrip(".").replace(".", "").lstrip("0")
    return len(digits) <= 3


def isqrt_exact(n: int):
    s = math.isqrt(n)
    return s if s * s == n else None


def sqrt_str(val) -> str:
    """√val كنص: عدد نظيف إن كان جذراً تاماً وإلا √p أو √p/q أو √(p/q)."""
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


def ratio_str(r: float, sym: str) -> str:
    """r·sym بصيغة امتحانية: 2·T0 · T0/2 · √2·T0 · T0/√2 · √3·T0/2 · √(2/3)·T0."""
    fr = Fraction(r * r).limit_denominator(10000)
    p, q = fr.numerator, fr.denominator
    sp, sq = isqrt_exact(p), isqrt_exact(q)
    if sp is not None and sq is not None:
        if sq == 1:
            return sym if sp == 1 else f"{sp}·{sym}"
        return f"{sym}/{sq}" if sp == 1 else f"{sp}·{sym}/{sq}"
    if q == 1:
        return f"√{p}·{sym}"
    if sp == 1:
        return f"{sym}/√{q}"
    if sq is not None:
        return f"√{p}·{sym}/{sq}"
    return f"√({p}/{q})·{sym}"


def pi_str(c) -> str:
    """c·π كنص: π · 2π · π/2 · 3π/4."""
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


def phase_txt(ph: str) -> str:
    """نص الطور داخل cos(ω0·t …)."""
    if ph in ("0", ""):
        return ""
    if ph.startswith(MINUS) or ph.startswith("-"):
        return f" {MINUS} {ph[1:]}"
    if ph.startswith("+"):
        return f" + {ph[1:]}"
    return f" + {ph}"


def neg_phase(ph: str) -> str:
    if ph == "0":
        return "π"
    if ph == "π":
        return "0"
    if ph.startswith("+"):
        return MINUS + ph[1:]
    if ph.startswith(MINUS):
        return "+" + ph[1:]
    return MINUS + ph


def mult_words(f) -> str:
    return MULT.get(f, f"{fmt(f)} من")


def norm(s) -> str:
    return re.sub(r"\s+", " ", str(s)).strip()


def close(a, b) -> bool:
    if a is None or b is None:
        return False
    if a == b:
        return True
    return abs(a - b) <= TOL * max(abs(a), abs(b))


def split_all_of_above(key: str):
    """«جميع ما سبق صحيح (A · B · C)» ⇒ [A, B, C]."""
    m = re.search(r"\((.*)\)\s*$", key)
    if not m:
        return []
    inner = m.group(1)
    parts = [p.strip() for p in (inner.split(" · ") if " · " in inner else inner.split("، "))]
    return [p for p in parts if p]


# ───────────────────────────── مشتتات الصيغ الرمزية ─────────────────────────────
SIGN_LHS = {"F", "a", "at", "Γ_w", "Γ_η/Δ", "θ″", "x″", "x‴"}


def formula_transforms(key: str):
    """تحويلات نصية توافق قواعد الأخطاء الموثّقة؛ تُعيد [(نص, قاعدة, مسوّغ)]."""
    out = []

    def add(rule, s, why):
        if s and s != key and (s, rule) not in [(o[0], o[1]) for o in out]:
            out.append((s, rule, why))

    lhs = key.split("=", 1)[0].strip() if "=" in key else ""
    if MINUS in key:
        add("sign_flip", key.replace(MINUS, "", 1).replace("=  ", "= "), "حذف الإشارة السالبة (إشارة الإرجاع)")
    elif lhs in SIGN_LHS or "sin θ" in key:
        l, r = key.split("=", 1)
        add("sign_flip", f"{l.strip()} = {MINUS}{r.strip()}", "إشارة سالبة في غير موضعها")
    if "²" in key:
        add("forget_square", key.replace("²", "", 1), "أهمل التربيع")
    m = re.search(r"√\(([^()/]+)/([^()]+)\)", key)
    if m:
        add("invert_ratio", key[: m.start()] + f"√({m.group(2)}/{m.group(1)})" + key[m.end():], "قلب النسبة تحت الجذر")
    else:
        m = re.search(r"\(([^()/]+)/([^()]+)\)", key)
        if m:
            add("invert_ratio", key[: m.start()] + f"({m.group(2)}/{m.group(1)})" + key[m.end():], "قلب النسبة")
    if "2π·" in key:
        add("forget_2pi", key.replace("2π·", "", 1), "أهمل 2π")
    if "½·" in key:
        add("forget_half", key.replace("½·", "", 1), "أهمل ½")
    if "sin" in key:
        add("sin_cos", key.replace("sin", "cos"), "cos مكان sin")
    elif "cos" in key:
        add("sin_cos", key.replace("cos", "sin"), "sin مكان cos")
    if "√" in key:
        add("forget_sqrt", key.replace("√", "", 1), "أهمل الجذر التربيعي")
    return out


# ───────────────────────────── المولّد ─────────────────────────────
SOLVERS = {}


def solver(*ids):
    def deco(fn):
        for i in ids:
            SOLVERS[i] = fn
        return fn
    return deco


def pick(rng, spec):
    return rng.choice(spec["set"] if isinstance(spec, dict) else spec)


class Generator:
    def __init__(self, doc: dict, banned, seed: int):
        self.doc = doc
        self.rules = dict(doc["schema"]["distractor_rules"])
        self.banned = [b for b in banned if b]
        self.rng = random.Random(seed)
        self.seed = seed
        self.next_id = FIRST_ID
        self.by_id = {t["id"]: t for t in doc["templates"]}
        self.report = {"skipped": [], "short": 0, "banned_hits": [], "per_template": {}}
        consts = doc.get("constants") or {}
        global G, PI2
        G, PI2 = consts.get("g", G), consts.get("pi_sq", PI2)

    # ── بناء بند ──
    def make(self, t, stem, key, ds, *, answer=None, fixed_last=False, extra=None):
        """key: نص المفتاح · ds: [(نص, قاعدة, مسوّغ[, قيمة])] · answer: {value, unit} للرقمي."""
        kv = answer["value"] if answer else None
        chosen, seen, vals = [], {norm(key)}, [kv]
        for d in ds:
            txt, rule, rat = d[0], d[1], d[2]
            val = d[3] if len(d) > 3 else None
            if rule not in self.rules:
                raise ValueError(f"{t['id']}: قاعدة مشتت غير موثّقة: {rule}")
            if norm(txt) in seen:
                continue
            if val is not None and (not math.isfinite(val) or any(close(val, v) for v in vals if v is not None)):
                continue
            seen.add(norm(txt))
            vals.append(val)
            chosen.append((txt, rule, rat, val))
            if len(chosen) == 3:
                break
        if len(chosen) < 3:
            self.report["short"] += 1
            return None
        opts = chosen + [(key, None, None, kv)] if fixed_last else [(key, None, None, kv)] + chosen
        if not fixed_last:
            self.rng.shuffle(opts)
        options = [o[0] for o in opts]
        ci = options.index(key)
        text = " ".join([stem] + options)
        hits = [b for b in self.banned if b in text]
        if hits:
            self.report["banned_hits"].append((t["id"], hits))
            return None
        steps = []
        for i, (txt, rule, rat, _) in enumerate(opts):
            letter = "ABCD"[i]
            if rule is None:
                steps.append(f"✓ ({letter}) {txt}")
            else:
                steps.append(f"({letter}) خطأ [{rule}]: {rat or self.rules.get(rule, '')}")
        item = {
            "id": self.new_id(),
            "templateId": t["id"],
            "unit": "U1",
            "chapter": t["chapter"],
            "type": t["type"],
            "difficulty": t.get("difficulty", 1),
            "weight": t.get("weight", 10),
            "approved": False,
            "stem": stem,
            "options": options,
            "correctIndex": ci,
            "optionRules": [o[1] for o in opts],
            "optionValues": [o[3] for o in opts],
            "solutionSteps": steps,
            "followThrough": [],
            "answer": ({"value": kv, "unit": answer.get("unit", ""), "tolerance": TOL} if answer else None),
            "rubric": t.get("rubric"),
            "answerBasis": t.get("answer_basis"),
            "source": t.get("source"),
        }
        if extra:
            item.update(extra)
        return item

    def numeric(self, t, stem, val, unit, ds, *, prefix=""):
        """بند رقمي: المفتاح والمشتتات قيم تُنسَّق بالوحدة نفسها."""
        if not nice(val):
            return None
        key = f"{prefix}{fmt(val)} {unit}".strip()
        dd = [(f"{prefix}{fmt(sig3(v))} {unit}".strip(), rule, rat, float(v)) for v, rule, rat in ds]
        return self.make(t, stem, key, dd, answer={"value": float(val), "unit": unit})

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    # ── المسارات العامة ──
    def from_variants(self, t):
        items = []
        for v in t["variants"]:
            if t["type"] == "why":
                ds = [(d, "true_but_partial", "تعليل شائع لكنه لا يجيب عن السبب الفيزيائي") for d in v["mcq_distractors"]]
                it = self.make(t, v["stem"], v["mcq_key"], ds,
                               extra={"keys": v.get("keys", []), "antiKeys": v.get("anti_keys", [])})
            else:
                key = v["key"]
                if key.startswith("جميع ما سبق"):
                    ds = [(re.sub(r"\s+فقط$", "", d["text"]), d.get("rule", "true_but_partial"), d.get("rationale") or "صحيحة لكنها ليست الوحيدة")
                          for d in v["distractors"]]
                    it = self.make(t, v["stem"], "جميع ما سبق صحيح", ds, fixed_last=True,
                                   extra={"keyFull": key})
                else:
                    lhs = key.split("=", 1)[0].strip() + " = " if re.match(r"^[^ ]{1,8} = ", key) else ""
                    ds = [((lhs + d["text"]) if lhs and "=" not in d["text"] and not d["text"].startswith("جميع") else d["text"],
                           d["rule"], d.get("rationale")) for d in v["distractors"]]
                    it = self.make(t, v["stem"], key, ds)
            if it:
                items.append(it)
        return items

    def from_table(self, t):
        items, rows = [], t["table"]
        opts = t.get("options") or {}
        skip = ROW_SKIP.get(t["id"], set())
        for q, row in rows.items():
            if q in skip or not isinstance(row, dict):
                continue
            stem = t["stem"]
            for k, v in row.items():
                if isinstance(v, str):
                    stem = stem.replace("{table[q].%s}" % k, v)
            key = row.get("key")
            if key is None:
                continue
            if "distractors_from" in opts:
                ds = [(w, "unit_confusion", "واحدة مقدار آخر أو تركيب خاطئ للواحدات") for w in row.get("wrong", [])]
                it = self.make(t, stem, key, ds)
            elif key.startswith("جميع ما سبق"):
                parts = split_all_of_above(key)
                if len(parts) != 3:
                    continue
                ds = [(p, "true_but_partial", "صحيحة لكنها ليست الوحيدة") for p in parts]
                it = self.make(t, stem, "جميع ما سبق صحيح", ds, fixed_last=True, extra={"keyFull": key})
            else:
                ds = formula_transforms(key)
                others = [r["key"] for k2, r in rows.items()
                          if k2 != q and isinstance(r, dict) and r.get("key") and not r["key"].startswith("جميع ما سبق")]
                self.rng.shuffle(others)
                ds += [(o, "mix_formulas", "علاقة صحيحة لمقدار آخر من الدرس نفسه") for o in others]
                it = self.make(t, stem, key, ds)
            if it:
                items.append(it)
        return items

    def from_proof(self, t):
        steps = t.get("steps")
        base = self.by_id.get(t.get("inherits", ""))
        if steps is None and base is not None:
            sm = t.get("symbol_map") or {}
            def sub(s):
                for a, b in sorted(sm.items(), key=lambda kv: -len(kv[0])):
                    s = re.sub(rf"(?<![\w′″]){re.escape(a)}(?![\w])", b, s)
                return s
            steps = [dict(s, text=sub(s["text"])) for s in base["steps"]]
            extra = {e["n"]: e for e in t.get("extra_steps", [])}
            steps = [extra.get(s["n"], s) for s in steps]
            if 0 in extra:
                steps = [extra[0]] + steps
        if not steps:
            return None
        stem = t.get("stem") or t["title"]
        return {
            "id": self.new_id(), "templateId": t["id"], "unit": "U1", "chapter": t["chapter"],
            "type": "proof", "difficulty": t.get("difficulty", 3), "weight": t.get("weight", 25),
            "approved": False, "stem": stem, "options": [], "correctIndex": -1,
            "steps": steps, "stepDistractors": t.get("step_distractors", []),
            "altRoute": t.get("alt_route"), "totalPoints": sum(s.get("points", 0) for s in steps),
            "solutionSteps": [f"{s['n']}. {s['text']} ({s.get('points', 0)})" for s in steps],
            "followThrough": [], "answer": None, "answerBasis": t.get("answer_basis"), "source": t.get("source"),
        }

    # ── التشغيل ──
    def run_template(self, t, per_template):
        tid = t["id"]
        if t.get("needs_figure"):
            self.report["skipped"].append((tid, "needs_figure"))
            return []
        if t["type"] == "proof":
            it = self.from_proof(t)
            return [it] if it else []
        if "variants" in t:
            return self.from_variants(t)
        if tid in SOLVERS:
            out, seen, tries = [], set(), 0
            while len(out) < per_template and tries < per_template * 40:
                tries += 1
                it = SOLVERS[tid](self, t)
                if it and norm(it["stem"]) + "|" + it["options"][it["correctIndex"]] not in seen:
                    seen.add(norm(it["stem"]) + "|" + it["options"][it["correctIndex"]])
                    out.append(it)
            return out
        if "table" in t and isinstance(t.get("stem"), str):
            return self.from_table(t)
        self.report["skipped"].append((tid, "no_solver"))
        return []

    def generate(self, per_template=6):
        pool = []
        for t in self.doc["templates"]:
            items = self.run_template(t, per_template)
            self.report["per_template"][t["id"]] = len(items)
            pool.extend(items)
        return pool


# ───────────────────────────── الحلّالات الرقمية/الرمزية ─────────────────────────────
@solver("U1.L1.T08")
def s_l1_t08(g, t):
    rng, v = g.rng, t["vars"]
    fm, fk, fx, ask = pick(rng, v["fm"]), pick(rng, v["fk"]), pick(rng, v["fx"]), pick(rng, v["ask"])
    stem = t["stem"].format(fm=fmt(fm), fk=fmt(fk), fx=fmt(fx), ask=ask)
    if fm == fk:                                  # لا يتغير إلا السعة ⇒ الدور ثابت
        if fx == 1:
            return None
        key = ask
        ds = [(ratio_str(math.sqrt(fx), ask), "amplitude_dependence", "ظنّ T0 ∝ √XmaX"),
              (ratio_str(fx, ask), "amplitude_dependence", "ظنّ T0 ∝ XmaX"),
              (ratio_str(1 / math.sqrt(fx), ask), "amplitude_dependence", "ظنّ T0 ∝ 1/√XmaX")]
        return g.make(t, stem, key, ds)
    r = math.sqrt(fm / fk) if ask == "T0" else math.sqrt(fk / fm)
    ds = [(ratio_str(r * r, ask), "forget_sqrt", "أهمل الجذر التربيعي"),
          (ratio_str(1 / r, ask), "invert_ratio", "قلب النسبة (خلط T0 مع ω0)"),
          (ratio_str(r * (math.sqrt(fx) if fx != 1 else 2), ask), "amplitude_dependence", "ظنّ أن السعة تؤثر في الدور")]
    return g.make(t, stem, ratio_str(r, ask), ds)


@solver("U1.L1.T09")
def s_l1_t09(g, t):
    rng, v = g.rng, t["vars"]
    n, dt, ask = pick(rng, v["n"]), pick(rng, v["dt"]), pick(rng, v["ask"])
    T0, f = dt / n, n / dt
    if not nice(T0):
        return None
    head = "نواس مرن غير متخامد"
    if ask == "n_from_T0":
        stem = f"{head} دوره الخاص T0 = {fmt(T0)} s. عدد الهزات الكاملة التي ينجزها خلال {dt} s:"
        ds = [(dt * T0, "invert_ratio", "ضرب الزمن بالدور بدل قسمته عليه"),
              (n + 1, "off_by_one", "خطأ بواحدة في العدّ"),
              (2 * n, "forget_half", "عدّ الذهاب وحده هزة (نصف هزة)")]
        return g.numeric(t, stem, n, "هزة", ds)
    if ask == "t_from_n_T0":
        stem = f"{head} دوره الخاص T0 = {fmt(T0)} s. الزمن اللازم لإنجاز {n} {hazza(n)} كاملة:"
        ds = [(n / T0, "invert_ratio", "قسم العدد على الدور بدل الضرب"),
              ((n + 1) * T0, "off_by_one", "خطأ بواحدة في العدّ"),
              (n * T0 / 2, "forget_half", "استعمل نصف الدور (ذهاب فقط)")]
        return g.numeric(t, stem, dt, "s", ds)
    stem = t["stem"].replace("{n} هزة", f"{n} {hazza(n)}").replace("{dt}", str(dt))
    if ask == "T0":
        ds = [(f, "invert_ratio", "قلب الدور والتواتر"), (dt / (n + 1), "off_by_one", "خطأ بواحدة في العدّ"),
              (T0 / 2, "forget_half", "حسب زمن نصف الهزة")]
        return g.numeric(t, stem.replace("{ask}", "الدور الخاص T0"), T0, "s", ds)
    if ask == "f":
        ds = [(T0, "invert_ratio", "قلب الدور والتواتر"), ((n + 1) / dt, "off_by_one", "خطأ بواحدة في العدّ"),
              (2 * math.pi * f, "mix_formulas", "خلط التواتر بالنبض (2πf)")]
        return g.numeric(t, stem.replace("{ask}", "التواتر f"), f, "Hz", ds)
    c = Fraction(2 * n, dt)                          # ω0 = c·π
    key = f"{pi_str(c)} rad·s⁻¹"
    ds = [(f"{fmt(f)} rad·s⁻¹", "forget_2pi", "ω0 = 2πf لا f", f),
          (f"{pi_str(2 * Fraction(dt, n))} rad·s⁻¹", "invert_ratio", "ω0 = 2π/T0 لا 2πT0", float(2 * math.pi * T0)),
          (f"{pi_str(c / 2)} rad·s⁻¹", "forget_half", "ω0 = πf بدل 2πf", float(c / 2) * math.pi)]
    return g.make(t, stem.replace("{ask}", "النبض الخاص ω0"), key, ds, answer={"value": float(c) * math.pi, "unit": "rad·s⁻¹"})


@solver("U1.L1.T10", "U1.L2.T07")
def s_period_mk(g, t):
    tors = t["id"].startswith("U1.L2")
    mkey, kkey = ("I", "C") if tors else ("m", "k")
    rng, v = g.rng, t["vars"]
    m, k, T0, ask = pick(rng, v[mkey]), pick(rng, v[kkey]), pick(rng, v["T0"]), pick(rng, v["ask"])
    mname, munit = ("عزم عطالته IΔ", "kg·m²") if tors else ("كتلة جسمه m", "kg")
    kname, kunit = ("ثابت فتل سلكه C", "N·m·rad⁻¹") if tors else ("ثابت صلابة نابضه k", "N·m⁻¹")
    if ask == kkey:
        val, unit, askt = 4 * PI2 * m / T0 ** 2, kunit, kname
        given = f"{mname} = {fmt(m)} {munit} ودوره الخاص T0 = {fmt(T0)} s"
        ds = [(4 * PI2 * m / T0, "forget_square", "نسي تربيع T0"), (m / T0 ** 2, "forget_4pi2", "نسي 4π²"),
              (T0 ** 2 / (4 * PI2 * m), "invert_ratio", "قلب العلاقة")]
    elif ask == mkey:
        val, unit, askt = k * T0 ** 2 / (4 * PI2), munit, mname
        given = f"{kname} = {fmt(k)} {kunit} ودوره الخاص T0 = {fmt(T0)} s"
        ds = [(k * T0 / (4 * PI2), "forget_square", "نسي تربيع T0"), (k * T0 ** 2, "forget_4pi2", "نسي 4π²"),
              (4 * PI2 / (k * T0 ** 2), "invert_ratio", "قلب العلاقة")]
    else:
        val, unit, askt = 2 * math.sqrt(PI2 * m / k), "s", "دوره الخاص T0"
        given = f"{mname} = {fmt(m)} {munit} و{kname} = {fmt(k)} {kunit}"
        ds = [(2 * math.sqrt(PI2) * m / k, "forget_sqrt", "أهمل الجذر التربيعي"),
              (2 * math.sqrt(PI2 * k / m), "invert_ratio", f"{kkey}/{mkey} بدل {mkey}/{kkey}"),
              (math.sqrt(m / k), "forget_2pi", "أهمل 2π")]
    stem = t["stem"].replace("{given}", given).replace("{ask}", askt)
    return g.numeric(t, stem, val, unit, ds)


@solver("U1.L1.T11")
def s_l1_t11(g, t):
    rng, v = g.rng, t["vars"]
    k, xcm, T0, ask = pick(rng, v["k"]), pick(rng, v["x_cm"]), pick(rng, v["T0"]), pick(rng, v["ask"])
    x, om2 = xcm / 100, 4 * PI2 / T0 ** 2
    given = f"ثابت صلابة نابضه k = {fmt(k)} N·m⁻¹ ودوره الخاص T0 = {fmt(T0)} s"
    if ask == "F":
        val, unit, askt = -k * x, "N", "قوة الإرجاع F"
        ds = [(k * x, "sign_flip", "أهمل الإشارة السالبة لقوة الإرجاع"), (-k * xcm, "unit_cm_m", "ترك المطال بالسنتيمتر"),
              (-om2 * x, "mix_v_a", "حسب التسارع بدل القوة")]
    else:
        val, unit, askt = -om2 * x, "m·s⁻²", "التسارع a"
        ds = [(om2 * x, "sign_flip", "أهمل الإشارة السالبة"), (-om2 * xcm, "unit_cm_m", "ترك المطال بالسنتيمتر"),
              (-k * x, "mix_v_a", "حسب القوة بدل التسارع")]
    stem = t["stem"].replace("{given}", given).replace("{ask}", askt).replace("{x_cm}", fmt(xcm))
    return g.numeric(t, stem, val, unit, ds)


@solver("U1.L1.T12")
def s_l1_t12(g, t):
    rng, v = g.rng, t["vars"]
    Xcm, xcm, om, ask = pick(rng, v["XmaX_cm"]), pick(rng, v["x_cm"]), pick(rng, [2, 4, 5, 10]), pick(rng, v["ask"])
    if xcm >= Xcm:
        return None
    X, x = Xcm / 100, xcm / 100
    stem = t["stem"].replace("{omega0}", fmt(om)).replace("{XmaX_cm}", fmt(Xcm))
    if ask == "vmax":
        ds = [(om * Xcm, "unit_cm_m", "ترك السعة بالسنتيمتر"), (om * om * X, "mix_v_a", "حسب التسارع الأعظمي بدل السرعة"),
              (X / om, "invert_ratio", "قسم على النبض بدل الضرب")]
        return g.numeric(t, stem.replace("{ask}", "السرعة العظمى vmax"), om * X, "m·s⁻¹", ds)
    val = om * math.sqrt(X * X - x * x)
    stem = stem.replace("{ask}", f"السرعة في الموضع الذي مطاله x = {fmt(xcm)} cm")
    ds = [(om * X, "mix_max_center", "أعطى السرعة العظمى بدل السرعة عند x"),
          (om * (X - x), "forget_sqrt", "√(XmaX² − x²) ≠ XmaX − x"),
          (om * math.sqrt(Xcm ** 2 - xcm ** 2), "unit_cm_m", "ترك الأطوال بالسنتيمتر")]
    return g.numeric(t, stem, val, "m·s⁻¹", ds, prefix="±")


@solver("U1.L1.T13")
def s_l1_t13(g, t):
    rng, v = g.rng, t["vars"]
    k, Xcm, xcm, ask = pick(rng, v["k"]), pick(rng, v["XmaX_cm"]), pick(rng, v["x_cm"]), pick(rng, v["ask"])
    if xcm >= Xcm:
        return None
    X, x = Xcm / 100, xcm / 100
    E, Ep = 0.5 * k * X * X, 0.5 * k * x * x
    Ek = E - Ep
    if ask == "k_from_E":
        if not nice(E):
            return None
        stem = f"نواس مرن غير متخامد طاقته الميكانيكية E = {fmt(E)} J وسعته {fmt(Xcm)} cm. احسب ثابت صلابة النابض k."
        ds = [(E / X ** 2, "forget_half", "نسي ½ (k = E/XmaX²)"), (2 * E / X, "forget_square", "نسي تربيع السعة"),
              (2 * E / Xcm ** 2, "unit_cm_m", "ترك السعة بالسنتيمتر")]
        return g.numeric(t, stem, k, "N·m⁻¹", ds)
    stem = t["stem"].replace("{k}", fmt(k)).replace("{XmaX_cm}", fmt(Xcm)).replace("{x_cm}", fmt(xcm))
    if ask == "E":
        val, askt = E, "الطاقة الميكانيكية E"
        ds = [(k * X * X, "forget_half", "نسي ½"), (0.5 * k * X, "forget_square", "نسي التربيع"),
              (Ek, "mix_Ep_Ek", "حسب الحركية عند x بدل الكلية")]
    elif ask == "Ep":
        val, askt = Ep, "الطاقة الكامنة المرونية Ep"
        ds = [(k * x * x, "forget_half", "نسي ½"), (Ek, "mix_Ep_Ek", "خلط الكامنة بالحركية"),
              (0.5 * k * xcm ** 2, "unit_cm_m", "ترك المطال بالسنتيمتر")]
    else:
        val, askt = Ek, "الطاقة الحركية Ek"
        ds = [(Ep, "mix_Ep_Ek", "خلط الحركية بالكامنة"), (E, "mix_max_center", "أعطى الطاقة الكلية (كأن x = 0)"),
              (0.5 * k * (X - x) ** 2, "forget_square", "(XmaX − x)² بدل XmaX² − x²")]
    return g.numeric(t, stem.replace("{ask}", askt), val, "J", ds)


def _frac_E(a: int, b: int) -> str:
    return f"E/{b}" if a == 1 else f"{a}·E/{b}"


@solver("U1.L1.T14")
def s_l1_t14(g, t):
    rng, v, S = g.rng, t["vars"], t["stems"]
    mode = pick(rng, v["mode"])
    if mode in ("Ep_at_frac", "Ek_at_frac"):
        n = pick(rng, v["n"])
        n2 = {2: 4, 3: 9, 4: 16, "√2": 2, "√3": 3, "√5": 5}[n]
        stem = S[mode].replace("{n}", str(n))
        if mode == "Ep_at_frac":
            key = f"Ep = {_frac_E(1, n2)}"
            ds = [(f"Ep = E/{n}", "forget_square", "Ep ∝ x² لا x"), (f"Ep = {_frac_E(n2 - 1, n2)}", "mix_Ep_Ek", "هذه Ek"),
                  (f"Ep = {_frac_E(1, 2 * n2)}", "forget_half", "أدخل ½ مرة زائدة")]
        else:
            key = f"Ek = {_frac_E(n2 - 1, n2)}"
            ds = [(f"Ek = {_frac_E(1, n2)}", "mix_Ep_Ek", "هذه Ep"), (f"Ek = ({n} − 1)·E/{n}", "forget_square", "استعمل x لا x²"),
                  (f"Ek = {_frac_E(n2 - 1, 2 * n2)}", "forget_half", "أدخل ½ مرة زائدة")]
        return g.make(t, stem, key, ds)
    if mode == "x_for_equal":
        ds = [("x = ±XmaX/2", "forget_sqrt", "نسي الجذر"), ("x = +XmaX/√2", "forget_pm", "أهمل الموضع المتناظر"),
              ("x = ±√2·XmaX", "invert_ratio", "قلب النسبة")]
        return g.make(t, S[mode], "x = ±XmaX/√2", ds)
    r = pick(rng, v["r"])
    stem = S[mode].replace("{r}", fmt(r))
    if mode == "x_for_Ek_r_Ep":
        k = ratio_str(math.sqrt(1 / (1 + r)), "XmaX")
        ds = [("x = ±" + ratio_str(math.sqrt(r / (1 + r)), "XmaX"), "mix_Ep_Ek", "خلط Ek بـ Ep"),
              (f"x = ±XmaX/{fmt(1 + r)}", "forget_sqrt", "نسي الجذر"), ("x = +" + k, "forget_pm", "أهمل الموضع المتناظر")]
        return g.make(t, stem, "x = ±" + k, ds)
    if r >= 1:
        return None
    if mode == "x_for_Ep_r_E":
        k = ratio_str(math.sqrt(r), "XmaX")
        ds = [("x = ±" + ratio_str(math.sqrt(1 - r), "XmaX"), "mix_Ep_Ek", "حسب موضع Ek = r·E"),
              (f"x = ±{fmt(r)}·XmaX", "forget_sqrt", "نسي الجذر"), ("x = +" + k, "forget_pm", "أهمل الموضع المتناظر")]
        return g.make(t, stem, "x = ±" + k, ds)
    k = ratio_str(math.sqrt(1 - r), "XmaX")
    ds = [("x = ±" + ratio_str(math.sqrt(r), "XmaX"), "mix_Ep_Ek", "حسب موضع Ep = r·E"),
          (f"x = ±{fmt(1 - r)}·XmaX", "forget_sqrt", "نسي الجذر"), ("x = +" + k, "forget_pm", "أهمل الموضع المتناظر")]
    return g.make(t, stem, "x = ±" + k, ds)


@solver("U1.L1.T15")
def s_l1_t15(g, t):
    rng, v = g.rng, t["vars"]
    m, k, T0, ask = pick(rng, v["m"]), pick(rng, v["k"]), pick(rng, v["T0"]), pick(rng, v["ask"])
    mk = f"كتلة جسمه m = {fmt(m)} kg وثابت صلابة نابضه k = {fmt(k)} N·m⁻¹"
    if ask == "x0_from_mk":
        val, unit, given, askt = m * G / k, "m", mk, "استطالة النابض في وضع التوازن x0"
        ds = [(k / (m * G), "invert_ratio", "قلب العلاقة"), (m / k, "mix_formulas", "x0 = m/k (نسي g)"),
              (m * 1000 * G / k, "unit_g_kg", "ترك الكتلة بالغرام")]
    elif ask == "x0_from_T0":
        val, unit, given, askt = G * T0 ** 2 / (4 * PI2), "m", f"دوره الخاص T0 = {fmt(T0)} s", "استطالة النابض في وضع التوازن x0"
        ds = [(G * T0 / (4 * PI2), "forget_square", "نسي تربيع T0"), (4 * PI2 / (G * T0 ** 2), "invert_ratio", "قلب العلاقة"),
              (G * T0 ** 2, "forget_4pi2", "نسي 4π²")]
    else:
        val, unit, given, askt = m * G, "N", mk, "شدة قوة توتر النابض في وضع التوازن Fs0"
        ds = [(m * G * 1000, "unit_g_kg", "ترك الكتلة بالغرام"), (k * m, "mix_formulas", "Fs0 = k·m"),
              (k * m * G, "mix_formulas", "ضرب في k زيادة (Fs0 = k·x0 = m·g)")]
    stem = t["stem"].replace("{given}", given).replace("{ask}", askt)
    return g.numeric(t, stem, val, unit, ds)


@solver("U1.L1.T16")
def s_l1_t16(g, t):
    rng, v, S = g.rng, t["vars"], t["stems"]
    mode = pick(rng, v["mode"])
    if mode == "segment_len":
        ds = [("XmaX", "mix_max_center", "خلط السعة بطول القطعة"), ("4·XmaX", "forget_half", "أخذ مسار هزة كاملة"), ("XmaX/2", "forget_half", "نصف السعة")]
        return g.make(t, S[mode], "2·XmaX", ds)
    if mode == "time_end_to_end":
        ds = [("T0", "forget_half", "زمن هزة كاملة"), ("T0/4", "mix_max_center", "زمن الانتقال من الطرف إلى المركز"), ("2·T0", "forget_half", "ضاعف بدل أن ينصّف")]
        return g.make(t, S[mode], "T0/2", ds)
    if mode == "path_n_osc":
        n = pick(rng, v["n"])
        ds = [(f"2·{n}·XmaX", "forget_half", "احتسب نصف المسار في كل هزة"), (f"{n}·XmaX", "mix_max_center", "خلط السعة بالمسار"), (f"8·{n}·XmaX", "forget_half", "ضاعف مسار الهزة")]
        return g.make(t, S[mode].replace("{n}", str(n)), f"4·{n}·XmaX", ds)
    if mode == "T0_from_path":
        dt = pick(rng, v["dt"])
        ds = [(dt, "forget_half", "8·XmaX = هزتان لا هزة"), (dt / 8, "mix_max_center", "قسم على 8 (عدد السعات)"), (dt / 4, "forget_half", "قسم على 4")]
        return g.numeric(t, S[mode].replace("{dt}", str(dt)), dt / 2, "s", ds)
    if mode == "XmaX_from_path":
        n, Xcm = pick(rng, v["n"]), pick(rng, v["XmaX_cm"])
        path = 4 * n * Xcm
        ds = [(path / (2 * n), "forget_half", "قسم على 2n"), (path / n, "mix_max_center", "قسم على n"), (path / 4, "forget_half", "نسي عدد الهزات")]
        return g.numeric(t, S[mode].replace("{n}", str(n)).replace("{path}", str(path)), Xcm, "cm", ds)
    dt = pick(rng, v["dt"])
    stem = S[mode].replace("{dt}", str(dt))
    key = f"{pi_str(Fraction(1, dt))} rad·s⁻¹"
    ds = [(f"{pi_str(Fraction(2, dt))} rad·s⁻¹", "forget_half", "اعتبر الزمن المعطى دوراً كاملاً", 2 * math.pi / dt),
          (f"{pi_str(Fraction(1, 2 * dt))} rad·s⁻¹", "forget_half", "اعتبر الزمن المعطى ربع دور", math.pi / (2 * dt)),
          (f"{fmt(1 / dt)} rad·s⁻¹", "forget_2pi", "أهمل π", 1 / dt)]
    return g.make(t, stem, key, ds, answer={"value": math.pi / dt, "unit": "rad·s⁻¹"})


@solver("U1.L1.T17")
def s_l1_t17(g, t):
    rows = t["table"]
    start = g.rng.choice(list(rows))
    row = rows[start]
    stem = t["stem"].replace("{table[start].desc}", row["desc"])
    key = t["options"]["key"].replace("{table[start].phi}", row["phi"])
    others = [r["phi"] for k2, r in rows.items() if k2 != start and r["phi"] != row["phi"]]
    g.rng.shuffle(others)
    ds = []
    for ph in dict.fromkeys(others):
        rule = "sign_flip" if ph == neg_phase(row["phi"]) else "mix_max_center"
        ds.append((t["options"]["key"].replace("{table[start].phi}", ph), rule,
                   "قلب إشارة الطور (جهة الحركة الابتدائية)" if rule == "sign_flip" else "خلط موضع الانطلاق أو جهته"))
    return g.make(t, stem, key, ds)


@solver("U1.L1.T19")
def s_l1_t19(g, t):
    rng, v = g.rng, t["vars"]
    Xcm = pick(rng, v["XmaX_cm"])
    rows = g.by_id["U1.L1.T17"]["table"]
    start = rng.choice(list(rows))
    phi = rows[start]["phi"]
    if rng.random() < 0.6:
        T0 = pick(rng, [1, 2, 4])
        om, om_wrong, om_rule = pi_str(Fraction(2, T0)), pi_str(Fraction(1, T0)), ("forget_2pi", "ω0 = 1/T0 بدل 2π/T0")
        given = f"دوره الخاص T0 = {T0} s"
    else:
        m, k = rng.choice([[2, 20], [0.04, 10], [0.5, 8]])
        om, om_wrong, om_rule = sqrt_str(Fraction(k) / Fraction(m)), sqrt_str(Fraction(m) / Fraction(k)), ("invert_ratio", "ω0 = √(m/k) بدل √(k/m)")
        given = f"كتلة جسمه {fmt(m)} kg وثابت صلابة نابضه {fmt(k)} N·m⁻¹"

    def eq(Xs, oms, ph):
        return f"x = {Xs}·cos({oms}·t{phase_txt(ph)})"

    key = eq(fmt(Xcm / 100), om, phi)
    ds = [(eq(fmt(Xcm), om, phi), "unit_cm_m", "السعة بالسنتيمتر بدل المتر"),
          (eq(fmt(Xcm / 100), om_wrong, phi), om_rule[0], om_rule[1]),
          (eq(fmt(Xcm / 100), om, neg_phase(phi)), "sign_flip" if phi not in ("0", "π") else "mix_max_center",
           "إشارة الطور الابتدائي" if phi not in ("0", "π") else "خلط +XmaX بـ −XmaX")]
    stem = t["stem"].replace("{XmaX_cm}", fmt(Xcm)).replace("{given}", given).replace("{start.desc}", rows[start]["desc"])
    return g.make(t, stem, key, ds)


PHIS = {"0": Fraction(0), "π/6": Fraction(1, 6), "π/3": Fraction(1, 3), "π/2": Fraction(1, 2),
        "π": Fraction(1), "−π/3": Fraction(-1, 3), "−π/2": Fraction(-1, 2)}


@solver("U1.L1.T18", "U1.L2.T11", "U1.L3.T14")
def s_pass_times(g, t):
    rng = g.rng
    base = g.by_id["U1.L1.T18"]
    sym = t.get("symbol_map") or {}
    X = sym.get("XmaX", "XmaX")
    T0 = pick(rng, [1, 2, 4, 6, 12])
    c = Fraction(2, T0)                              # ω0 = c·π
    phs = rng.choice(list(PHIS))
    ph = PHIS[phs]
    mode = rng.choice(["t_center_first", "t_center_second", "t_plus_max_first", "t_minus_max_first", "v_at_center_first"])
    Xm = pick(rng, base["vars"]["XmaX"])
    Xm = Xm if t["id"] == "U1.L1.T18" else Xm * 2.5   # سعة زاوية (rad) للنواسين الدورانيين
    oms = pi_str(c)
    if t["id"] == "U1.L1.T18":
        head = f"نواس مرن غير متخامد تابع مطاله x = {fmt(Xm)}·cos({oms}·t{phase_txt(phs)}) (x بالمتر، t بالثانية)."
        vunit = "m·s⁻¹"
    elif t["id"] == "U1.L2.T11":
        head = f"نواس فتل غير متخامد تابع مطاله الزاوي θ = {fmt(Xm)}·cos({oms}·t{phase_txt(phs)}) (θ بالراديان، t بالثانية)."
        vunit = "rad·s⁻¹"
    else:
        if Xm > 0.2:
            return None
        head = f"نواس ثقلي بسيط يهتز بسعة صغيرة وتابع مطاله الزاوي θ = {fmt(Xm)}·cos({oms}·t{phase_txt(phs)}) (θ بالراديان، t بالثانية)."
        vunit = "rad·s⁻¹"

    def first_t(target: Fraction, period: Fraction):
        k = -3
        while True:
            tt = (target - ph + k * period) / c
            if tt > 0:
                return tt
            k += 1

    if mode.startswith("t_center"):
        if ph in (Fraction(1, 2), Fraction(-1, 2)):
            return None
        t1 = first_t(Fraction(1, 2), Fraction(1))
        second = mode == "t_center_second"
        val = t1 + Fraction(T0, 2) if second else t1
        q = "لحظة المرور الثاني بمركز الاهتزاز:" if second else "لحظة المرور الأول بمركز الاهتزاز:"
        if second:
            ds = [(float(t1 + T0), "forget_n", "أضاف T0 بدل T0/2 بين مرورين متتاليين"),
                  (float(t1), "forget_n", "أعطى لحظة المرور الأول"),
                  (T0 / 4 + T0 / 2, "quarter_period_reflex", "T0/4 + T0/2 مهما كان φ")]
        else:
            ds = [(T0 / 4, "quarter_period_reflex", "T0/4 مهما كان φ"),
                  (float(t1 + Fraction(T0, 2)), "forget_n", "أعطى لحظة المرور الثاني"),
                  (float(first_t(Fraction(0), Fraction(1))), "sin_cos", "حلّ sin(…) = 0 بدل cos(…) = 0")]
        return g.numeric(t, f"{head} {q}", float(val), "s", ds)
    if mode == "t_plus_max_first":
        if ph == 0:
            return None
        val = first_t(Fraction(0), Fraction(2))
        q = f"أول لحظة يكون فيها المطال أعظمياً موجباً (+{X}):"
        ds = [(T0 / 4, "quarter_period_reflex", "T0/4 مهما كان φ"),
              (float(first_t(Fraction(1), Fraction(2))), "sign_flip", f"حلّ من أجل −{X}"),
              (float(val + Fraction(T0, 2)), "forget_n", "أضاف نصف دور")]
        return g.numeric(t, f"{head} {q}", float(val), "s", ds)
    if mode == "t_minus_max_first":
        if ph == 1:
            return None
        val = first_t(Fraction(1), Fraction(2))
        q = f"أول لحظة يكون فيها المطال أعظمياً سالباً (−{X}):"
        ds = [(T0 / 4, "quarter_period_reflex", "T0/4 مهما كان φ"),
              (float(first_t(Fraction(0), Fraction(2))), "sign_flip", f"حلّ من أجل +{X}"),
              (float(val + Fraction(T0, 2)), "forget_n", "أضاف نصف دور")]
        return g.numeric(t, f"{head} {q}", float(val), "s", ds)
    # v_at_center_first
    if ph in (Fraction(1, 2), Fraction(-1, 2)):
        return None
    t1 = first_t(Fraction(1, 2), Fraction(1))
    k = c * t1 + ph - Fraction(1, 2)                 # عدد صحيح
    sgn = -1 if int(k) % 2 == 0 else 1               # v = −ω0·X·sin(π/2 + kπ)
    coef = c * Fraction(Xm).limit_denominator(1000)
    key = f"{MINUS if sgn < 0 else '+'}{pi_str(coef)} {vunit}"
    val = sgn * float(coef) * math.pi
    q = "السرعة (الجبرية) لحظة المرور الأول بمركز الاهتزاز:"
    ds = [(f"{'+' if sgn < 0 else MINUS}{pi_str(coef)} {vunit}", "sign_flip", "جهة الحركة عند المرور الأول", -val),
          (f"{MINUS if sgn < 0 else '+'}{fmt(float(coef))} {vunit}", "forget_2pi", "نسي π في ω0", sgn * float(coef)),
          (f"0 {vunit}", "mix_max_center", "ظنّ السرعة معدومة في مركز الاهتزاز (خلط مع الطرفين)", 0.0)]
    return g.make(t, f"{head} {q}", key, ds, answer={"value": val, "unit": vunit})


@solver("U1.L2.T06")
def s_l2_t06(g, t):
    rng, v, S = g.rng, t["vars"], t["stems"]
    mode = rng.choice(["length", "length", "diameter", "inertia", "amplitude", "split_wire", "target_T", "two_wires_L", "two_wires_C", "cut_fraction"])
    if mode == "length":
        fl = pick(rng, v["fl"])
        r = math.sqrt(fl)
        stem = S["length"].replace("{fl}", mult_words(fl))
        ds = [(ratio_str(fl, "T0"), "forget_sqrt", "T0 ∝ l بدل √l"), (ratio_str(1 / r, "T0"), "invert_ratio", "قلب النسبة"),
              ("T0", "mix_pendulums", "ظنّ الدور مستقلاً عن السلك")]
        return g.make(t, stem, ratio_str(r, "T0"), ds)
    if mode == "diameter":
        fd = pick(rng, v["fd"])
        stem = S["diameter"].replace("{fd}", mult_words(fd))
        ds = [(ratio_str(1 / fd, "T0"), "exponent4", "T0 ∝ 1/d بدل 1/d² (نسي الأس ٤)"),
              (ratio_str(fd * fd, "T0"), "invert_ratio", "قلب النسبة"), (ratio_str(1 / math.sqrt(fd), "T0"), "exponent4", "ظنّ C ∝ d")]
        return g.make(t, stem, ratio_str(1 / fd ** 2, "T0"), ds)
    if mode == "inertia":
        fI = pick(rng, v["fI"])
        stem = S["inertia"].replace("{fI}", fmt(fI))
        ds = [(ratio_str(fI, "T0"), "forget_sqrt", "أهمل الجذر"), (ratio_str(1 / math.sqrt(fI), "T0"), "invert_ratio", "قلب النسبة"),
              ("T0", "mix_pendulums", "ظنّ الدور مستقلاً عن IΔ")]
        return g.make(t, stem, ratio_str(math.sqrt(fI), "T0"), ds)
    if mode == "amplitude":
        T0 = pick(rng, v["T0"])
        stem = S["amplitude"].replace("{T0}", fmt(T0))
        ds = [(T0 * 1.5, "amplitude_dependence", "ظنّ T0 ∝ θmax"), (T0 * math.sqrt(1.5), "amplitude_dependence", "ظنّ T0 ∝ √θmax"),
              (T0 / 1.5, "amplitude_dependence", "ظنّ T0 ∝ 1/θmax")]
        return g.numeric(t, stem, T0, "s", ds)
    if mode == "split_wire":
        ds = [("T0/√2", "forget_square", "أخذ C′ = 2C فقط"), ("2·T0", "invert_ratio", "قلب النسبة"),
              ("T0/4", "forget_sqrt", "C′ = 4C ⇒ T0/4 بلا جذر")]
        return g.make(t, S["split_wire"], "T0/2", ds)
    if mode == "target_T":
        T0 = pick(rng, v["T0"])
        stem = S["target_T"].replace("{T0/2}", fmt(T0 / 2)).replace("{T0}", fmt(T0))
        ds = [("l/2", "forget_square", "l′/l = T0′/T0 بدل (T0′/T0)²"), ("4·l", "invert_ratio", "قلب النسبة"), ("l/16", "exponent4", "ربّع مرتين")]
        return g.make(t, stem, "l/4", ds)
    if mode == "two_wires_L":
        ds = [("L1 = 2·L2", "forget_square", "لم يربّع النسبة"), ("L2 = 4·L1", "invert_ratio", "قلب النسبة"), ("L1 = √2·L2", "mix_formulas", "جذر بدل تربيع")]
        return g.make(t, S["two_wires_L"], "L1 = 4·L2", ds)
    if mode == "two_wires_C":
        ds = [("C1 = 4·C2", "invert_ratio", "قلب النسبة"), ("C2 = 2·C1", "forget_square", "لم يربّع النسبة"), ("C2 = 16·C1", "exponent4", "أس ٤ في غير موضعه")]
        return g.make(t, S["two_wires_C"], "C2 = 4·C1", ds)
    word, f = rng.choice([("الثلث", Fraction(2, 3)), ("الربع", Fraction(3, 4))])
    stem = S["cut_fraction"].replace("الثلث/الربع", word)
    ds = [(ratio_str(math.sqrt(1 - f), "T0"), "mix_formulas", "استعمل الجزء المحذوف بدل الباقي"),
          (ratio_str(float(f), "T0"), "forget_sqrt", "أهمل الجذر"), (ratio_str(1 / math.sqrt(f), "T0"), "invert_ratio", "قلب النسبة")]
    return g.make(t, stem, ratio_str(math.sqrt(f), "T0"), ds)


@solver("U1.L2.T08")
def s_l2_t08(g, t):
    rng = g.rng
    om, thm, C = pick(rng, [2, 4, 5, 10]), pick(rng, [0.1, 0.2, 0.4, 0.5, 1]), pick(rng, [0.1, 0.4, 0.8])
    ask = rng.choice(["alpha_at_theta", "alpha_max", "omega_max", "E", "Ep_frac", "Ek_frac"])
    frac = rng.choice([Fraction(1, 2), Fraction(1, 4), Fraction(-1, 2)])
    th = float(frac) * thm
    head = f"نواس فتل غير متخامد نبضه الخاص ω0 = {om} rad·s⁻¹ وسعته الزاوية θmax = {fmt(thm)} rad"
    if ask == "alpha_at_theta":
        stem = f"{head}. احسب التسارع الزاوي θ″ في الموضع الذي مطاله الزاوي θ = {fmt(th)} rad."
        ds = [(om * om * th, "sign_flip", "أهمل إشارة الإرجاع"), (-om * th, "mix_v_a", "ω0 بدل ω0²"), (-om * om * thm, "mix_max_center", "حسب القيمة العظمى")]
        return g.numeric(t, stem, -om * om * th, "rad·s⁻²", ds)
    if ask == "alpha_max":
        stem = f"{head}. احسب القيمة العظمى للتسارع الزاوي θ″max."
        ds = [(om * thm, "mix_v_a", "حسب السرعة الزاوية العظمى"), (om * thm * thm, "forget_square", "ربّع θmax بدل ω0"), (om * om, "mix_formulas", "نسي θmax")]
        return g.numeric(t, stem, om * om * thm, "rad·s⁻²", ds)
    if ask == "omega_max":
        stem = f"{head}. احسب القيمة العظمى للسرعة الزاوية θ′max."
        ds = [(om * om * thm, "mix_v_a", "حسب التسارع الزاوي الأعظمي"), (thm / om, "invert_ratio", "قسم بدل الضرب"), (2 * om * thm, "mix_formulas", "ضاعف بلا مسوّغ (2ω0θmax)")]
        return g.numeric(t, stem, om * thm, "rad·s⁻¹", ds)
    head += f" وثابت فتل سلكه C = {fmt(C)} N·m·rad⁻¹"
    E = 0.5 * C * thm * thm
    if ask == "E":
        stem = f"{head}. احسب الطاقة الميكانيكية E للنواس."
        ds = [(C * thm * thm, "forget_half", "نسي ½"), (0.5 * C * thm, "forget_square", "نسي التربيع"), (0.5 * om * om * thm * thm, "mix_pendulums", "استعمل ω0² بدل C")]
        return g.numeric(t, stem, E, "J", ds)
    f2 = float(frac) ** 2
    if ask == "Ep_frac":
        stem = f"{head}. احسب الطاقة الكامنة المرونية عندما يكون المطال الزاوي θ = {fmt(th)} rad."
        ds = [(E * abs(float(frac)), "forget_square", "Ep ∝ θ لا θ²"), (E * (1 - f2), "mix_Ep_Ek", "حسب الحركية"), (E, "mix_max_center", "أعطى القيمة العظمى")]
        return g.numeric(t, stem, E * f2, "J", ds)
    stem = f"{head}. احسب الطاقة الحركية الدورانية عندما يكون المطال الزاوي θ = {fmt(th)} rad."
    ds = [(E * f2, "mix_Ep_Ek", "حسب الكامنة"), (E * (1 - abs(float(frac))), "forget_square", "استعمل θ لا θ²"), (E, "mix_max_center", "أعطى الطاقة الكلية")]
    return g.numeric(t, stem, E * (1 - f2), "J", ds)


@solver("U1.L2.T10")
def s_l2_t10(g, t):
    rng = g.rng
    body = rng.choice(["rod_uniform", "disk", "rod_massless_2masses"])
    ask = rng.choice(["I", "T0", "C"])
    if body == "rod_uniform":
        m, l = pick(rng, [0.12, 0.24, 0.6, 1.2, 2.4]), pick(rng, [0.1, 0.5, 1])
        I = m * l * l / 12
        desc = f"ساق متجانسة كتلتها {fmt(m)} kg وطولها {fmt(l)} m"
        wrongI = (m * l * l / 3, "mix_pendulums", "استعمل ml²/3 (محور من الطرف) بدل ml²/12")
        wrongU = (m * (l * 100) ** 2 / 12, "unit_cm_m", "ترك الطول بالسنتيمتر")
        wrongS = (m * l / 12, "forget_square", "نسي تربيع الطول")
    elif body == "disk":
        m, r = pick(rng, [0.1, 0.2, 0.5, 1, 2]), pick(rng, [0.1, 0.2, 0.4])
        I = 0.5 * m * r * r
        desc = f"قرص متجانس كتلته {fmt(m)} kg ونصف قطره {fmt(r)} m"
        wrongI = (m * r * r, "mix_pendulums", "استعمل mr² (حلقة/نقطة مادية) بدل mr²/2")
        wrongU = (0.5 * m * (r * 100) ** 2, "unit_cm_m", "ترك نصف القطر بالسنتيمتر")
        wrongS = (0.5 * m * r, "forget_square", "نسي تربيع نصف القطر")
    else:
        m1, l = pick(rng, [0.02, 0.1, 0.2, 0.4]), pick(rng, [0.1, 0.2, 0.5, 1])
        I = 2 * m1 * (l / 2) ** 2
        desc = f"ساق مهملة الكتلة طولها {fmt(l)} m تحمل في طرفيها كتلتين نقطيتين متماثلتين كل منهما {fmt(m1)} kg"
        wrongI = (2 * m1 * l * l, "mix_pendulums", "استعمل l بدل l/2 لبعد كل كتلة عن المحور")
        wrongU = (I * 1000, "unit_g_kg", "ترك الكتلة بالغرام")
        wrongS = (2 * m1 * (l / 2), "forget_square", "نسي تربيع البعد")
    if not nice(I):
        return None
    base = f"نواس فتل يتألف من {desc} معلّق من مركزه بسلك فتل شاقولي"
    if ask == "I":
        return g.numeric(t, f"{base}. احسب عزم عطالة الجملة IΔ بالنسبة لمحور السلك.", I, "kg·m²", [wrongI, wrongU, wrongS])
    if ask == "T0":
        C = pick(rng, [0.008, 0.02, 0.05, 0.08, 0.4, 0.8, 2])
        val = 2 * math.sqrt(PI2 * I / C)
        stem = f"{base} ثابت فتله C = {fmt(C)} N·m·rad⁻¹. احسب دوره الخاص T0 (π² = 10)."
        ds = [(2 * math.sqrt(PI2 * wrongI[0] / C), "mix_pendulums", wrongI[2]), (2 * math.sqrt(PI2 * C / I), "invert_ratio", "C/IΔ بدل IΔ/C"),
              (math.sqrt(I / C), "forget_2pi", "أهمل 2π")]
        return g.numeric(t, stem, val, "s", ds)
    T0 = pick(rng, [0.5, 1, 2, 4])
    stem = f"{base}؛ دوره الخاص T0 = {fmt(T0)} s. احسب ثابت فتل السلك C (π² = 10)."
    ds = [(4 * PI2 * wrongI[0] / T0 ** 2, "mix_pendulums", wrongI[2]), (4 * PI2 * I / T0, "forget_square", "نسي تربيع T0"),
          (I / T0 ** 2, "forget_4pi2", "نسي 4π²")]
    return g.numeric(t, stem, 4 * PI2 * I / T0 ** 2, "N·m·rad⁻¹", ds)


@solver("U1.L3.T06")
def s_l3_t06(g, t):
    rng = g.rng
    fl, fm = pick(rng, [0.25, 0.5, 2, 4, 1]), pick(rng, [1, 4])
    moon = rng.random() < 0.35
    if fl == 1 and not moon:
        return None
    fg = Fraction(1, 6) if moon else Fraction(1)
    kind = rng.choice(["بسيط", "مركّب"]) if fl == 1 else "بسيط"
    changes = []
    if fl != 1:
        changes.append(f"نجعل طول خيطه {mult_words(fl)} ما كان عليه")
    if moon:
        changes.append("ننقله إلى سطح القمر حيث g′ = g/6")
    if fm != 1:
        changes.append(f"نجعل كتلته {mult_words(fm)} ما كانت عليه")
    r = math.sqrt(fl / float(fg))
    ds = [(ratio_str(fl / float(fg), "T0"), "forget_sqrt", "أهمل الجذر"), (ratio_str(1 / r, "T0"), "invert_ratio", "قلب النسبة"),
          (ratio_str(r * (math.sqrt(fm) if fm != 1 else 2), "T0"), "mix_pendulums", "ظنّ الكتلة تؤثر في الدور")]
    stem = t["stem"].replace("{kind}", kind).replace("{change}", " و".join(changes))
    return g.make(t, stem, ratio_str(r, "T0"), ds)


@solver("U1.L3.T07")
def s_l3_t07(g, t):
    rng, v = g.rng, t["vars"]
    l, m, T0 = pick(rng, [0.1, 0.2, 0.4, 0.625, 1, 2.5]), pick(rng, [0.1, 0.2, 0.5]), pick(rng, [1, 2, 4])
    ask = pick(rng, v["ask"])
    ml = f"كتلة كرته m = {fmt(m)} kg وطول خيطه l = {fmt(l)} m"
    if ask == "omega0":
        val, unit, given, askt = math.sqrt(G / l), "rad·s⁻¹", f"طول خيطه l = {fmt(l)} m", "نبضه الخاص ω0"
        ds = [(G / l, "forget_sqrt", "أهمل الجذر"), (math.sqrt(l / G), "invert_ratio", "قلب النسبة"), (2 * math.sqrt(PI2 * l / G), "mix_formulas", "حسب T0 بدل ω0")]
    elif ask == "I":
        val, unit, given, askt = m * l * l, "kg·m²", ml, "عزم عطالة الكرة IΔ بالنسبة لمحور الدوران"
        ds = [(m * l, "forget_square", "نسي التربيع"), (m * l * l / 12, "mix_pendulums", "استعمل ml²/12 (ساق) لنقطة مادية"), (m * (l * 100) ** 2, "unit_cm_m", "ترك الطول بالسنتيمتر")]
    elif ask == "l_from_I":
        I = m * l * l
        if not nice(I):
            return None
        val, unit, given, askt = l, "m", f"كتلة كرته m = {fmt(m)} kg وعزم عطالتها IΔ = {fmt(I)} kg·m²", "طول خيطه l"
        ds = [(I / m, "forget_sqrt", "أهمل الجذر"), (math.sqrt(m / I), "invert_ratio", "قلب النسبة"), (I * m, "mix_formulas", "ضرب بدل القسمة")]
    else:
        val, unit, given, askt = G * T0 ** 2 / (4 * PI2), "m", f"دوره الخاص T0 = {fmt(T0)} s", "طول خيطه l"
        ds = [(G * T0 / (4 * PI2), "forget_square", "نسي تربيع T0"), (4 * PI2 / (G * T0 ** 2), "invert_ratio", "قلب العلاقة"), (G * T0 ** 2, "forget_4pi2", "نسي 4π²")]
    stem = t["stem"].replace("{given}", given).replace("{ask}", askt)
    return g.numeric(t, stem, val, unit, ds)


@solver("U1.L3.T08")
def s_l3_t08(g, t):
    rng = g.rng
    m, l, tm, th = pick(rng, [0.1, 0.2, 0.4, 0.5]), pick(rng, [0.2, 0.4, 1]), pick(rng, [37, 60, 90]), pick(rng, [0, 37, 60])
    ask = rng.choice(["v_bottom", "v_theta", "T_bottom", "T_theta", "a_n_bottom", "a_t_theta", "theta_max_from_v0"])
    if th > tm:
        return None
    cm, c = COS[tm], COS[th]
    consts = "(g = 10 m·s⁻²، cos 37° = 0.8، sin 37° = 0.6)" if 37 in (tm, th) else "(g = 10 m·s⁻²)"
    if ask == "theta_max_from_v0":
        v0 = 2
        cosmax = 1 - v0 ** 2 / (2 * G * l)
        deg = {0.5: 60, 0.0: 90, 0.8: 37}.get(round(cosmax, 3))
        if deg is None:
            return None
        stem = f"نواس ثقلي بسيط طول خيطه {fmt(l)} m تمر كرته بوضع التوازن الشاقولي بسرعة {v0} m·s⁻¹. السعة الزاوية θmax للحركة (g = 10 m·s⁻²، cos 37° = 0.8):"
        wrong = [(d, r, why) for d, r, why in [(90, "forget_half", "نسي 2 في 2gh"), (60, "forget_half", "نسي 2 في 2gh"),
                 (37, "sign_flip", "cos θmax = 1 + v0²/2gl"), (30, "forget_sqrt", "أهمل الجذر"), (45, "mix_formulas", "خلط بعلاقة أخرى")] if d != deg]
        return g.make(t, stem, f"{deg}°", [(f"{d}°", r, why) for d, r, why in wrong])
    stem0 = t["stem"].replace("{m}", fmt(m)).replace("{l}", fmt(l)).replace("{theta_max_deg}", str(tm)).replace("(g = 10 m·s⁻²)", consts)
    vb = math.sqrt(2 * G * l * (1 - cm))
    if ask == "v_bottom":
        askt, val, unit = "سرعة الكرة لحظة مرورها بوضع التوازن الشاقولي", vb, "m·s⁻¹"
        ds = [(math.sqrt(G * l * (1 - cm)), "forget_half", "نسي 2 في 2gh"), (math.sqrt(2 * G * l * (1 + cm)), "sign_flip", "(1 + cos) بدل (1 − cos)"),
              (math.sqrt(G / l) * math.radians(tm) * l, "forget_small_angle", "طبّق vmax = ω0·XmaX على سعة كبيرة")]
    elif ask == "v_theta":
        if th in (0, tm):
            return None
        askt, val, unit = f"سرعة الكرة عندما يصنع الخيط الزاوية {th}° مع الشاقول", math.sqrt(2 * G * l * (c - cm)), "m·s⁻¹"
        ds = [(vb, "mix_max_center", "أعطى السرعة عند الشاقول"), (math.sqrt(G * l * (c - cm)), "forget_half", "نسي 2 في 2gh"),
              (math.sqrt(2 * G * l * (1 - c)), "sign_flip", "(1 − cos θ) بدل (cos θ − cos θmax)")]
    elif ask == "T_bottom":
        askt, val, unit = "شدة قوة توتر الخيط لحظة المرور بوضع التوازن الشاقولي", m * G * (3 - 2 * cm), "N"
        ds = [(m * G, "forget_normal_accel", "T = mg (أهمل mv²/l)"), (2 * m * G * (1 - cm), "mix_formulas", "T = mv²/l فقط (أهمل mg)"),
              (m * G * cm, "forget_normal_accel", "T = mg·cos θmax")]
    elif ask == "T_theta":
        if th == 0:
            return None
        askt, val, unit = f"شدة قوة توتر الخيط عندما يصنع الخيط الزاوية {th}° مع الشاقول", m * G * (3 * c - 2 * cm), "N"
        ds = [(m * G * c, "forget_normal_accel", "T = mg·cos θ (أهمل mv²/l)"), (m * G * (3 * cm - 2 * c), "sign_flip", "قلب θ وθmax"),
              (m * G * (3 - 2 * cm), "mix_max_center", "أعطى التوتر عند الشاقول")]
    elif ask == "a_n_bottom":
        askt, val, unit = "التسارع الناظمي للكرة لحظة المرور بوضع التوازن", 2 * G * (1 - cm), "m·s⁻²"
        ds = [(G * (1 - cm), "forget_half", "نسي 2 في 2gh"), (G, "mix_formulas", "a = g"), (0.0, "mix_v_a", "ظنّ التسارع معدوماً في المركز (خلط مع المماسي)")]
    else:
        if th == 0:
            return None
        askt, val, unit = f"التسارع المماسي للكرة عندما يصنع الخيط الزاوية {th}° مع الشاقول", G * SIN[th], "m·s⁻²"
        ds = [(G * c, "sin_cos", "استعمل cos بدل sin"), (G, "mix_formulas", "a = g"), (G * math.radians(th), "forget_small_angle", "θ بدل sin θ")]
    return g.numeric(t, stem0.replace("{ask}", askt), val, unit, ds)


@solver("U1.L3.T09")
def s_l3_t09(g, t):
    rng = g.rng
    body = rng.choice(["rod_end", "rod_at_L6", "ring_rim", "disk_rim"])
    ask = rng.choice(["T0", "T0", "l_sync", "T0_formula"])
    M = pick(rng, [0.5, 2, 3])
    if body in ("rod_end", "rod_at_L6"):
        L = pick(rng, [0.6, 1.5, 2.4, 6])
        dim, sym = L, "L"
        desc = f"ساق متجانسة كتلتها {fmt(M)} kg وطولها L = {fmt(L)} m"
        form, simple = "T0 = 2π·√(2L/(3g))", "T0 = 2π·√(L/g)"
        if body == "rod_end":
            I, d, axis = M * L * L / 3, L / 2, "يمر من أحد طرفيها ويعامدها"
            wrongI = (M * L * L / 12, "d_vs_I", "استعمل IG = ML²/12 دون هايغنز")
            wrongd = (L, "d_vs_I", "d = L بدل L/2")
            formIG = "T0 = 2π·√(L/(6g))"
        else:
            I, d, axis = M * L * L / 9, L / 6, "يبعد L/6 عن مركزها ويعامدها"
            wrongI = (M * L * L / 12, "d_vs_I", "نسي حدّ هايغنز M·d²")
            wrongd = (L / 2, "d_vs_I", "d = L/2 بدل L/6")
            formIG = "T0 = 2π·√(L/(2g))"
    elif body == "ring_rim":
        r = pick(rng, [0.02, 0.5, 0.8, 2])
        dim, sym = r, "r"
        desc = f"حلقة متجانسة كتلتها {fmt(M)} kg ونصف قطرها r = {fmt(r)} m"
        I, d, axis = 2 * M * r * r, r, "يمر من نقطة على محيطها ويعامد مستويها"
        form, simple, formIG = "T0 = 2π·√(2r/g)", "T0 = 2π·√(r/g)", "T0 = 2π·√(r/g)"
        wrongI = (M * r * r, "d_vs_I", "IΔ = Mr² دون هايغنز")
        wrongd = None
    else:
        r = pick(rng, [0.24, 0.54, 0.96])
        dim, sym = r, "r"
        desc = f"قرص متجانس كتلته {fmt(M)} kg ونصف قطره r = {fmt(r)} m"
        I, d, axis = 1.5 * M * r * r, r, "يمر من نقطة على محيطه ويعامد مستويه"
        form, simple, formIG = "T0 = 2π·√(3r/(2g))", "T0 = 2π·√(r/g)", "T0 = 2π·√(r/(2g))"
        wrongI = (0.5 * M * r * r, "d_vs_I", "IΔ = Mr²/2 دون هايغنز")
        wrongd = None
    base = f"نواس ثقلي مركّب من {desc} يهتز في مستوٍ شاقولي بسعة صغيرة حول محور أفقي {axis}"
    lsync = I / (M * d)
    if ask == "T0":
        val = 2 * math.sqrt(PI2 * I / (M * G * d))
        ds = [(2 * math.sqrt(PI2 * wrongI[0] / (M * G * d)), wrongI[1], wrongI[2]),
              (2 * math.sqrt(PI2 * dim / G), "mix_pendulums", f"عامله كنواس بسيط طوله {sym}"), (math.sqrt(I / (M * G * d)), "forget_2pi", "أهمل 2π")]
        if wrongd:
            ds.insert(1, (2 * math.sqrt(PI2 * I / (M * G * wrongd[0])), wrongd[1], wrongd[2]))
        return g.numeric(t, f"{base}. احسب دوره الخاص T0 (g = 10 m·s⁻²، π² = 10).", val, "s", ds)
    if ask == "l_sync":
        ds = [(dim, "mix_pendulums", f"ظنّ الطول المواقت = {sym}"), (d, "d_vs_I", "أعطى d بدل IΔ/(m·d)"), (I / M, "mix_formulas", "IΔ/m دون القسمة على d")]
        return g.numeric(t, f"{base}. احسب طول النواس الثقلي البسيط المواقت له.", lsync, "m", ds)
    ds = [(simple, "mix_pendulums", "عامله كنواس بسيط"), (formIG, "d_vs_I", "IG دون هايغنز")] + formula_transforms(form)
    return g.make(t, f"{base}. عبارة دوره الخاص T0 بدلالة {sym} وg:", form, ds)


@solver("U1.L3.T10")
def s_l3_t10(g, t):
    rng = g.rng
    cfg = rng.choice(["axis_at_L4_two_equal", "axis_at_L4_two_equal", "axis_top_mass_mid_and_bottom", "axis_top_mass_top_and_bottom"])
    tab = t["table"][cfg]
    m1, m2 = pick(rng, [0.2, 0.3, 0.4, 0.5]), pick(rng, [0.2, 0.4, 0.6])
    if cfg == "axis_at_L4_two_equal":
        L = pick(rng, [0.2, 0.8, 1.8, 3.2])
        I, d, Mt = (5 / 8) * m1 * L * L, L / 4, 2 * m1
        vals = f"L = {fmt(L)} m، m1 = {fmt(m1)} kg"
        asks = ["T0", "T0", "l_sync", "omega_bottom", "L_from_T0"]
        wrongT = [(2 * math.sqrt(PI2 * I / (Mt * G * 0.75 * L)), "d_vs_I", "d = 3L/4 (بعد الكتلة السفلية) بدل L/4"),
                  (2 * math.sqrt(PI2 * I / (Mt * G * L / 2)), "sign_r_above", "أهمل إشارة الكتلة فوق المحور ⇒ d = L/2"),
                  (2 * math.sqrt(PI2 * I / (m1 * G * d)), "mix_pendulums", "استعمل m1 بدل كتلة الجملة 2m1")]
    elif cfg == "axis_top_mass_mid_and_bottom":
        L = pick(rng, [0.5, 1, 1.5])
        I, Mt = m1 * (L / 2) ** 2 + m2 * L * L, m1 + m2
        d = (m1 * L / 2 + m2 * L) / Mt
        vals = f"L = {fmt(L)} m، m1 = {fmt(m1)} kg، m2 = {fmt(m2)} kg"
        asks = ["T0", "l_sync"]
        wrongT = [(2 * math.sqrt(PI2 * I / (Mt * G * L)), "d_vs_I", "d = L"),
                  (2 * math.sqrt(PI2 * m2 * L * L / (Mt * G * d)), "mix_pendulums", "أهمل الكتلة الوسطى في IΔ"),
                  (2 * math.sqrt(PI2 * I / (m2 * G * d)), "mix_pendulums", "استعمل m2 بدل كتلة الجملة")]
    else:
        L = pick(rng, [0.4, 0.9, 1.6, 2.5])
        I, Mt = m2 * L * L, m1 + m2
        d = m2 * L / Mt
        vals = f"L = {fmt(L)} m، m1 = {fmt(m1)} kg، m2 = {fmt(m2)} kg"
        asks = ["T0", "l_sync"]
        wrongT = [(2 * math.sqrt(PI2 * (I + m1 * L * L) / (Mt * G * d)), "mix_pendulums", "أدخل الكتلة الواقعة على المحور في IΔ بذراع L"),
                  (2 * math.sqrt(PI2 * I / (Mt * G * L)), "d_vs_I", "d = L"),
                  (2 * math.sqrt(PI2 * I / (Mt * G * L / 2)), "sign_r_above", "أخذ d = L/2")]
    desc = f"{tab['desc']} ({vals})"
    ask = rng.choice(asks)
    if ask == "T0":
        val = 2 * math.sqrt(PI2 * I / (Mt * G * d))
        stem = f"{desc}. يهتز النواس في مستوٍ شاقولي بسعة صغيرة. احسب دوره الخاص T0 (g = 10 m·s⁻²، π² = 10)."
        return g.numeric(t, stem, val, "s", wrongT)
    if ask == "l_sync":
        lsync = I / (Mt * d)
        ds = [(d, "d_vs_I", "أعطى d بدل IΔ/(m·d)"), (L, "mix_pendulums", "ظنّ الطول المواقت = L"), (I / Mt, "mix_formulas", "IΔ/m دون القسمة على d")]
        return g.numeric(t, f"{desc}. احسب طول النواس الثقلي البسيط المواقت له.", lsync, "m", ds)
    if ask == "L_from_T0":
        T0 = pick(rng, [1, 2, 3, 4])
        stem = f"{tab['desc']} (m1 = {fmt(m1)} kg)؛ دوره الخاص T0 = {T0} s. احسب طول الساق L (g = 10 m·s⁻²، π² = 10)."
        ds = [(0.4 * T0 * T0, "sign_r_above", "d = L/2 ⇒ L = 0.4·T0²"), (T0 * T0 / 10, "mix_pendulums", "m1 بدل 2m1 في m·g·d"), (T0 / 5, "forget_square", "نسي تربيع T0")]
        return g.numeric(t, stem, T0 * T0 / 5, "m", ds)
    tm = pick(rng, [60, 90])
    cm = COS[tm]
    w2 = 2 * Mt * G * d * (1 - cm) / I
    val = math.sqrt(w2)
    om0 = math.sqrt(Mt * G * d / I)
    stem = f"{desc}. نزيح النواس عن وضع توازنه بزاوية {tm}° ونتركه دون سرعة ابتدائية. احسب سرعته الزاوية لحظة مروره بوضع التوازن (g = 10 m·s⁻²)."
    ds = [(f"{sqrt_str(w2 / 2)} rad·s⁻¹", "forget_half", "نسي 2 في نظرية الطاقة الحركية", math.sqrt(w2 / 2)),
          (f"{fmt(om0 * math.radians(tm))} rad·s⁻¹", "forget_small_angle", "طبّق θ′max = ω0·θmax على سعة كبيرة", om0 * math.radians(tm)),
          (f"{sqrt_str(w2 * (1 + cm) / (1 - cm))} rad·s⁻¹", "sign_flip", "(1 + cos) بدل (1 − cos)", math.sqrt(w2 * (1 + cm) / (1 - cm)))]
    return g.make(t, stem, f"{sqrt_str(w2)} rad·s⁻¹", ds, answer={"value": val, "unit": "rad·s⁻¹"})


# ───────────────────────────── تحقق، عيّنة، إخراج ─────────────────────────────
def verify(item, rules) -> list:
    errs = []
    if item["type"] == "proof":
        return errs if item.get("steps") else ["برهان بلا خطوات"]
    o = item["options"]
    if len(o) != 4:
        errs.append("عدد الخيارات ≠ 4")
    if len({norm(x) for x in o}) != len(o):
        errs.append("خياران متطابقان")
    if not (0 <= item["correctIndex"] < len(o)):
        errs.append("correctIndex خارج المجال")
    if not item["stem"].strip():
        errs.append("جذع فارغ")
    for r in item.get("optionRules", []):
        if r is not None and r not in rules:
            errs.append(f"قاعدة غير موثّقة: {r}")
    a = item.get("answer")
    if a:
        symbolic = "π" in o[item["correctIndex"]] or "√" in o[item["correctIndex"]]
        if not math.isfinite(a["value"]) or (not symbolic and not nice(a["value"])):
            errs.append("قيمة المفتاح غير نظيفة")
        for i, v in enumerate(item.get("optionValues", [])):
            if i != item["correctIndex"] and v is not None and close(v, a["value"]):
                errs.append("مشتت ضمن حدود التسامح")
    if any(ch in item["stem"] for ch in "{}"):
        errs.append("متغيّر غير معوَّض في الجذع")
    return errs


def sample(pool, n, rng):
    eligible = [i for i in pool if i["type"] != "proof"]
    by_ch = {}
    for it in eligible:
        by_ch.setdefault(it["chapter"], []).append(it)
    total_w = sum(CHAPTER_WEIGHTS[c] for c in by_ch)
    quotas = {c: n * CHAPTER_WEIGHTS[c] / total_w for c in by_ch}
    q_int = {c: int(q) for c, q in quotas.items()}
    for c in sorted(quotas, key=lambda c: quotas[c] - q_int[c], reverse=True)[: n - sum(q_int.values())]:
        q_int[c] += 1
    out = []
    for c, items in by_ch.items():
        by_t = {}
        for it in items:
            by_t.setdefault(it["templateId"], []).append(it)
        for lst in by_t.values():
            rng.shuffle(lst)
        order = sorted(by_t)
        picked = []
        while len(picked) < min(q_int[c], len(items)):
            for tid in order:
                if by_t[tid] and len(picked) < q_int[c]:
                    picked.append(by_t[tid].pop())
        out.extend(picked)
    out.sort(key=lambda i: (i["chapter"], i["templateId"], i["id"]))
    return out


def load_banned():
    if not GLOSSARY.exists():
        return []
    gl = json.loads(GLOSSARY.read_text(encoding="utf-8"))
    banned = gl.get("banned", [])
    return [b["term"] if isinstance(b, dict) else b for b in banned]


def merge_into_pack(items, meta):
    p = json.loads(PACK.read_text(encoding="utf-8"))
    p["items"] = items
    p["itemsMeta"] = meta
    PACK.write_text(json.dumps(p, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--n", type=int, default=100, help="حجم العيّنة")
    ap.add_argument("--per-template", type=int, default=6, help="عدد البنود لكل قالب محسوب")
    ap.add_argument("--pack", action="store_true", help="دمج العيّنة في pack.json تحت items")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    doc = yaml.safe_load(TEMPLATES.read_text(encoding="utf-8"))
    gen = Generator(doc, load_banned(), args.seed)
    pool = gen.generate(args.per_template)
    bad = [(it["templateId"], verify(it, gen.rules)) for it in pool if verify(it, gen.rules)]
    pool = [it for it in pool if not verify(it, gen.rules)]
    smp = sample(pool, args.n, random.Random(args.seed + 1))
    meta = {"generator": "tools/gen_items.py", "templates": str(TEMPLATES.relative_to(ROOT)),
            "templatesVersion": doc["meta"].get("version"), "seed": args.seed, "perTemplate": args.per_template,
            "poolSize": len(pool), "sampleSize": len(smp), "constants": doc.get("constants"),
            "credit": "تم الإشراف على المادة العلمية من قبل الأستاذ القدير فداء مأمون البني",
            "approvedByDefault": False}
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "U1.items.json").write_text(json.dumps({"meta": meta, "items": pool}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (OUT_DIR / f"U1.sample{args.n}.json").write_text(json.dumps({"meta": meta, "items": smp}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if args.pack:
        merge_into_pack(smp, meta)
    if not args.quiet:
        ch = {}
        for it in pool:
            ch[it["chapter"]] = ch.get(it["chapter"], 0) + 1
        print(f"pool: {len(pool)} بنداً {ch} · sample: {len(smp)} · rejected: {len(bad)} · short: {gen.report['short']}")
        for tid, n in gen.report["per_template"].items():
            print(f"  {tid:<16} {n}")
        for tid, why in gen.report["skipped"]:
            print(f"  ⏭ {tid}: {why}")
        for tid, hits in gen.report["banned_hits"]:
            print(f"  ⛔ {tid}: مصطلح محظور {hits}")
        for tid, errs in bad:
            print(f"  ✗ {tid}: {errs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
