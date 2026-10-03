#!/usr/bin/env python3
# Review screens for U2-11 — نواس الفتل: مسألة القرص والساق والكتلتين (map 2.11, blocks 1090–1111)
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
    (X1, SY, "الجملة + IΔ/جملة"),
    (X2, SY, "T₀ + IΔ′/جملة"),
    (X3, SY, "إيجاد r₁′ و 2r′"),
    (X1, SY2, "ملخص المسألة"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.11 · نواس الفتل", "ar")]

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
# S1 — الجملة + IΔ/جملة
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "الجملة",
     [[("k = 8×10⁻⁴ m.N.rad⁻¹", "la")],
      [("قرص: M₁ = 0.12 kg (R₁ = 0.05 m)", "la")],
      [("ساق: M₂ = 0.012 kg (l = 0.1 m)", "la")],
      [("m₁ = m₂ = 0.05 kg (r = 0.02 m)", "la")]],
     380)
card(x, y1+410, w, 2, "إيجاد IΔ/جملة",
     [[("IΔ/جملة = IΔ/قرص + IΔ/ساق + 2IΔ/m₁", "la")],
      [("= (1/12)M₂l² + (1/2)M₁R² + 2m₁r₁²", "la")],
      [("= (1/12)×0.012×10⁻² + (1/2)×0.12×25×10⁻⁴", "la")],
      [(" + 2×5×10⁻²×4×10⁻⁴", "la")],
      [("1×10⁻⁵ + 15×10⁻⁵ + 4×10⁻⁵ = 2×10⁻⁴", "la")]],
     470)
footer(x, y)

# ================================================================
# S2 — T₀ + IΔ′/جملة
# ================================================================
x, y, _ = screens[1]
header(x, y, "T₀ + IΔ′/جملة")
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "إيجاد T₀",
     [[("T₀ = 2π√(IΔ/جملة/k)", "la")],
      [("(2×10⁻⁴)/(8×10⁻⁴) = 1/4", "la")],
      [("T₀ = 2π√(1/4) = π = 3.14 (s)", "la")]],
     300)
card(x, y1+330, w, 2, "عند T₀′ = 4 (s)",
     [[("T₀′ = T₀ + 0.86 = 4 (s)", "la")],
      [("IΔ′/جملة = (T₀′²·k)/40", "la")],
      [("= (16×8×10⁻⁴)/40 = 32×10⁻⁵ kg.m²", "la")]],
     300)
footer(x, y)

# ================================================================
# S3 — إيجاد r₁′ و 2r′
# ================================================================
x, y, _ = screens[2]
header(x, y, "إيجاد r₁′ و 2r′")
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "معادلة IΔ′/جملة",
     [[("IΔ′/جملة = IΔ/قرص + IΔ/ساق + 2IΔ′/m₁", "la")],
      [("32×10⁻⁵ = 1×10⁻⁵ + 15×10⁻⁵ + 10⁻¹·r₁′²", "la")],
      [("16×10⁻⁵ = 10⁻¹·r₁′²", "la")],
      [("r₁′² = 16×10⁻⁴  ⟹  r₁′ = 4×10⁻² m", "la")]],
     380)
card(x, y1+410, w, 2, "البعد الجديد",
     [[("البعد الجديد بين الكتلتين", "ar")],
      [("2r′ = 8×10⁻² m", "la")]],
     250)
footer(x, y)

# ================================================================
# S4 — ملخص المسألة
# ================================================================
x, y, _ = screens[3]
header(x, y, "ملخص المسألة")
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "IΔ/جملة", [], 200, eq="IΔ/جملة = 2×10⁻⁴ kg.m²")
card(x, y1+230, w, 2, "T₀", [], 200, eq="T₀ = π = 3.14 (s)")
card(x, y1+460, w, 3, "الطلب (2)",
     [[("IΔ′/جملة = 32×10⁻⁵ kg.m²", "la")],
      [("2r′ = 8×10⁻² m", "la"), ("  ⟹  ", "la"), ("r₁′ = 4×10⁻² m", "la")]],
     260)
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([(("عزم عطالة الجملة IΔ/جملة هو:", "ar"))],
     ["2×10⁻⁴ kg.m²", "1×10⁻⁴ kg.m²", "4×10⁻⁴ kg.m²", "15×10⁻⁵ kg.m²"], 0),
    ([(("الدور الخاص T₀ هو:", "ar"))],
     ["π = 3.14 (s)", "2π (s)", "1 (s)", "0.5 (s)"], 0),
    ([(("عند T₀′ = 4 (s)، IΔ′/جملة هو:", "ar"))],
     ["32×10⁻⁵ kg.m²", "16×10⁻⁵ kg.m²", "64×10⁻⁵ kg.m²", "2×10⁻⁴ kg.m²"], 0),
    ([(("القيمة الجديدة r₁′ هي:", "ar"))],
     ["4×10⁻² m", "2×10⁻² m", "8×10⁻² m", "1×10⁻¹ m"], 0),
    ([(("البعد الجديد بين الكتلتين 2r′ هو:", "ar"))],
     ["8×10⁻² m", "4×10⁻² m", "0.04 m", "1×10⁻¹ m"], 0),
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

out = "unit-2.11-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
