#!/usr/bin/env python3
"""content/authoring/U*/L*.md  →  app/assets/content/pack.json

قواعد التحويل (التطبيق يعرض نصاً عادياً، لا Markdown):
- كل عنوان `## ` في الدرس = فقرة (Paragraph): text = محتوى القسم مسطّحاً،
  summary = أول سطر معنوي في القسم (أو صف الخلاصة المقابل).
- الجداول تُسطَّح إلى أسطر «عمود١ — عمود٢ — …».
- `<details>` تصبح «الحل: …».
- 🎯 اختبر نفسك: كل «**سN.**» بأربعة خيارات (A)–(D) وعلامة ✓ ⇒ Question (approved:false).
  الأسئلة المفتوحة («> جواب») تصبح بطاقات.
- 🧾 خلاصة: كل صف ⇒ Card (front = الوصف، back/formula = الصيغة).
- كل الأسئلة approved:false حتى مراجعة الأستاذ.
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "authoring"
OUT = ROOT / "app" / "assets" / "content" / "pack.json"

UNIT_TITLES = {
    "U1": "الوحدة الأولى: الحركة والتحريك",
    "U2": "الوحدة الثانية: الكهرباء والمغناطيسية",
    "U3": "الوحدة الثالثة: الأمواج المستقرة",
    "U4": "الوحدة الرابعة: الفيزياء الحديثة",
    "U5": "الوحدة الخامسة: الفيزياء الفلكية (إثرائية)",
}
AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def ar2int(s: str) -> int:
    return int(s.translate(AR_DIGITS))


def clean_inline(s: str) -> str:
    s = re.sub(r"\n\s*-\s*$", "", s)
    s = s.replace("**", "")
    s = re.sub(r"<details><summary>(.*?)</summary>(.*?)</details>", r"\1: \2", s, flags=re.S)
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"(?<!\w)\*(.+?)\*(?!\w)", r"\1", s)
    s = s.replace("`", "")
    s = re.sub(r"\[(.+?)\]\((.+?)\)", r"\1", s)
    s = re.sub(r"^>\s?", "", s)
    s = s.replace("▢", "___")
    return s.strip()


def flatten_table(rows: list[str]) -> list[str]:
    out = []
    header = None
    for r in rows:
        cells = [clean_inline(c) for c in r.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c.strip()) or c.strip() == "" for c in cells):
            continue
        if header is None:
            header = cells
            if any(h for h in header):
                out.append(" — ".join(h for h in header if h))
            continue
        out.append(" — ".join(c for c in cells if c))
    return out


def flatten_block(lines: list[str]) -> str:
    out, table = [], []
    for ln in lines:
        if ln.strip().startswith("|"):
            table.append(ln)
            continue
        if table:
            out.extend("• " + t for t in flatten_table(table))
            table = []
        s = clean_inline(ln)
        if not s or s == "---":
            continue
        if re.match(r"^#{3,}\s", ln):
            s = "\n" + re.sub(r"^#+\s*", "", s)
        elif re.match(r"^\s*[-*]\s", ln):
            s = "• " + re.sub(r"^\s*[-*]\s+", "", s)
        elif re.match(r"^\s*\d+\.\s", ln):
            s = re.sub(r"^\s*(\d+)\.\s+", r"\1) ", s)
        out.append(s)
    if table:
        out.extend("• " + t for t in flatten_table(table))
    return "\n".join(out).strip()


def split_sections(md: str):
    """[(title, [lines])] على مستوى ## ."""
    secs, cur, buf = [], None, []
    for ln in md.split("\n"):
        if ln.startswith("## "):
            if cur is not None:
                secs.append((cur, buf))
            cur, buf = ln[3:].strip(), []
        elif cur is not None:
            buf.append(ln)
    if cur is not None:
        secs.append((cur, buf))
    return secs


def parse_lesson(path: Path):
    md = path.read_text(encoding="utf-8")
    title = md.split("\n", 1)[0].lstrip("# ").strip()
    m = re.search(r"ص\s*([٠-٩\d]+)", md)
    page = ar2int(m.group(1)) if m else 0
    lesson_title = title.split(":", 1)[1].strip() if ":" in title else title
    head = ""
    for ln in md.split("\n")[1:12]:
        if ln.startswith(">"):
            head = clean_inline(ln)
            break
    return lesson_title, page, head, split_sections(md)


