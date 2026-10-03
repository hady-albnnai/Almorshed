#!/usr/bin/env python3
# Review screens for U2-10 — نواس الفتل: (b) + الإضافي (map 2.10, blocks 1049–1083)
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
    (X1, SY, "(b): IΔ/جملة"),
    (X2, SY, "(b): إيجاد T₀′ و k"),
    (X3, SY, "إضافي: سلكان k*"),
    (X1, SY2, "إضافي: حذف ربع الطول"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.10 · نواس الفتل", "ar")]

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
# S1 — (b): IΔ/جملة
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "الجملة",
     [[("m₁ = m₂ = 75×10⁻³ kg", "la")],
      [("r₁ = r₂ = l/2 = 2×10⁻¹ m", "la")],
      [("T₀ = 1 s  ·  IΔ/c = 2×10⁻³", "la")]],
     290)
card(x, y1+320, w, 2, "إيجاد IΔ/جملة",
     [[("IΔ/جملة = IΔ/c + 2IΔ/m₁", "la")],
      [("= IΔ/c + 2m₁r₁²", "la")],
      [("= 2×10⁻³ + 2×75×10⁻³×4×10⁻²", "la")],
      [("= 8×10⁻³ kg.m²", "la")]],
     380)
pill(x+PW-44, y+PH-260,
     [("T₀′ = T₀·√(IΔ/جملة/IΔ/c) = 2 (s)", "la")])
footer(x, y)

# ================================================================
# S2 — (b): إيجاد T₀′ و k
# ================================================================
x, y, _ = screens[1]
header(x, y, "(b): إيجاد T₀′ و k")
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "T₀′",
     [[("(T₀′/T₀) = √(IΔ/جملة/IΔ/c)", "la")],
      [("(T₀′/1) = √((8×10⁻³)/(2×10⁻³))", "la")],
      [("T₀′ = 2 (s)", "la")]],
     290)
card(x, y1+320, w, 2, "k (طر 1)",
     [[("k = ω₀²·IΔ/c", "la")],
      [("ω₀ = 2π/T₀ = 2π  ⟹  ω₀² ≈ 40", "la")],
      [("k = 40×2×10⁻³ = 8×10⁻²", "la")]],
     300)
card(x, y1+650, w, 3, "k (طر 2)",
     [[("k = (ω₀′)²·IΔ/جملة", "la")],
      [("ω₀′ = (2π)/T₀′ = π", "la")],
      [("k = π²×8×10⁻³ = 8×10⁻²", "la")]],
     300)
footer(x, y)

# ================================================================
# S3 — إضافي: سلكان k*
# ================================================================
x, y, _ = screens[2]
header(x, y, "إضافي: سلكان k*")
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "k لكل سلك",
     [[("k = k′(2r)⁴/l", "la")],
      [("k₁ = k′(2r)⁴/(l/2) = 2k", "la")],
      [("وبالمثل k₂ = 2k", "la")]],
     310)
card(x, y1+340, w, 2, "k* و T₀*",
     [[("k* = k₁ + k₂ = 4k", "la")],
      [("(T₀*/T₀) = √(k/k*) = √(k/4k)", "la")],
      [("T₀* = (1/2) = 0.5 (s)", "la")]],
     310)
footer(x, y)

# ================================================================
# S4 — إضافي: حذف ربع الطول + ملخص
# ================================================================
x, y, _ = screens[3]
header(x, y, "إضافي: حذف ربع الطول")
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "حذف ربع طول سلك الفتل",
     [[("l′ = (3/4)l", "la")],
      [("k′ = k′(2r)⁴/l′ = (4/3)k", "la")],
      [("T₀′ = T₀·√(k/k′) = T₀·√(3/4)", "la")],
      [("T₀′ = (√3/2)·1 ≈ 0.87 (s)", "la")]],
     360)
card(x, y1+390, w, 2, "ملخص (b)",
     [[("IΔ/جملة = 8×10⁻³ kg.m²", "la")],
      [("T₀′ = 2 s  ·  k = 8×10⁻² m.N.rad⁻¹", "la")],
      [("T₀* = 0.5 s (سلكان)", "la")]],
     300)
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
     ["8×10⁻³ kg.m²", "2×10⁻³ kg.m²", "6×10⁻³ kg.m²", "1×10⁻² kg.m²"], 0),
    ([(("الدور الخاص الجديد T₀′ هو:", "ar"))],
     ["2 (s)", "1 (s)", "0.5 (s)", "4 (s)"], 0),
    ([(("ثابت الفتل k (بالطريقتين) هو:", "ar"))],
     ["8×10⁻² m.N.rad⁻¹", "8×10⁻³ m.N.rad⁻¹", "4×10⁻² m.N.rad⁻¹", "16×10⁻² m.N.rad⁻¹"], 0),
    ([(("الإضافي: سلكان لكل منهما l/2، ثابت الجملة k* هو:", "ar"))],
     ["4k", "2k", "k/2", "k"], 0),
    ([(("الإضافي: T₀* في حال السلكين (T₀ = 1 s) هو:", "ar"))],
     ["0.5 (s)", "1 (s)", "2 (s)", "0.25 (s)"], 0),
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

out = "unit-2.10-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
