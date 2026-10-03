#!/usr/bin/env python3
# Review screens for U3-03 — الاهتزازات غير التوافقية: النواس الثقلي البسيط (map 3.3, blocks 1205–1292)
import review_common as cv

W, H = 2480, 3420
img = cv.make_bg(W, H)
from PIL import ImageDraw
d = ImageDraw.Draw(img)

# ---------------- layout (3 + 2) ----------------
SY, SY2 = 330, 1860
PW, PH  = 760, 1350
X1, X2, X3 = 1640, 850, 60
screens = [
    (X1, SY, "التعريف + التحريكية"),
    (X2, SY, "س2) (a) الانسحابي"),
    (X3, SY, "(b) الدوراني"),
    (X1, SY2, "سعات صغيرة + T₀"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 3.3 · النواس الثقلي البسيط", "ar")]

def header(x, y, title):
    cv.draw_header(x, y, PW, PH, title if isinstance(title, list) else [(title, "ar")], SUB)

def footer(x, y):
    cv.draw_footer(x, y, PW, PH)

def rbox(x, y, w, h, r=34):
    d.rounded_rectangle([x, y, x+w, y+h], radius=r, outline=cv.CARD_BORDER, width=3)

def pill(right_x, y, segs, size=34):
    w = cv.flow_width(segs, size, True)
    pad = 30
    x = right_x - w - 2*pad
    d.rounded_rectangle([x, y, right_x, y+size+34], radius=(size+34)//2,
                        outline=cv.TEAL, width=4)
    cv.draw_flow(right_x - pad, y+17+size-6, segs, size, cv.TEAL, bold=True)

def badge(cx, cy, num, color, r=30, fsize=30):
    d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=color, width=4)
    nw = cv.flow_width([(str(num), "la")], fsize, True)
    cv.draw_flow(cx + nw/2, cy + fsize*0.36, [(str(num), "la")], fsize, color, bold=True)

def card(x, y, w, num, title, lines, h, eq=None):
    d.rounded_rectangle([x, y, x+w, y+h], radius=28, fill=cv.CARD_BG)
    rbox(x, y, w, h)
    badge(x+70, y+66, num, cv.CYAN)
    title_segs = title if isinstance(title, list) else [(title, "ar")]
    tw = cv.flow_width(title_segs, 32, True)
    assert tw <= w - 140, f"card title too wide: {tw}"
    cv.draw_flow(x+w-44, y+48, title_segs, 32, cv.WHITE, bold=True)
    d.line([x+44, y+118, x+w-44, y+118], fill=cv.DIM, width=2)
    ly = y + 150
    last = len(lines) - 1
    for i, segs in enumerate(lines):
        color = cv.TEAL if (eq is None and i == last and last >= 1) else cv.LIGHT
        lw = cv.flow_width(segs, 26)
        assert lw <= w - 100, f"card line too wide: {lw}"
        cv.draw_flow(x+w-44, ly+22, segs, 26, color)
        ly += 38
    if eq:
        eq_segs = eq if isinstance(eq, list) else [(eq, "la")]
        ew = cv.flow_width(eq_segs, 34, True)
        assert ew <= w - 100, f"card eq too wide: {ew}"
        cv.draw_flow(x+w-44, ly+16, eq_segs, 34, cv.CYAN, bold=True)

# ================================================================
# S1 — التعريف + التحريكية + القوى
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "التعريف",
     [[("نظرياً: نقطة مادية كتلتها m تهتز", "ar")],
      [("في مستوى شاقولي على بعد ثابت من محور أفقي", "ar")],
      [("عملياً: كرة صغيرة كثيفة معلقة بخيط", "ar")],
      [("مهمل الكتلة لا يمتط: l كبير بالنسبة لنصف قطر الكرة", "ar")]],
     380)
card(x, y1+410, w, 2, "التحريكية",
     [[("d = oc = l = r", "la")],
      [("d′ = l·sin(θ)", "la")],
      [("ذراع قوة الثقل", "ar")]],
     300)
card(x, y1+740, w, 3, "القوى الخارجية",
     [[("W : ثقل الكرة", "ar")],
      [("T : توتر الخيط", "ar")]],
     250)
footer(x, y)

# ================================================================
# S2 — س2) (a) الانسحابي
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "العلاقة الأساسية",
     [[("ΣF = m·a", "la")],
      [("بالاسقاط على المماس:", "ar")],
      [("−W·sin(θ) = m·α·l", "la")]],
     300)
card(x, y1+330, w, 2, "النتيجة",
     [[("−g·sin(θ) = l·(θ)″", "la")],
      [("(θ)″ = −(g/l)·sin(θ)", "la")],
      [("لا تقبل حلاً جيبياً (sinθ بدلاً من θ)", "ar")]],
     300)
footer(x, y)

