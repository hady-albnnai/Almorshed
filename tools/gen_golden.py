#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/gen_golden.py — تصدير تجهيزات ذهبية + أصل قوالب للمحرّك على الجهاز.

المخرجات:
  • app/test/fixtures/gen_golden.json — لكل قالب parts عيّنة توليفات صريحة مع
    مخرَجها الحتميّ الكامل (جذع، أجزاء، سلّم، خيارات كمجموعة، متابعة) أو «رفض».
    محرّك Dart يُغذّى التوليفة نفسها ويجب أن يطابق ⇒ ضمان رياضيّ بلا Dart هنا.
  • app/assets/content/templates.json — قوالب المسائل الـ69 + الثوابت + قواعد
    المشتتات؛ هذا ما يقرأه المحرّك ليولّد بلا حدّ على الجهاز.

المصدر الوحيد للحقيقة هو Generator.from_parts نفسه (المتحقَّق: 69/69 · 22138/22138).
"""
from __future__ import annotations

import glob
import importlib.util
import itertools
import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SAMPLE_PER_TEMPLATE = 60           # توليفات مُنتقاة بتباعد منتظم (تغطّي الأطراف)


def load_generator():
    spec = importlib.util.spec_from_file_location("gi", ROOT / "tools/gen_items.py")
    gi = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gi)
    doc = gi.load_docs()                       # الدمج الرسميّ (rules + constants + templates)
    templates = doc["templates"]
    banned = []
    gpath = ROOT / "app/assets/content/glossary.json"
    if gpath.exists():
        g = json.load(open(gpath, encoding="utf-8"))
        banned = g.get("banned", []) if isinstance(g, dict) else []
    gen = gi.Generator(doc, banned, 2026)
    return gi, gen, doc, templates


def evenly(seq, k):
    """انتقاء ≤k عنصراً بتباعد منتظم يشمل الطرفين."""
    n = len(seq)
    if n <= k:
        return list(seq)
    return [seq[round(i * (n - 1) / (k - 1))] for i in range(k)]


def canon_part(p):
    return {
        "label": p["label"],
        "prompt": p["prompt"],
        "weight": p["weight"],
        "answerText": p["answer"]["text"],
        "answerValue": p["answer"]["value"],
        "answerUnit": p["answer"]["unit"],
        "unitRequired": p["answer"]["unitRequired"],
        "rubric": [{"step": r["step"], "kind": r["kind"], "points": r["points"]} for r in p["rubric"]],
        # الخيارات كمجموعة مرتّبة (ترتيب العرض عشوائيّ ⇒ يُقارَن كمجموعة)
        "optionSet": sorted(p["options"]) if p["options"] else [],
        "correctText": (p["options"][p["correctIndex"]] if p["options"] else None),
    }


def canon_item(it):
    return {
        "stem": it["stem"],
        "weight": it["weight"],
        "parts": [canon_part(p) for p in it["parts"]],
        "followThrough": [
            {"part": ft["part"],
             "accept": [{"dependsOn": a["dependsOn"], "power": a["power"], "scale": a["scale"]}
                        for a in ft["accept"]]}
            for ft in it.get("followThrough", [])
        ],
    }


def main():
    gi, gen, doc, templates = load_generator()
    parts = [t for t in templates if t.get("parts")]
    fixtures = []
    for t in parts:
        vars_ = t.get("vars") or {}
        set_names = [n for n, s in vars_.items() if isinstance(s, dict) and "set" in s]
        if not set_names:
            continue
        combos = list(itertools.product(*[vars_[n]["set"] for n in set_names]))
        combos.sort()
        for combo in evenly(combos, SAMPLE_PER_TEMPLATE):
            base = dict(zip(set_names, combo))
            it = gen.from_parts(t, base)
            entry = {"templateId": t["id"], "chapter": t["chapter"], "vars": base}
            if it is None:
                entry["reject"] = True
            else:
                entry["reject"] = False
                entry["item"] = canon_item(it)
            fixtures.append(entry)

    acc = sum(1 for f in fixtures if not f["reject"])
    out = ROOT / "app/test/fixtures/gen_golden.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    json.dump({"generatedBy": "tools/gen_golden.py", "count": len(fixtures),
               "accepted": acc, "fixtures": fixtures},
              open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"تجهيزات: {len(fixtures)} (مقبول {acc} · مرفوض {len(fixtures) - acc}) ⇒ {out.relative_to(ROOT)}")

    # أصل القوالب للمحرّك: قوالب parts + ثوابت + قواعد المشتتات
    tj = ROOT / "app/assets/content/templates.json"
    json.dump({
        "version": 1,
        "constants": doc.get("constants", {}),
        "namespace": {"g": gi.G, "pi_sq": gi.PI2},
        "distractorRules": doc["schema"]["distractor_rules"],
        "templates": parts,
    }, open(tj, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"قوالب المحرّك: {len(parts)} ⇒ {tj.relative_to(ROOT)}  ({tj.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
