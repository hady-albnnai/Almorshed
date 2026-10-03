#!/usr/bin/env python3
# Review screens for U3-06 — طرق حل مسألة النواس البسيط + تطبيقان (map 3.6, blocks 1360–1445)
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
    (X1, SY, "الطرق 1 + 2"),
    (X2, SY, "الطرق 3 + 4"),
    (X3, SY, "تطبيق 1"),
    (X1, SY2, "تطبيق 2"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 3.6 · طرق حل النواس البسيط", "ar")]

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
# S1 — الطرق 1 + 2
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "1) T₀ في السعات الصغيرة",
     [[("T₀ = 2π√(l/g)", "la")],
      [("نعزل المجهول (l أو g أو T₀)", "ar")]],
     250)
card(x, y1+280, w, 2, "2) T₀′ في السعات الكبيرة",
     [[("T₀′ = T₀[1 + (θmax²/16)]", "la")],
      [("θmax بالراد حصراً: ", "ar"), ("0.2 rad", "la"), (" (صغيرة)  ", "ar"), ("0.4, 0.8 rad", "la"), (" (كبيرة)", "ar")],
      [("كلما زادت السعة زاد T₀′", "ar")]],
     300)
card(x, y1+610, w, 3, "ملاحظة",
     [[("السعات الكبيرة: θmax > 0.2 rad تقريباً", "ar")]],
     200)
footer(x, y)

# ================================================================
# S2 — الطرق 3 + 4
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "3) v عند الشاقول أو السعة",
     [[("نظرية الطاقة بين وضعين:", "ar")],
      [("(1/2)v² = g·l·(1 − cosθmax)", "la")]],
     250)
card(x, y1+280, w, 2, "4) التوتر T عند الشاقول",
     [[("−W + T = m·v²/l", "la")],
      [("T = m·[v²/l + g]", "la")]],
     250)
card(x, y1+560, w, 3, "خطوات الحل",
     [[("نحدد المطلوب ⟹ نكتب العلاقة ⟹ نعوض", "ar")],
      [("ونعزل المجهول", "ar")]],
     250)
footer(x, y)

# ================================================================
# S3 — تطبيق 1
# ================================================================
x, y, _ = screens[2]
header(x, y, [("تطبيق 1", "ar")])
pill(x+PW-44, y+186, [("l = 0.4 m", "la"), ("  m = 10⁻¹ kg", "la"), ("  v = 2 m/s", "la")], size=30)
w = PW - 80
y1 = y + 290
card(x, y1, w, 1, "(1) إيجاد θmax",
     [[("(1/2)v² = g·l·(1 − cosθmax)", "la")],
      [("(1/2)×4 = 10×0.4×(1 − cosθmax)", "la")],
      [("cosθmax = 1/2", "la")],
      [("θmax = π/3 rad", "la")]],
     380)
card(x, y1+410, w, 2, "(2) إيجاد T",
     [[("T = m·[v²/l + g]", "la")],
      [("= 10⁻¹·[10 + 10]", "la")],
      [("T = 2 N", "la")]],
     300)
footer(x, y)

# ================================================================
# S4 — تطبيق 2
# ================================================================
x, y, _ = screens[3]
header(x, y, [("تطبيق 2", "ar")])
pill(x+PW-44, y+186, [("h = 0.8 m", "la"), ("  l = 1.6 m", "la"), ("  m = 0.5 kg", "la")], size=30)
w = PW - 80
y1 = y + 290
card(x, y1, w, 1, "(1) v و (2) θmax",
     [[("v = √(2gh) = √(2×10×0.8) = 4 m/s", "la")],
      [("cosθmax = 1 − h/l = 1/2", "la")],
      [("θmax = π/3 rad", "la")],
      [("(3) T₀′ = 2π√(l/g)·[1 + θmax²/16]", "la")]],
     380)
card(x, y1+410, w, 2, "(3) T₀′ و (4) T",
     [[("T₀′ = 2.5×1.07 ≃ 2.673 s", "la")],
      [("T = m·[v²/l + g]", "la")],
      [(": = 0.5×[10 + 10]", "la")],
      [("T = 10 N", "la")]],
     380)
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([("الدور الخاص في السعات الكبيرة:", "ar")],
     ["T₀[1 + θmax²/16]", "T₀[1 − θmax²/16]", "2π√(l/g) فقط", "T₀×θmax"], 0),
    ([("في العلاقة T₀′، θmax يكون:", "ar")],
     ["بالراد حصراً", "بالدرجات", "بأي وحدة", "بلا وحدات"], 0),
    ([("عند θmax = π/3 و l = 0.4 m، v عند الشاقول:", "ar")],
     ["2 m/s", "4 m/s", "1 m/s", "√2 m/s"], 0),
    ([("توتر الخيط عند الشاقول في تطبيق 1:", "ar")],
     ["2 N", "1 N", "4 N", "0.5 N"], 0),
    ([("في تطبيق 2، T₀′ ≈ :", "ar")],
     ["2.673 s", "2.5 s", "1.07 s", "5.3 s"], 0),
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

out = "unit-3.6-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
