# -*- coding: utf-8 -*-
"""v3 حاسم: النهائية PDF مقابل r23 كاملاً (نثر NHTML + 1346 معادلة linear_original).

المنهج — تطبيع محصّن من شوائب طبقة نص الـ PDF:
- NFKC + إزالة التشكيل/التطويل/علامات الاتجاه
- إزالة كل اللامات (شوائب الرّباطات لا/لل في استخراج الـ PDF)
- توحيد الهمزات: أإآٱ→ا · ة→ه · ى→ي
- توحيد الأرقام العربية لللاتينية
المقارنات: كلمات عربية (≥3)، أرقام (tokens)، 4-gram تغطية، عدّادات بنائية.
"""
import json
import re
import unicodedata
from collections import Counter
import fitz
from docx import Document

PDF = "notes/النواسات.pdf"
TXT = "rebuild/nawwasat/content/text.json"
EQ = "rebuild/nawwasat/content/equations.json"
DOCX = "notes/النواسات م_101932-r23-all-absolute-value-bars-green.docx"

STRIP = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200B-\u200F\u2060\u00AD\u2066-\u2069]")

def canon(s: str) -> str:
    s = unicodedata.normalize("NFKC", s)
    s = STRIP.sub("", s)
    s = s.replace("\u0644", "")  # إزالة كل اللامات (حماية من رباطات لا/لل)
    s = re.sub(r"[أإآٱ]", "ا", s)
    s = s.replace("ة", "ه").replace("ى", "ي")
    return s

AR_D = "٠١٢٣٤٥٦٧٨٩"
def digits(s: str) -> str:
    for a, b in zip(AR_D, "0123456789"):
        s = s.replace(a, b)
    return s

ARABIC_W = re.compile(r"[ا-ي]{3,}")
NUM_W = re.compile(r"\d+(?:[.,]\d+)?")

def tokens(s: str):
    c = canon(digits(s))
    return [w for w in c.split() if w], c

# ---------- A: الـ PDF ----------
pdf = fitz.open(PDF)
A_raw = "\n".join(p.get_text() for p in pdf)
A_words, A_flat = tokens(A_raw)

# ---------- B: r23 كامل ----------
blocks = json.load(open(TXT, encoding="utf-8"))["blocks"]
eqs = json.load(open(EQ, encoding="utf-8"))["equations"]
B_parts = [b["text"] for b in blocks]
B_parts += [e["linear_original"] for e in eqs]
# ترويسات/تذييلات الـ docx (رأس "فداء البني" إن وُجد)
doc = Document(DOCX)
for sec in doc.sections:
    for hf in (sec.header, sec.footer, sec.first_page_header, sec.first_page_footer):
        for p in hf.paragraphs:
            B_parts.append(p.text)
B_raw = "\n".join(B_parts)
B_words, B_flat = tokens(B_raw)

print(f"A (PDF النهائي): {pdf.page_count} صفحات · كلمات={len(A_words)} · chars={len(A_flat)}")
print(f"B (r23 كامل):    بلوكات={len(blocks)} · معادلات={len(eqs)} · كلمات={len(B_words)} · chars={len(B_flat)}")

wa, wb = Counter(w for w in A_words if ARABIC_W.search(w)), Counter(w for w in B_words if ARABIC_W.search(w))
print(f"\nكلمات عربية: A={sum(wa.values())}  B={sum(wb.values())}")

only_a, only_b = wa - wb, wb - wa
print(f"\n=== في النهائية زيادة/جديد: {len(only_a)} كلمة مختلفة ===")
for w, c in only_a.most_common(45):
    print(f"  +{c}  {w}")
print(f"\n=== في r23 زيادة/غيّبت: {len(only_b)} كلمة مختلفة ===")
for w, c in only_b.most_common(45):
    print(f"  -{c}  {w}")

na, nb = Counter(NUM_W.findall(digits(canon(A_raw)))), Counter(NUM_W.findall(digits(canon(B_raw))))
print(f"\nأرقام: A={sum(na.values())}  B={sum(nb.values())}")
print("=== أرقام جديدة/أكثر في النهائية ===")
for t, c in (na - nb).most_common(30):
    print(f"  +{c}  {t}")
print("=== أرقام غيّبت/أقل في النهائية ===")
for t, c in (nb - na).most_common(30):
    print(f"  -{c}  {t}")

def ng(s, n=4):
    s = re.sub(r"[^ا-ي0-9]", "", s)
    return set(s[i:i + n] for i in range(len(s) - n + 1))
ga, gb = ng(A_flat), ng(B_flat)
inter = ga & gb
print(f"\n4-gram تغطية: A⊂B={100*len(inter)/len(ga):.1f}%  B⊂A={100*len(inter)/len(gb):.1f}%")

KW = ["المطلوب", "اثبت", "استنتج", "ارسم", "نواس", "مرن", "فتل", "مركب", "بسيط", "مواقت", "ميقاتية"]
print("\n=== عدّادات بنائية ===")
for k in KW:
    kk = canon(k)
    print(f"{k:<12} A={A_flat.count(kk):>5}  B={B_flat.count(kk):>5}")
