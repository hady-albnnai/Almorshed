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
        if it.get("grading") == gi.GRADING_PARTS:      # الأجزاء: خيارات داخل كل جزء
            for part in it["parts"]:
                if part["options"]:
                    assert len(part["options"]) == 4 and len(part["solutionSteps"]) == 4
                    for i, r in enumerate(part["optionRules"]):
                        if i == part["correctIndex"]:
                            assert r is None and part["solutionSteps"][i].startswith("✓")
                        else:
                            assert r in gen.rules, r
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
        if it.get("grading") == gi.GRADING_PARTS:          # بند أجزاء: لا مفتاح مسطّح يُنتشر
            continue
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


# ── المحرّك العام متعدد الوحدات (قوالب U1b / U2 / U3-U5) ──

@pytest.fixture(scope="module")
def all_pool():
    doc = gi.load_docs()
    gen = gi.Generator(doc, gi.load_banned(), seed=2026)
    return gen, gen.generate(per_template=6)


def test_load_docs_merges_all_units(all_pool):
    gen, items = all_pool
    chapters = {i["chapter"] for i in items}
    assert chapters == set(gi.CHAPTER_WEIGHTS), chapters - set(gi.CHAPTER_WEIGHTS)
    assert len(items) >= 500
    # كل قاعدة مشتت في كل ملف موثّقة (وإلا رفع make ValueError أثناء التوليد)
    assert all(r is None or r in gen.rules for i in items for r in i.get("optionRules") or [])


def test_all_units_verify_clean(all_pool):
    gen, items = all_pool
    bad = [(i["templateId"], gi.verify(i, gen.rules)) for i in items if gi.verify(i, gen.rules)]
    assert bad == []
    hits = [i["templateId"] for i in items if any(b in " ".join([i["stem"]] + i["options"]) for b in gen.banned)]
    assert hits == []


def test_fmt_sci_and_nice_sci():
    assert gi.fmt_sci(5.93e6) == "5.93×10⁶"
    assert gi.fmt_sci(1e-3) == "10⁻³"
    assert gi.fmt_sci(2.5, 3) == "2.5"
    assert gi.nice_sci(7.5e6) and gi.nice_sci(1.24e-11)
    assert not gi.nice_sci(5929994.53)


def test_ratio_str_pulls_squares():
    assert gi.ratio_str(gi.math.sqrt(15) / 4, "c") == "√15·c/4"
    assert gi.ratio_str(gi.math.sqrt(8) / 3, "c") == "2√2·c/3"
    assert gi.ratio_str(0.5, "T0") == "T0/2"


def test_curriculum_anchor_values(all_pool):
    _, items = all_pool
    # U2: طومسون — 100 mH و10 μF ⇒ T0 = 6.28 ms
    for it in _find(items, "U2.L4.T01", "100 mH ومكثفة سعتها 10 μF"):
        if "الدور الخاص" in it["stem"]:
            assert abs(it["answer"]["value"] - 6.28e-3) < 1e-6
    # U3: مزمار مختلف 17 cm ⇒ f1 = 500 Hz والتالي 1500 Hz
    for it in _find(items, "U3.L2.T01", "مختلف الطرفين (مغلق من أحد طرفيه) طوله 17 cm"):
        assert min(abs(it["answer"]["value"] - v) for v in (500.0, 1500.0)) < 1e-6
    # U4: بور 2→1 ⇒ 10.2 eV
    for it in _find(items, "U4.L1.T01", "من السوية n = 2 إلى السوية n = 1"):
        assert abs(it["answer"]["value"] - 10.2) < 1e-9
    # U5: هابل 70 × 100 Mpc ⇒ 7000 km/s
    for it in _find(items, "U5.L1.T01", "H0 = 70 km·s⁻¹·Mpc⁻¹. مجرة تبعد عنا 100 Mpc"):
        assert abs(it["answer"]["value"] - 7000) < 1e-9


# ─────────────────────────── المسألة بأجزاء — parts-v1 (قرار ٦٨) ───────────────────────────

def _parts(items):
    return [i for i in items if i.get("grading") == gi.GRADING_PARTS]


def test_parts_templates_exist_in_two_units(all_pool):
    _, items = all_pool
    pr = _parts(items)
    assert pr, "لا بند أجزاء واحد — القوالب لم تُقرأ"
    assert {i["unit"] for i in pr} >= {"U1", "U2"}
    assert {i["type"] for i in pr} == {"problem"}


