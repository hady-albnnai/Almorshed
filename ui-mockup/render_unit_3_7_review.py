#!/usr/bin/env python3
# Review screens for U3-07 — طرق حل مسألة النواس الثقلي المركب (map 3.7, blocks 1446–1818)
import review_common as cv

W, H = 2480, 3420
img = cv.make_bg(W, H)
from PIL import ImageDraw
d = ImageDraw.Draw(img)

# ---------------- layout (3 + 3) ----------------
SY, SY2 = 330, 1860
PW, PH  = 760, 1350
X1, X2, X3 = 1640, 850, 60
screens = [
    (X1, SY,  "الطريقة 1: T₀ والقواعد"),
    (X2, SY,  "البعد d + الطريقتان 2 و 3"),
    (X3, SY,  "الطريقتان 4 و 5: الطاقة والسرعات"),
    (X1, SY2, "تطبيق 1: ساق مهملة + كتلتان"),
    (X2, SY2, "التطبيقات 2 و 3 و 4 + الميقاتية"),
    (X3, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 3.7 · طرق حل النواس الثقلي المركب", "ar")]

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
# S1 — الطريقة 1: T₀ + قواعد m و IΔ و Steiner
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "1) T₀ في السعات الصغيرة",
     [[("(a) احسب: m, IΔ, d بالأرقام ونعوض", "ar")],
      [("(b) استنتج T₀ أو l أو r بالرموز", "ar")],
      [("ونعزل المجهول (بدون كتل: استنتاج)", "ar")]],
     320)
card(x, y1+350, w, 2, "كتلة الجملة وعزمها",
     [[("m", "la"), ("جملة", "ar"), (" = m", "la"), ("جسم", "ar"), (" + m₁ + m₂", "la")],
      [("m", "la"), ("جسم", "ar"), (" = 0 ", "la"), ("إذا الجسم مهمل الكتلة", "ar")],
      [("IΔ/", "la"), ("جملة", "ar"), (" = IΔ", "la"), ("جسم", "ar"), (" + m₁r₁² + m₂r₂²", "la")],
      [("(IΔ/m₁ ≠ IΔ/m₂ حصراً)", "ar")]],
     320)
card(x, y1+700, w, 3, "Steiner و قيم IΔ/c",
     [[("IΔ/0 = IΔ/c + m·d²", "la")],
      [("حلقة: ", "ar"), ("IΔ/c = mr²", "la")],
      [("ساق: ", "ar"), ("IΔ/c = (1/12)ml²", "la")],
      [("قرص: ", "ar"), ("IΔ/c = (1/2)mr²", "la")]],
     320)
footer(x, y)

# ================================================================
# S2 — البعد d + الطريقتان 2 و 3
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "d = oc: نقطة التعليق ومركز العطالة",
     [[("مباشرة (بدون كتل): ", "ar"), ("d = d", "la"), (" هاينغز", "ar")],
      [("غير مباشرة (مع كتل):", "ar")],
      [("d = ∑(mᵢrᵢ)/∑(mᵢ)", "la")],
      [("r > 0 ", "la"), ("تحت المحور،", "ar"), (" r < 0 ", "la"), ("فوق المحور", "ar")],
      [("r = 0 ", "la"), ("الكتلة على المحور", "ar")]],
     380)
card(x, y1+410, w, 2, "2) T₀′ في السعات الكبيرة",
     [[("T₀′", "la"), ("كبيرة", "ar"), (" = T₀", "la"), ("صغيرة", "ar"), ("[1 + θmax²/16]", "la")]],
     200)
card(x, y1+630, w, 3, "3) النواس البسيط المواقيت",
     [[("بسيط ", "ar"), ("T₀", "la"), (" = مركب ", "ar"), ("T₀", "la")],
      [("2π√(l/g) = 2π√(IΔ/mgd)", "la")],
      [("l = IΔ/(m·d)", "la")]],
     300)
footer(x, y)

