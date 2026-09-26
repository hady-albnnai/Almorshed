#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""اختبارات المحرّك المرجعيّ ومقيّم التعابير (نظائر Dart) — تقفل إثبات المطابقة.

  • test_expr_eval_matches_python_eval: مقيّمنا == eval على كل نداءات توليد الـparts.
  • test_engine_ref_matches_golden: المحرّك المستقلّ (templates.json فقط) == كل
    التجهيزات الذهبية المولّدة من مولّد بايثون المتحقَّق.

إذا انكسر أحدهما فقد انحرفت نواة التوليد ⇒ يلزم إعادة توليد الذهبيّ ومزامنة Dart.
"""
import glob
import importlib.util
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import expr_eval as ee            # noqa: E402
import engine_ref as er           # noqa: E402


def _load_gen():
    spec = importlib.util.spec_from_file_location("gi", ROOT / "tools/gen_items.py")
    gi = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gi)
    doc = gi.load_docs()
    banned = []
    gp = ROOT / "app/assets/content/glossary.json"
    if gp.exists():
        g = json.load(open(gp, encoding="utf-8"))
        banned = g.get("banned", []) if isinstance(g, dict) else []
    return gi, gi.Generator(doc, banned, 2026), doc


def test_expr_eval_matches_python_eval():
    gi, gen, doc = _load_gen()
    parts = [t for t in doc["templates"] if t.get("parts")]
    mism = []
    orig = gi.Generator._ev

    def wrapped(self, expr, env):
        r = orig(self, expr, env)
        try:
            m = ee.evaluate(expr, self._ns(env))
        except Exception as ex:  # noqa: BLE001
            mism.append((expr, "MY_ERR", str(ex)))
            return r
        ok = (m == r) or (isinstance(m, float) and isinstance(r, (int, float))
                          and abs(m - r) <= 1e-9 * max(1, abs(r)))
        if not ok:
            mism.append((expr, r, m))
        return r

    gi.Generator._ev = wrapped
    try:
        for t in parts:
            gen.run_template(t, 40)
    finally:
        gi.Generator._ev = orig
    assert not mism, f"اختلافات المقيّم: {mism[:10]}"


def test_engine_ref_matches_golden():
    asset = json.load(open(ROOT / "app/assets/content/templates.json", encoding="utf-8"))
    gold = json.load(open(ROOT / "app/test/fixtures/gen_golden.json", encoding="utf-8"))
    eng = er.Engine(asset)
    errs = []
    for fx in gold["fixtures"]:
        t = eng.templates[fx["templateId"]]
        got = eng.from_parts(t, fx["vars"])
        if fx["reject"]:
            if got is not None:
                errs.append((fx["templateId"], fx["vars"], "توقّعت رفضاً"))
            continue
        if got is None:
            errs.append((fx["templateId"], fx["vars"], "توقّعت إنتاجاً"))
            continue
        diff = er.deep_eq(er.canon(got), fx["item"])
        if diff:
            errs.append((fx["templateId"], fx["vars"], diff))
    assert not errs, f"اختلافات ذهبية: {errs[:10]}"


def test_golden_asset_is_small():
    """أصل المحرّك يجب أن يبقى صغيراً (توليد لحظيّ لا بنك ضخم)."""
    tj = ROOT / "app/assets/content/templates.json"
    assert tj.exists()
    assert tj.stat().st_size < 400 * 1024, "أصل القوالب تضخّم بغير توقّع"
