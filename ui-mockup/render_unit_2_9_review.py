#!/usr/bin/env python3
# Review screens for U2-09 — نواس الفتل: مسألة T₀ = 1 s (map 2.9, blocks 1027–1048)
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
    (X1, SY, [("الطلب (1): ", "ar"), ("θ", "la")]),
    (X2, SY, [("الطلب (2): ", "ar"), ("t₂", "la"), (" و ", "ar"), ("ω", "la")]),
    (X3, SY, [("الطلب (3): ", "ar"), ("α", "la")]),
    (X1, SY2, "ملخص المسألة"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.9 · نواس الفتل", "ar")]

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
# S1 — الطلب 1: θ
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "الثوابت",
     [[("θmax = θ = (π/3) rad", "la"), (" — ترك دون سرعة ابتدائية", "ar")],
      [("ω₀ = (2π)/T₀ = (2π)/1 = 2π rad.s⁻¹", "la")],
      [("عند t = 0: cos(φ) = 1 ⟹ φ = 0 rad", "la")]],
     300)
card(x, y1+330, w, 2, "النتيجة", [], 210, eq="θ = (π/3)·cos(2πt)  (rad)")
footer(x, y)

# ================================================================
# S2 — الطلب 2: t₂ و ω
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "إيجاد t₂",
     [[("مرور ثاني ⟸ السرعة عظمى موجبة", "ar")],
      [("t₂ = (3T₀)/4", "la")],
      [("= (3/4) (s)", "la")]],
     290)
card(x, y1+320, w, 2, "ω عندما t = 0",
     [[("θ = θmax", "la")],
      [("ωmax = +ω₀θmax = +2π×(π/3)", "la")],
      [("= (20/3) rad.s⁻¹", "la")]],
     300)
card(x, y1+650, w, 3, "ω عند t = t₂",
     [[("ω = −ω₀θmax·sin(ω₀t₂)", "la")],
      [("= −2π×(π/3)·sin(3π/2)", "la")],
      [("= (20/3) rad.s⁻¹", "la")]],
     300)
footer(x, y)

# ================================================================
# S3 — الطلب 3: α
# ================================================================
x, y, _ = screens[2]
header(x, y, screens[2][2])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, [("α عند ", "ar"), ("θ = (−π/6) rad", "la")],
     [[("α = −ω₀²θ", "la")],
      [("ω₀² = 4π² ≈ 40", "la")],
      [("α = −40×(−π/6)", "la")],
      [("= +(20π/3) rad.s⁻²", "la")]],
     340)
card(x, y1+370, w, 2, "إشارة α",
     [[("المطال سالب ⟹ α موجب", "ar")],
      [("α موجّه نحو مركز الاهتزاز", "ar")]],
     250)
footer(x, y)

# ================================================================
# S4 — ملخص المسألة
# ================================================================
x, y, _ = screens[3]
header(x, y, "ملخص المسألة")
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "الطلب (1)", [], 200, eq="θ = (π/3)cos(2πt)  (rad)")
card(x, y1+230, w, 2, "الطلب (2)",
     [[("t₂ = (3/4) (s)", "la")],
      [("(20/3) rad.s⁻¹", "la"), (" — عظمى موجبة", "ar")]],
     260)
card(x, y1+510, w, 3, "الطلب (3)", [], 200, eq="α = +(20π/3) rad.s⁻²")
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([(("النبض الخاص ω₀ في هذه المسألة هو:", "ar"))],
     ["2π rad.s⁻¹", "π rad.s⁻¹", "(2π)/3 rad.s⁻¹", "4π rad.s⁻¹"], 0),
    ([(("التابع الزمني للمطال هو:", "ar"))],
     ["θ = (π/3)cos(2πt) (rad)", "θ = (π/3)cos(πt) (rad)", "θ = (π/6)cos(2πt) (rad)", "θ = (π/3)sin(2πt) (rad)"], 0),
    ([(("الزمن t₂ (مرور ثاني، السرعة عظمى موجبة) هو:", "ar"))],
     ["(3T₀)/4 = (3/4) (s)", "T₀/4 = (1/4) (s)", "T₀/2 = (1/2) (s)", "(3T₀)/2 (s)"], 0),
    ([(("السرعة الزاوية عند t = t₂ هي:", "ar"))],
     ["(20/3) rad.s⁻¹ (عظمى موجبة)", "(−20/3) rad.s⁻¹", "صفر", "(10/3) rad.s⁻¹"], 0),
    ([(("التسارع الزاوي عند θ = (−π/6) rad هو:", "ar"))],
     ["+(20π/3) rad.s⁻²", "(−20π/3) rad.s⁻²", "صفر", "+(10π/3) rad.s⁻²"], 0),
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

out = "unit-2.9-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