# ================================================================
# S3 — الطريقتان 4 و 5
# ================================================================
x, y, _ = screens[2]
header(x, y, screens[2][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "4) ω عند الشاقول أو السعة",
     [[("الطاقة بين أعلى ارتفاع والشاقول:", "ar")],
      [("Ek₁ = 0", "la"), ("  و  ", "ar"), ("W_R = 0", "la"), (" (نقطة التأثير", "ar")],
      [("لا تنتقل) ⟹ ", "ar"), ("Ek₂ = m·g·h", "la")]],
     280,
     eq=[("(1/2)IΔω² = m·g·d·(1 − cosθmax)", "la")])
card(x, y1+310, w, 2, "5) السرعات الخطية",
     [[("v_m₁ = ω·r₁    v_m₂ = ω·r₂", "la")],
      [("لمركز العطالة: ", "ar"), ("v_c = ω·d", "la")]],
     260)
card(x, y1+590, w, 3, "عندما يعطى سرعة خطية",
     [[("نحسب منها سرعة زاوية:", "ar")],
      [("ω = v_c/d", "la"), ("  أو  ", "ar"), ("ω = v_m₁/r₁", "la")]],
     260)
footer(x, y)

# ================================================================
# S4 — تطبيق 1
# ================================================================
x, y, _ = screens[3]
header(x, y, [("تطبيق 1", "ar")])
pill(x+PW-44, y+186, [("ساق مهملة + كتلتان", "ar")], size=26)
pill(x+PW-44, y+250, [("m₁ = 0.4 (r₁ = 0.5)    m₂ = 0.2 (r₂ = 1)", "la")], size=26)
w = PW - 80
y1 = y + 330
card(x, y1, w, 1, "(1) إيجاد T₀",
     [[("m = 0.4 + 0.2 = 0.6 kg", "la")],
      [("IΔ = 0.4×(1/4) + 0.2×1 = 0.3 kg.m²", "la")],
      [("d = (0.4×(1/2) + 0.2×1)/0.6 = 2/3 m", "la")],
      [("T₀ = 2π√(0.3/(0.6×10×2/3)) = √3 s", "la")]],
     420)
card(x, y1+450, w, 2, "(2) v_c = 4π/(3√3): ω و v_m₂",
     [[("ω = v_c/d = (4π/(3√3))/(2/3) = 2π/√3", "la")],
      [("v_m₂ = ω·r₂ = 2π/√3 m.s⁻¹", "la")]],
     260)
card(x, y1+740, w, 3, "(3) إيجاد θmax (الملاحظة 4)",
     [[("(1/2)×0.3×(40/3) = 0.6×10×(2/3)(1−cosθmax)", "la")],
      [("cosθmax = 1/2 ⟹ θmax = π/3 rad", "la")]],
     260)
footer(x, y)

# ================================================================
# S5 — التطبيقات 2 + 3 + 4 + الميقاتية
# ================================================================
x, y, _ = screens[4]
header(x, y, screens[4][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "تطبيق 2: كتلتان r₁ = r₂ = l/2",
     [[("m₁ = 0.2, m₂ = 0.6, l = 1 m", "la")],
      [("T₀ = 2 s (IΔ = 0.2, d = 1/4)", "la")],
      [("مواقيت ", "ar"), ("l = 1 m", "la")],
      [("T₀′ (θmax=0.4) = 2.02 s", "la")],
      [("ω = √10 ≃ π, vc = π/4, vm₁ = π/2", "la")]],
     440)
card(x, y1+470, w, 2, "تطبيق 3: حلقة R = 12.5 cm",
     [[("T₀ = 2π√(2R/g) = 1 s", "la")],
      [("مواقيت ", "ar"), ("l = 0.25 m", "la")]],
     280)
card(x, y1+770, w, 3, "تطبيق 4: قرص r = 2/3 m + الميقاتية",
     [[("T₀ = 2π√(3r/2g) = 2 s", "la")],
      [("المِيقاتية تدق الثانية ⟺ ", "ar"), ("T₀ = 2 s", "la")],
      [("تقدم ⟺ نكبر ", "ar"), ("T₀", "la"), (". تؤخر ⟺ نصغرها", "ar")]],
     340)
footer(x, y)

# ================================================================
# S6 — MCQ
# ================================================================
x, y, _ = screens[5]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([("لم يمر محور الدوران من مركز العطالة: ", "ar"), ("IΔ/0 =", "la")],
     ["IΔ/c + m·d²", "IΔ/c", "m·d² فقط", "IΔ/c − m·d²"], 0),
    ([("IΔ/c للقرص نصف قطره r:", "ar")],
     ["(1/2)mr²", "mr²", "(1/12)mr²", "(2/5)mr²"], 0),
    ([("الكتلة فوق محور الدوران في حساب d:", "ar")],
     ["r < 0", "r > 0", "r = 0", "تُحذف"], 0),
    ([("طول النواس البسيط المواقيت:", "ar")],
     ["l = IΔ/(m·d)", "l = m·d/IΔ", "l = T₀²g/40", "l = 2d"], 0),
    ([("ميقاتية ثقلي تقدم — لتصحيحها:", "ar")],
     ["نكبر T₀", "نصغر T₀", "لا تصحح", "نقلل g"], 0),
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

out = "unit-3.7-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