def parse_mcq(lines: list[str]):
    """يدعم شكلين: (١) خيارات على أسطر «- (A) …» مع تعليل بعد ⟵؛ (٢) خيارات في سطر واحد مفصولة بـ ·."""
    qs, opens = [], []
    text = "\n".join(lines)
    for m in re.finditer(r"\*\*س([٠-٩\d]+)\.\*\*\s*(.+?)(?=\n\*\*س|\Z)", text, flags=re.S):
        body = m.group(2).strip()
        # قسّم عند كل (X)
        parts = re.split(r"(?:^|\s|\*\*|·|-\s)\(([A-Da-d])\)\s*", body)
        if len(parts) >= 9:  # stem + 4×(letter, text)
            stem = clean_inline(parts[0]).rstrip(":：").strip()
            options, expl, correct = [], [], -1
            for i in range(1, 9, 2):
                raw = parts[i + 1]
                is_correct = "✓" in raw
                raw = raw.replace("✓", "")
                # تعليل بعد ⟵ أو بعد « — » للخيار الصحيح
                note = ""
                if "⟵" in raw:
                    raw, _, note = raw.partition("⟵")
                elif is_correct and " — " in raw:
                    raw, _, note = raw.partition(" — ")
                raw = re.sub(r"\s*\[[^\]]*\]\s*", " ", raw)  # [أستاذ ص ٢١٦]
                opt = clean_inline(raw).strip(" ·*—-.").strip()
                opt = opt.split("\n")[0].strip()
                options.append(opt)
                note = re.sub(r"\s*\[[^\]]*\]\s*", " ", clean_inline(note)).strip(" .*-\n")
                if note:
                    expl.append(("✓ " if is_correct else f"({'ABCD'[(i-1)//2]}) خطأ: ") + note)
                if is_correct:
                    correct = (i - 1) // 2
            if correct >= 0 and all(options):
                qs.append((stem, options, correct, expl))
            continue
        if ">" in body:
            q, _, a = body.partition(">")
            opens.append((clean_inline(q).rstrip(":").strip(), clean_inline(a)))
    return qs, opens


def parse_summary_cards(lines: list[str]):
    cards = []
    for r in lines:
        if not r.strip().startswith("|"):
            continue
        cells = [clean_inline(c) for c in r.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) or c == "" for c in cells):
            continue
        cells = [c for c in cells if c]
        if not cells or cells[0] in ("القانون", "العلاقة", "الصيغة") or cells[-1] in ("متى أستخدمه", "ملاحظة", "السياق"):
            continue
        formula, label = cells[0], (cells[1] if len(cells) > 1 else "")
        front = label if label else "ما العلاقة/القاعدة؟"
        cards.append({"front": f"{front} — أكمل: {formula.split('·')[0][:40]}…" if len(formula) > 60 else front, "back": formula, "formula": formula.split("\n")[0]})
    return cards


def build():
    units, questions, cards = [], [], []
    qid, cid = 1000, 5000
    for udir in sorted(SRC.glob("U*")):
        uid = udir.name
        chapters = []
        for i, lpath in enumerate(sorted(udir.glob("L*.md")), start=1):
            chid = f"{uid}C{i}"
            ltitle, page, head, secs = parse_lesson(lpath)
            paragraphs = []
            pi = 0
            for stitle, slines in secs:
                if stitle.startswith("🎯"):
                    mcq, opens = parse_mcq(slines)
                    for stem, opts, corr, expl in mcq:
                        qid += 1
                        questions.append({
                            "id": qid, "unit": uid, "chapter": chid, "approved": False,
                            "stem": stem, "options": opts, "correctIndex": corr,
                            "solutionSteps": expl,
                            "followThrough": [],
                        })
                    for q, a in opens:
                        cid += 1
                        cards.append({"id": cid, "unit": uid, "chapter": chid, "front": q, "back": a})
                    continue
                if stitle.startswith("🧾"):
                    for c in parse_summary_cards(slines):
                        cid += 1
                        cards.append({"id": cid, "unit": uid, "chapter": chid, **c})
                    # الخلاصة تبقى أيضاً فقرة أخيرة للقراءة
                text = flatten_block(slines)
                if not text:
                    continue
                pi += 1
                first = next((l for l in text.split("\n") if l and not l.startswith("•")), text.split("\n")[0])
                summary = first[:160]
                paragraphs.append({
                    "id": f"{chid}P{pi}",
                    "text": text,
                    "summary": clean_inline(stitle) + (" — " + summary if summary and summary != stitle else ""),
                })
            if head:
                paragraphs.insert(0, {"id": f"{chid}P0", "text": head, "summary": "مصادر الدرس ووزنه في امتحان ٢٠٢٦"})
            chapters.append({"id": chid, "title": ltitle, "page": page, "paragraphs": paragraphs})
        units.append({"id": uid, "title": UNIT_TITLES.get(uid, uid), "chapters": chapters})
    pack = {"packId": "syria-2027-v2", "year": 2027, "edition": 2,
            "units": units, "questions": questions, "cards": cards}
    return pack


if __name__ == "__main__":
    pack = build()
    OUT.write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    nP = sum(len(c["paragraphs"]) for u in pack["units"] for c in u["chapters"])
    print(f"units={len(pack['units'])} chapters={sum(len(u['chapters']) for u in pack['units'])} "
          f"paragraphs={nP} questions={len(pack['questions'])} cards={len(pack['cards'])} → {OUT.relative_to(ROOT)}")
    for u in pack["units"]:
        print(u["id"], [(c["id"], c["page"], len(c["paragraphs"])) for c in u["chapters"]])
