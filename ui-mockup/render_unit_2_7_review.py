#!/usr/bin/env python3
# Review screens for U2-07 — نواس الفتل: المسألة الكاملة (map 2.7, blocks 938–973)
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
    (X1, SY, [("IΔ/c", "la"), (" و ", "ar"), ("T₀", "la")]),
    (X2, SY, "إضافي: كتلة القرص"),
    (X3, SY, "الطلب 2: التابع الزمني"),
    (X1, SY2, "الطلب 3: الطاقات"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.7 · نواس الفتل", "ar")]

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
# S1 — إيجاد IΔ/c و T₀
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "إيجاد IΔ/c",
     [[("IΔ/c = (1/2)mr²", "la")],
      [("= (1/2)×2×16×10⁻⁴", "la")],
      [("= 16×10⁻⁴ kg.m²", "la")]],
     290)
card(x, y1+320, w, 2, "إيجاد T₀",
     [[("T₀ = 2π√(IΔ/c/k)", "la")],
      [("= 2π√((16×10⁻⁴)/(16×10⁻³))", "la")],
      [("= 2π√(10⁻¹)", "la")]],
     300, eq="T₀ = 2 (s)")
footer(x, y)

# ================================================================
# S2 — إضافي: كتلة القرص
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "إيجاد IΔ/c من T₀",
     [[("T₀² = 40·(IΔ/c)/k", "la")],
      [("IΔ/c = (T₀²·k)/40", "la")],
      [("= (4×16×10⁻³)/40", "la")],
      [("= 16×10⁻⁴ kg.m²", "la")]],
     340)
card(x, y1+370, w, 2, "إيجاد m من IΔ/c",
     [[("m = (2IΔ/c)/r²", "la")],
      [("= (2×16×10⁻⁴)/(16×10⁻⁴)", "la")],
      [("= 2 kg", "la")]],
     300)
footer(x, y)

# ================================================================
# S3 — الطلب 2: التابع الزمني
# ================================================================
x, y, _ = screens[2]
header(x, y, screens[2][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "الثوابت",
     [[("θmax = θ = (π/4) rad", "la"), (" — ترك دون سرعة ابتدائية", "ar")],
      [("ω₀ = 2π/T₀ = (2π)/2 = π", "la"), (" (طر 1)", "ar")],
      [("ω₀ = √(K/IΔ/c) = √10 = π", "la"), (" (طر 2)", "ar")],
      [("عند t = 0: cos(φ) = 1 ⟹ φ = 0", "la")]],
     360)
card(x, y1+390, w, 2, "النتيجة", [], 210, eq="θ = (π/4)·cos(πt)  (rad)")
footer(x, y)

# ================================================================
# S4 — الطلب 3: الطاقات
# ================================================================
x, y, _ = screens[3]
header(x, y, screens[3][2])
pill(x+PW-44, y+186, [("عند ", "ar"), ("θ = (π/8)", "la"), (" rad", "la")])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "الطاقة الكامنة E_p",
     [[("E_p = (1/2)kθ²", "la")],
      [("= (1/2)×16×10⁻³×(10/64)", "la")],
      [("= (1/8)×10⁻² J", "la")]],
     300)
card(x, y1+330, w, 2, "الكلية E والحركية E_k",
     [[("E = (1/2)kθmax² = (1/2)×16×10⁻³×(10/16)", "la")],
      [("= (1/2)×10⁻² J", "la")],
      [("E_k = E − E_p = (1/2−1/8)×10⁻²", "la")],
      [("= (3/8)×10⁻² J", "la")]],
     360)
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([(("عزم عطالة القرص IΔ/c هو:", "ar"))],
     ["IΔ/c = (1/2)mr² = 16×10⁻⁴ kg.m²", "IΔ/c = mr² = 32×10⁻⁴ kg.m²", "IΔ/c = (1/2)mr = 8×10⁻⁴ kg.m²", "IΔ/c = (1/4)mr² = 8×10⁻⁴ kg.m²"], 0),
    ([(("الدور الخاص T₀ هو:", "ar"))],
     ["2π√(IΔ/c/k) = 2 (s)", "2π√(k/IΔ/c) = 10 (s)", "2π/IΔ/c (s)", "π√(IΔ/c/k) (s)"], 0),
    ([(("الإضافي: أُعطي T₀ = 2 (s) وطُلبت كتلة القرص، فإنها:", "ar"))],
     ["2 kg", "4 kg", "1 kg", "8 kg"], 0),
    ([(("التابع الزمني للمطال هو:", "ar"))],
     ["θ = (π/4)cos(πt) (rad)", "θ = (π/4)cos(2πt) (rad)", "θ = (π/8)cos(πt) (rad)", "θ = (π/4)sin(πt) (rad)"], 0),
    ([(("عند θ = (π/8) rad، الطاقة الحركية E_k هي:", "ar"))],
     ["(3/8)×10⁻² J", "(1/8)×10⁻² J", "(1/2)×10⁻² J", "(1/4)×10⁻² J"], 0),
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

out = "unit-2.7-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