def test_parts_weights_and_rubric_are_coherent(all_pool):
    _, items = all_pool
    for it in _parts(items):
        assert len(it["parts"]) >= 2
        assert sum(p["weight"] for p in it["parts"]) == it["weight"]      # وزن البند = مجموع أجزائه
        assert sum(r["points"] for r in it["rubric"]) == it["weight"]       # السلّم لا يزيف الوزن
        for p in it["parts"]:
            assert sum(r["points"] for r in p["rubric"]) == p["weight"]
            assert p["prompt"] or p["options"]                              # لا جزء بلا مطلوب
            a = p["answer"]
            assert a["value"] is not None or p["options"]                   # لا جزء لا يُصحَّح
            assert a["unit"] or not a["unitRequired"]
            if p["options"]:
                assert a["text"] in p["options"] and p["correctIndex"] == p["options"].index(a["text"])


def test_parts_have_no_flat_answer(all_pool):
    _, items = all_pool
    for it in _parts(items):
        assert it["options"] == [] and it["correctIndex"] == -1 and it["answer"] is None
        assert it["followThrough"] and all(f["part"] for f in it["followThrough"])


def test_follow_through_scale_reproduces_the_key(all_pool):
    gen, items = all_pool
    for it in _parts(items):
        by_ref = {str(p["label"]): p for p in it["parts"]}
        by_ref.update({p["n"]: p for p in it["parts"]})
        for p in it["parts"]:
            f = p.get("followThrough")
            if not f:
                continue
            for acc in f["accept"]:
                dep = by_ref[acc["dependsOn"]]
                got = acc["scale"] * float(dep["answer"]["value"]) ** float(acc["power"])
                want = float(p["answer"]["value"])
                assert abs(got - want) <= 1e-9 * max(1.0, abs(want)), (it["templateId"], p["label"], got, want)
                # المتابعة معنى حقيقي: خطأ في الجزء السابق ⇒ قيمة مقبولة != المفتاح
                wrong = acc["scale"] * (float(dep["answer"]["value"]) * 1.5) ** float(acc["power"])
                assert not gi.close(wrong, want), (it["templateId"], p["label"])


def test_parts_items_pass_verify(all_pool):
    gen, items = all_pool
    assert [(i["templateId"], gi.verify(i, gen.rules)) for i in _parts(items) if gi.verify(i, gen.rules)] == []


def test_parts_do_not_shift_flat_ids(all_pool):
    """قوالب الأجزاء تُشغَّل آخر القائمة ⇒ معرّفات البنود القديمة لا تتزحزح (مراجعة الأستاذ ورقية)."""
    gen, items = all_pool
    flat = [i for i in items if i.get("grading") != gi.GRADING_PARTS]
    pr = _parts(items)
    assert max(i["id"] for i in flat) < min(i["id"] for i in pr)
    assert flat[0]["id"] == gi.FIRST_ID and flat[0]["templateId"] == "U1.L1.T01"


@pytest.fixture(scope="module")
def u1_parts_only():
    """القالب U1.L3.P01 وحده بمحرّك جديد — السحب المرجعي يتكرر حتمياً (البذرة 2026)."""
    doc = yaml.safe_load(gi.TEMPLATES.read_text(encoding="utf-8"))
    gen = gi.Generator(doc, gi.load_banned(), seed=2026)
    t = [x for x in doc["templates"] if x["id"] == "U1.L3.P01"][0]
    return gen, gen.run_template(t, 6)


def test_exam_anchored_compound_pendulum_values(u1_parts_only):
    """مسألة ٢٠٢٦ الأولى: L = 0.8 m وm1 = m2 وd = L/4 ⇒ T0 = 2 s · ℓ = 1 m · ω = √10 (docs/20 §٦)."""
    gen, items = u1_parts_only
    assert items
    hit = [it for it in items if "0.8 m" in it["stem"] and "60°" in it["parts"][2]["prompt"]]
    assert hit, "لم يُولَّد السحب المرجعي (L = 0.8 m، θmax = 60°)"
    it = hit[0]
    T0, l_eq, w = (p["answer"]["value"] for p in it["parts"])
    assert abs(T0 - 2.0) < 1e-9 and abs(l_eq - 1.0) < 1e-9
    assert it["parts"][2]["answer"]["text"] == "√10 rad·s⁻¹" and abs(w - 10 ** 0.5) < 1e-9
    assert all(gi.verify(i, gen.rules) == [] for i in items)


