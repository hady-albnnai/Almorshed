#!/usr/bin/env python3
# Review screens for U2-05 — نواس الفتل: الدور الخاص T₀ + الجملة + إضافة كتل + k + T₀ واللطول (map 2.5, blocks 845–883)
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
    (X1, SY, "الدور الخاص T₀"),
    (X2, SY, "عزم عطالة الجملة"),
    (X3, SY, "إضافة كتل + ثابت الفتل"),
    (X1, SY2, "T₀ وطول السلك"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.5 · نواس الفتل", "ar")]

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
# S1 — الدور الخاص T₀
# ================================================================
x, y, _ = screens[0]
header(x, y, [("الدور الخاص ", "ar"), ("T₀", "la")])
dx, dw = x+50, PW-100
cv.draw_flow(dx+dw, y+300, [("T₀ = 2π√(IΔ/K)", "la")], 36, cv.CYAN, bold=True)

y1 = y + 400
card(x+40, y1, PW-80, 1, "الكميات",
     [[("عزم عطالة النواس: ", "ar"), ("IΔ (kg.m²)", "la")],
      [("ثابت فتل السلك: ", "ar"), ("K (m.N.rad⁻¹)", "la")],
      [("IΔ/c = 0", "la"), (" — إذا كان الجسم مهمل الكتلة", "ar")]],
     300)
pill(x+PW-44, y+PH-260, [("الدور الخاص يقاس بالثواني (s)", "ar")])
footer(x, y)

# ================================================================
# S2 — عزم عطالة الجملة
# ================================================================
x, y, _ = screens[1]
header(x, y, "عزم عطالة الجملة")
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "الجملة",
     [[("IΔ/m₁ = m₁·r₁²", "la"), (" و ", "ar"), ("IΔ/m₂ = m₂·r₂²", "la")],
      [("كتل مثبتة حصراً في الفتل", "ar")]],
     250, eq="IΔ/جملة = IΔ/c + IΔ/m₁ + IΔ/m₂")
card(x, y1+280, w, 2, "إذا IΔ/m₁ = IΔ/m₂",
     [[("الكتلتان متساويتا العزم", "ar")]],
     240, eq="IΔ/جملة = IΔ/c + 2IΔ/m₁")
footer(x, y)

# ================================================================
# S3 — إضافة كتل + ثابت فتل السلك
# ================================================================
x, y, _ = screens[2]
header(x, y, [("إضافة كتل + ثابت الفتل", "ar")])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "عند إضافة كتل",
     [[("الدور الخاص بعد الإضافة / قبل الإضافة", "ar")]],
     240, eq="T₀′/T₀ = √(IΔ/جملة/IΔ/c)")
card(x, y1+270, w, 2, "ثابت فتل السلك",
     [[("K′: ثابت يتعلق بمادة السلك", "ar")],
      [("r: قطر السلك — l: طول سلك الفتل", "ar")],
      [("تُستخدم لتغير T₀ مع طول السلك", "ar")]],
     310, eq="k = K′(2r)⁴/l")
footer(x, y)

# ================================================================
# S4 — T₀ وطول السلك
# ================================================================
x, y, _ = screens[3]
header(x, y, [("T₀", "la"), (" وطول السلك ", "ar"), ("l", "la")])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "التناسب",
     [[("T₀ ∝ 1/√K", "la"), (" — عكسي", "ar")],
      [("T₀ ∝ √l", "la"), (" — طردي", "ar")]],
     250)
card(x, y1+280, w, 2, "النسب (نربع ثم نجذر)",
     [[("T₀₂ = √2·T₀₁", "la"), ("  ↔  ", "la"), ("l₂ = 2l₁", "la")],
      [("T₀₂ = 2T₀₁", "la"), ("  ↔  ", "la"), ("l₂ = 4l₁", "la")],
      [("T₀₂ = T₀₁/2", "la"), ("  ↔  ", "la"), ("l₂ = l₁/4", "la")],
      [("T₀₂ = T₀₁/√2", "la"), ("  ↔  ", "la"), ("l₂ = l₁/2", "la")]],
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
    ([(("الدور الخاص لنواس الفتل هو:", "ar"))],
     ["T₀ = 2π√(IΔ/K)", "T₀ = 2π√(K/IΔ)", "T₀ = 2π/IΔ", "T₀ = √(K/IΔ)"], 0),
    ([(("عزم عطالة الجملة في نواس الفتل هو:", "ar"))],
     ["IΔ/جملة = IΔ/c + IΔ/m₁ + IΔ/m₂", "IΔ/جملة = IΔ/c − IΔ/m₁", "IΔ/جملة = IΔ/c·IΔ/m₁", "IΔ/جملة = IΔ/c + IΔ/m₁ − IΔ/m₂"], 0),
    ([(("إذا كان IΔ/m₁ = IΔ/m₂ فإن:", "ar"))],
     ["IΔ/جملة = IΔ/c + 2IΔ/m₁", "IΔ/جملة = 2IΔ/c + IΔ/m₁", "IΔ/جملة = IΔ/c + IΔ/m₁/2", "IΔ/جملة = 2IΔ/c"], 0),
    ([(("ثابت فتل السلك يعطى بالعلاقة:", "ar"))],
     ["k = K′(2r)⁴/l", "k = K′(2r)²/l", "k = K′r⁴/(2l)", "k = K′l/(2r)⁴"], 0),
    ([(("إذا أصبح T₀₂ = 2T₀₁ فإن طول سلك الفتل الجديد:", "ar"))],
     ["l₂ = 4l₁", "l₂ = 2l₁", "l₂ = l₁/2", "l₂ = l₁/4"], 0),
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

out = "unit-2.5-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