# ================================================================
# S3 — (b) الدوراني
# ================================================================
x, y, _ = screens[2]
header(x, y, screens[2][2])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "العلاقة الأساسية",
     [[("ΣΓ = IΔ·α  (IΔ = m·l²)", "la")],
      [("Γ_T = 0", "la"), ("  لأن حاملها يلاقي محور الدوران", "ar")],
      [("−m·g·l·sin(θ) = m·l²·(θ)″", "la")],
      [("(θ)″ = −(g/l)·sin(θ)", "la"), ("  (نفس النتيجة)", "ar")]],
     380)
card(x, y1+410, w, 2, "غير توافقية",
     [[("لوجود sinθ بدلاً من θ", "ar")],
      [("⟹ حركة النواس الثقلي البسيط غير توافقية", "ar")]],
     250)
footer(x, y)

# ================================================================
# S4 — سعات صغيرة + T₀
# ================================================================
x, y, _ = screens[3]
header(x, y, screens[3][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "سعات صغيرة",
     [[("θ ≤ 0.24 rad", "la"), (" أو ", "ar"), ("θ ≤ 14°", "la"), (" ⟹ ", "la"), ("sinθ ≃ θ", "la")],
      [("(θ)″ = −(g/l)·θ  …(*)", "la")],
      [("تقبل حلاً جيبياً", "ar")]],
     300)
card(x, y1+330, w, 2, "المقارنة",
     [[("ω₀² = g/l  ⟹  ω₀ = √(g/l) > 0", "la")],
      [("لأن g و l موجبان تماماً", "ar")],
      [("حركة جيبية دورانية في السعات الصغيرة فقط", "ar")]],
     300)
card(x, y1+660, w, 3, "الدور الخاص", [], 200, eq="T₀ = 2π√(l/g) (s)")
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([("النواس الثقلي البسيط عملياً:", "ar")],
     ["كرة صغيرة معلقة بخيط مهمل الكتلة لا يمتط", "كرة مثبتة بنابض", "قرص معلق بمحوره", "ساق معلقة بأحد طرفيه"], 0),
    ([("القوى الخارجية المؤثرة في الكرة:", "ar")],
     ["ثقل الكرة + توتر الخيط", "ثقل الكرة فقط", "توتر الخيط فقط", "ثقل + توتر + قوة مركزية"], 0),
    ([("المعادلة التفاضلية (قبل التقريب):", "ar")],
     ["(θ)″ = -(g/l)·sinθ", "(θ)″ = -(g/l)·θ", "(θ)″ = -(l/g)·sinθ", "(θ)″ = -ω₀²·sinθ"], 0),
    ([("الدور الخاص (سعات صغيرة):", "ar")],
     ["2π√(l/g) (s)", "2π√(g/l) (s)", "√(l/g) (s)", "2π/(g·l) (s)"], 0),
    ([("جعلنا l أربع أمثالها فتصبح T₀ (T₀~√l):", "ar")],
     ["2T₀", "T₀/2", "4T₀", "T₀ نفسها"], 0),
]
qh = 190
for i, (qsegs, opts, ans) in enumerate(qs):
    d.rounded_rectangle([x, qy, x+PW, qy+qh], radius=26, fill=cv.CARD_BG)
    rbox(x, qy, PW, qh)
    badge(x+58, qy+36, i+1, cv.CYAN, r=24, fsize=24)
    qw = cv.flow_width(qsegs, 26)
    assert qw <= PW - 160, f"q too wide: {qw}"
    cv.draw_flow(x+PW-44, qy+44, qsegs, 26, cv.WHITE)
    oy = qy + 56
    for j, opt in enumerate(opts):
        sel = j == ans
        fill = cv.TEAL_BG if sel else cv.CARD_BG2
        d.rounded_rectangle([x+60, oy, x+PW-60, oy+30], radius=15,
                            fill=fill, outline=cv.TEAL if sel else cv.CARD_BORDER,
                            width=3 if sel else 2)
        d.ellipse([x+74, oy+6, x+90, oy+22], outline=cv.TEAL if sel else cv.DIM, width=3)
        d.text((x+82, oy+10), "أبجد"[j], font=cv.load_ar(18), anchor="lm",
               fill=cv.TEAL if sel else cv.DIM)
        if sel:
            d.text((x+PW-84, oy+9), "✓", font=cv.load_la(20, bold=True), anchor="rm", fill=cv.TEAL)
        if isinstance(opt, list):
            osegs = opt
        else:
            osegs = [(opt, "ar" if cv.has_arabic(opt) else "la")]
        ow = cv.flow_width(osegs, 22)
        assert ow <= PW - 200, f"opt too wide: {ow}"
        cv.draw_flow(x+PW-116, oy+21, osegs, 22, cv.WHITE if sel else cv.LIGHT, bold=sel)
        oy += 34
    qy += qh + 8
footer(x, y)

out = "unit-3.3-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
