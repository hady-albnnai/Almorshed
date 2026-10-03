#!/usr/bin/env python3
# Review screens for U2-06 — نواس الفتل: أمثلة تغيّر طول سلك الفتل (map 2.6, blocks 885–937)
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
    (X1, SY, "مثال 1: الطول أربع أمثال"),
    (X2, SY, "مثال 2: الدور مثلي"),
    (X3, SY, "مثال 3: T₀ = 2 (s)"),
    (X1, SY2, "نسبة الدورين + إعادة السؤال"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.6 · نواس الفتل", "ar")]

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

def example_screen(scr, pilltext, q_lines, sol_lines, sol_h, ans_segs):
    x, y, _ = scr
    header(x, y, scr[2])
    w = PW - 80
    y1 = y + 270
    card(x, y1, w, 1, "المسألة", q_lines, 260)
    card(x, y1+290, w, 2, "الحل", sol_lines, sol_h, eq=None)
    pill(x+PW-44, y+PH-260, ans_segs)
    footer(x, y)

# ================================================================
# S1 — مثال 1
# ================================================================
example_screen(
    screens[0], "T₀₂ = √(l₂/l₁)·T₀₁",
    [[("نواس فتل دوره الخاص ", "ar"), ("T₀₁", "la")],
     [("نجعل طول سلك الفتل أربع أمثال ما كان عليه:", "ar")],
     [("فيصبح دوره الخاص الجديد:", "ar")]],
    [[("l₂ = 4l₁", "la"), ("  ⟹  ", "la"), ("T₀₂ = √4·T₀₁", "la")],
     [("√4 = 2", "la")],
     [("T₀₂ = 2T₀₁", "la")]],
    290,
    [("الإجابة: (ب)  T₀₂ = 2T₀₁", "ar")])

# ================================================================
# S2 — مثال 2
# ================================================================
example_screen(
    screens[1], "l₂ = 4l₁",
    [[("دوره الخاص ", "ar"), ("T₀₁", "la"), (" نغير طول السلك فيصبح دوره الجديد مثلي:", "ar")],
     [("فكون طول سلك الفتل الجديد:", "ar")]],
    [[("T₀₂ = 2T₀₁", "la"), ("  ⟹  ", "la"), ("√(l₂/l₁) = 2", "la")],
     [("نربع الطرفين: ", "ar"), ("l₂/l₁ = 4", "la")],
     [("l₂ = 4l₁", "la")]],
    290,
    [("الإجابة: (أ)  l₂ = 4l₁", "ar")])

# ================================================================
# S3 — مثال 3
# ================================================================
example_screen(
    screens[2], "T₀₂ = T₀/2",
    [[("دوره الخاص ", "ar"), ("T₀ = 2 (s)", "la"), (" نجعل طول سلك الفتل ربع ما كان:", "ar")],
     [("فيصبح دوره الخاص الجديد:", "ar")]],
    [[("l₂ = l₁/4", "la"), ("  ⟹  ", "la"), ("T₀₂ = √(1/4)·T₀ = T₀/2", "la")],
     [("T₀₂ = 2/2", "la")],
     [("T₀₂ = 1 (s)", "la")]],
    290,
    [("الإجابة: (ب)  T₀₂ = 1 (s)", "ar")])

# ================================================================
# S4 — نسبة الدورين + إعادة السؤال
# ================================================================
x, y, _ = screens[3]
header(x, y, "نسبة الدورين + إعادة السؤال")
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "عندما نغير طول سلك الفتل",
     [[("(T₀₂/T₀₁) = √(k₁/k₂)", "la")],
      [("بما أن ", "ar"), ("k = k′(2r)⁴/l:", "la")],
      [("(T₀₂/T₀₁) = √(l₂/l₁)", "la")]],
     310)
card(x, y1+340, w, 2, "إعادة السؤال (بالعكس)",
     [[("إذا أُعطي ", "ar"), ("l₁ = 4l₂", "la"), (" وطُلب العلاقة بين الدورين:", "ar")],
      [("(T₀₂/T₀₁) = √(l₂/4l₂) = 1/2", "la")],
      [("T₀₁ = 2T₀₂", "la")],
      [("والعكس: ", "ar"), ("T₀₁ = 2T₀₂ ⟹ l₁ = 4l₂", "la")]],
     400)
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([(("نواس دوره الخاص ", "ar")), (("T₀₁", "la")), ((" طول السلك صار 4 أمثال، فالدور الجديد:", "ar"))],
     ["T₀₂ = 4T₀₁", "T₀₂ = 2T₀₁", "T₀₂ = T₀₁/2", "T₀₂ = T₀₁/4"], 1),
    ([(("إذا أصبح دوره الخاص مثلي ما كان عليه، فالطول الجديد:", "ar"))],
     ["l₂ = 4l₁", "l₂ = 2l₁", "l₂ = l₁/2", "l₂ = l₁/4"], 0),
    ([("T₀ = 2 (s)", "la"), ("  طول السلك صار ربع ما كان، فالدور الجديد:", "ar")],
     ["4 (s)", "1 (s)", "1/2 (s)", "1/4 (s)"], 1),
    ([(("عندما نغير طول سلك الفتل، نسبة الدورين هي:", "ar"))],
     ["(T₀₂/T₀₁) = √(l₂/l₁)", "(T₀₂/T₀₁) = √(l₁/l₂)", "(T₀₂/T₀₁) = l₂/l₁", "(T₀₂/T₀₁) = k₁/k₂"], 0),
    ([(("إذا كان l₁ = 4l₂ فإن العلاقة بين الدورين:", "ar"))],
     ["T₀₁ = 2T₀₂", "T₀₂ = 2T₀₁", "T₀₁ = T₀₂/2", "T₀₁ = 4T₀₂"], 0),
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

out = "unit-2.6-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
