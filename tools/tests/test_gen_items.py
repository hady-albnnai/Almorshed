# -*- coding: utf-8 -*-
"""اختبارات المولّد tools/gen_items.py — تُشغَّل بـ: python3 -m pytest tools/tests -q"""
import json
import math
import random
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import gen_items as gi  # noqa: E402


@pytest.fixture(scope="module")
def doc():
    return yaml.safe_load(gi.TEMPLATES.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def pool(doc):
    gen = gi.Generator(doc, gi.load_banned(), seed=2026)
    items = gen.generate(per_template=6)
    return gen, items


# ── أدوات التنسيق ──
def test_fmt_and_nice():
    assert gi.fmt(0.5) == "0.5" and gi.fmt(2.0) == "2" and gi.fmt(-0.4) == "−0.4"
    assert gi.nice(0.625) and gi.nice(5.6) and gi.nice(4)
    assert not gi.nice(2.3094) and not gi.nice(1 / 3)


def test_ratio_and_pi_strings():
    assert gi.ratio_str(0.5, "T0") == "T0/2"
    assert gi.ratio_str(2, "T0") == "2·T0"
    assert gi.ratio_str(math.sqrt(2), "T0") == "√2·T0"
    assert gi.ratio_str(1 / math.sqrt(2), "T0") == "T0/√2"
    assert gi.ratio_str(math.sqrt(2 / 3), "T0") == "√(2/3)·T0"
    assert gi.pi_str(gi.Fraction(1, 2)) == "π/2" and gi.pi_str(2) == "2π" and gi.pi_str(gi.Fraction(-1, 3)) == "−π/3"
    assert gi.sqrt_str(10) == "√10" and gi.sqrt_str(gi.Fraction(1, 4)) == "0.5"


def test_formula_transforms_never_return_key():
    key = "T0 = 2π·√(m/k)"
    ds = gi.formula_transforms(key)
    assert ds and all(d[0] != key for d in ds)
    rules = {d[1] for d in ds}
    assert {"invert_ratio", "forget_2pi", "forget_sqrt"} <= rules


# ── سلامة المخرجات ──
def test_pool_is_nontrivial_and_valid(pool):
    gen, items = pool
    assert len(items) >= 250
    for it in items:
        assert gi.verify(it, gen.rules) == [], (it["templateId"], gi.verify(it, gen.rules))
        assert it["approved"] is False
        assert it["unit"] == "U1" and it["chapter"] in gi.CHAPTER_WEIGHTS


def test_every_option_has_documented_rule_and_rationale(pool):
    gen, items = pool
    for it in items:
        if it["type"] == "proof":
            continue
        assert len(it["options"]) == 4
        assert len(it["solutionSteps"]) == 4
        for i, r in enumerate(it["optionRules"]):
            if i == it["correctIndex"]:
                assert r is None and it["solutionSteps"][i].startswith("✓")
            else:
                assert r in gen.rules, r
                assert it["solutionSteps"][i].startswith("(")


def test_no_banned_terms(pool):
    gen, items = pool
    banned = gen.banned
    for it in items:
        text = it["stem"] + " ".join(it["options"])
        assert not any(b in text for b in banned), it["templateId"]


def test_numeric_distractors_outside_tolerance(pool):
    _, items = pool
    for it in items:
        a = it.get("answer")
        if not a:
            continue
        for i, v in enumerate(it["optionValues"]):
            if i != it["correctIndex"] and v is not None:
                assert not gi.close(v, a["value"]), (it["templateId"], it["options"])


def test_all_of_above_is_last_option(pool):
    _, items = pool
    for it in items:
        if it["type"] == "proof":
            continue
        for i, o in enumerate(it["options"]):
            if o.startswith("جميع ما سبق"):
                assert i == 3 and it["correctIndex"] == 3


def test_correct_index_is_spread(pool):
    _, items = pool
    counts = [0, 0, 0, 0]
    for it in items:
        if it["type"] != "proof" and not it["options"][it["correctIndex"]].startswith("جميع"):
            counts[it["correctIndex"]] += 1
    assert min(counts) >= 0.15 * sum(counts), counts


def test_deterministic_by_seed(doc):
    a = gi.Generator(doc, [], 7).generate(3)
    b = gi.Generator(doc, [], 7).generate(3)
    assert [(i["stem"], i["options"]) for i in a] == [(i["stem"], i["options"]) for i in b]


def test_figure_templates_are_skipped(pool):
    gen, items = pool
    skipped = {tid for tid, why in gen.report["skipped"] if why == "needs_figure"}
    assert {"U1.L1.T20", "U1.L2.T13", "U1.L3.T15"} <= skipped
    assert not any(it["templateId"] in skipped for it in items)


def test_pending_table_row_not_generated(pool):
    _, items = pool
    assert not any("بدلالة أبعاده" in it["stem"] for it in items)   # صف C_wire معلّق للأستاذ


# ── تحقق فيزيائي من مفاتيح مرجعية (الكتاب/امتحان ٢٠٢٦) ──
def _find(items, tid, needle):
    return [it for it in items if it["templateId"] == tid and needle in it["stem"]]


def test_reference_values(pool):
    _, items = pool
    # مسألة ٢٠٢٦: L = 0.8 m ⇒ T0 = 2 s
    for it in _find(items, "U1.L3.T10", "L = 0.8 m"):
        if "دوره الخاص T0" in it["stem"]:
            assert abs(it["answer"]["value"] - 2.0) < 1e-9
    # ٢٠٢٦ س١-١: ربع طول السلك ⇒ نصف الدور
    for it in _find(items, "U1.L2.T06", "ربع ما كان"):
        assert it["options"][it["correctIndex"]] == "T0/2"
    # مثال الكتاب: 0.1 kg، l = 0.4 m، 60° ⇒ T عند الشاقول = 2 N
    for it in _find(items, "U1.L3.T08", "0.1 kg وطول خيطه 0.4 m، يُزاح عن الشاقول بزاوية 60°"):
        if "لحظة المرور بوضع التوازن الشاقولي" in it["stem"] and "توتر" in it["stem"]:
            assert abs(it["answer"]["value"] - 2.0) < 1e-9


def test_sampling_respects_weights(pool):
    _, items = pool
    smp = gi.sample(items, 100, random.Random(1))
    assert len(smp) == 100
    ch = {c: sum(1 for i in smp if i["chapter"] == c) for c in gi.CHAPTER_WEIGHTS}
    assert ch["U1C1"] >= ch["U1C2"] >= ch["U1C3"]
    assert len({i["id"] for i in smp}) == 100


def test_pack_compatible_fields(pool):
    _, items = pool
    need = {"id", "unit", "chapter", "approved", "stem", "options", "correctIndex", "solutionSteps", "followThrough"}
    for it in items:
        assert need <= set(it), it["templateId"]
        assert isinstance(it["id"], int)
    json.dumps(items, ensure_ascii=False)