def test_compound_pendulum_physics_holds_for_every_draw(u1_parts_only):
    """كل سحب يجب أن يحقق: T0 = √(5L) · ℓ = 1.25·L = T0²/4 · ω² = 8/L عند 60° و16/L عند 90°."""
    gen, items = u1_parts_only
    for it in items:
        L = float(gi.re.search(r"طولها ([\d.]+) m", it["stem"]).group(1))
        th = int(gi.re.search(r"بزاوية[^0-9]*(\d+)°", it["parts"][2]["prompt"]).group(1))
        T0, l_eq, w = (p["answer"]["value"] for p in it["parts"])
        assert abs(T0 - math.sqrt(5 * L)) < 1e-9, it["id"]
        assert abs(l_eq - 1.25 * L) < 1e-9, it["id"]
        assert abs(l_eq - T0 * T0 / 4) < 1e-9, it["id"]                  # هوية السلم (ℓ = g(T0/2π)²)
        assert abs(w * w - (2.0 if th == 90 else 1.0) * 8 / L) < 1e-9, (it["id"], th)


def test_ac_chain_consistency(all_pool):
    """U = Z·I و P = U·I·cos φ = R·I² — الطريقان يجب أن يتفقا عددياً في كل بند مولَّد."""
    _, items = all_pool
    for it in _parts(items):
        if it["templateId"] != "U2.L5.P01":
            continue
        Z, I, cosf, P = (p["answer"]["value"] for p in it["parts"])
        import re as _re
        U = float(_re.search(r"Ueff = ([\d.]+) V", it["stem"]).group(1))
        R = float(_re.search(r"R = ([\d.]+) Ω", it["stem"]).group(1))
        assert abs(U - Z * I) < 1e-6 * max(1.0, U)
        assert abs(P - U * I * cosf) < 1e-6 * max(1.0, P)
        assert abs(P - R * I * I) < 1e-6 * max(1.0, P)


def test_verify_rejects_tampered_parts(all_pool):
    gen, items = all_pool
    good = _parts(items)[0]
    bad = json.loads(json.dumps(good))
    bad["parts"][0]["weight"] += 1
    assert any("أوزان الأجزاء" in e or "الوزن" in e for e in gi.verify_parts(bad, gen.rules)), gi.verify_parts(bad, gen.rules)
    bad2 = json.loads(json.dumps(good))
    ft = bad2["parts"][1]["followThrough"]["accept"][0]
    ft["scale"] *= 1.5
    assert any("المتابعة" in e for e in gi.verify_parts(bad2, gen.rules)), gi.verify_parts(bad2, gen.rules)
    bad3 = json.loads(json.dumps(good))
    bad3["answer"] = {"value": 1.0, "unit": "s", "text": "1 s"}          # مفتاح مسطّح ممنوع على بند أجزاء
    assert any("مسطّح" in e for e in gi.verify_parts(bad3, gen.rules)), gi.verify_parts(bad3, gen.rules)


def test_asset_excludes_parts_until_rubric_grading_lands(tmp_path, monkeypatch, capsys):
    orig = (gi.OUT_DIR, gi.ITEMS_ASSET)
    gi.OUT_DIR, gi.ITEMS_ASSET = tmp_path, tmp_path / "items.json"
    try:
        gi.main(["--quiet", "--asset", "--seed", "2026", "--per-template", "1", "--n", "10"])
        shipped = json.loads((tmp_path / "items.json").read_text(encoding="utf-8"))
        assert shipped["meta"]["partsExcluded"] is True
        assert all(i.get("grading") != gi.GRADING_PARTS for i in shipped["items"])
        assert shipped["meta"]["partsPool"] > 0                       # مذكور في الوصف وإن لم يُشحن
        gi.main(["--quiet", "--asset", "--parts-asset", "--seed", "2026", "--per-template", "1", "--n", "10"])
        shipped2 = json.loads((tmp_path / "items.json").read_text(encoding="utf-8"))
        assert any(i.get("grading") == gi.GRADING_PARTS for i in shipped2["items"])
    finally:
        gi.OUT_DIR, gi.ITEMS_ASSET = orig
