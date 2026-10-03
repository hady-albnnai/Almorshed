#!/usr/bin/env python3
# Review screens for U2-03 — نواس الفتل: الطاقة + الاشتقاق من الطاقة (map 2.3, blocks 788–803)
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
    (X1, SY, "طاقة نواس الفتل"),
    (X2, SY, "نشتق الطرفين"),
    (X3, SY, "مثل السابق"),
    (X1, SY2, "بطاقات المراجعة"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.3 · نواس الفتل", "ar")]

def header(x, y, title):
    cv.draw_header(x, y, PW, PH, [(title, "ar")], SUB)

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
        cv.draw_flow(x+w-44, ly+16, [(eq, "la")], 34, cv.CYAN, bold=True)

# ================================================================
# S1 — conservation of energy
# ================================================================
x, y, _ = screens[0]
header(x, y, "طاقة نواس الفتل")
pill(x+PW-44, y+186, [("حفظ الطاقة", "ar")])

dx, dw = x+50, PW-100
eqw = cv.flow_width([("E = E_k + E_p = const", "la")], 34, True)
cv.draw_flow(dx+dw, y+320, [("E = E_k + E_p = const", "la")], 34, cv.CYAN, bold=True)

y1 = y + 400
card(x+40, y1, PW-80, 1, "شكل الطاقة",
     [[("الطاقة الميكانيكية الكلية محفوظة:", "ar")],
      [("الطاقة الحركية: ", "ar"), ("E_k = (1/2)IΔ·ω²", "la")],
      [("الطاقة الكامنة: ", "ar"), ("E_p = (1/2)K·θ²", "la")],
      [("الطاقة محفوظة في جميع المواضع", "ar")]],
     360, eq="(1/2)IΔ·ω² + (1/2)K·θ² = const")
pill(x+PW-44, y+PH-260,
     [("معادلة الطاقة تقود هي الأُخرى إلى معادلة الحركة", "ar")])
footer(x, y)

# ================================================================
# S2 — differentiate both sides
# ================================================================
x, y, _ = screens[1]
header(x, y, "نشتق الطرفين")
pill(x+PW-44, y+186, [("الاشتقاق الزمني", "ar")])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "خطوات الاشتقاق",
     [[("بما أن ω′ = α: ", "ar"), ("IΔ·ωα + K·θω = 0", "la")],
      [("ω[IΔ·α + K·θ] = 0", "la")],
      [("ω ≠ 0  ⟹  IΔ·α + K·θ = 0", "la")]],
     300)
card(x, y1+330, w, 2, "النتيجة",
     [[("IΔ·θ̈ = −K·θ", "la")]],
     240, eq="θ̈ = (−K/IΔ)·θ  …(*)")
footer(x, y)

# ================================================================
# S3 — مثل السابق (same equation)
# ================================================================
x, y, _ = screens[2]
header(x, y, "مثل السابق")
pill(x+PW-44, y+186, [("نفس المعادلة", "ar")])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "المعادلة",
     [[("IΔ·θ̈ = −K·θ", "la")],
      [("θ̈ = (−K/IΔ)·θ  …(*)", "la")],
      [("نفس معادلة الدراسة التحريكية", "ar")]],
     280)
card(x, y1+310, w, 2, "الاستنتاج",
     [[("حركة نواس الفتل", "ar")],
      [("حركة جيبية دورانية", "ar")]],
     240)
card(x, y1+580, w, 3, "طريقتا الاشتقاق",
     [[("التحريكي: ", "ar"), ("ΣΓ = IΔ·α", "la")],
      [("الطاقة: ", "ar"), ("نشتق (1/2)IΔω² + (1/2)Kθ² = const", "la")],
      [("كلا الطريقتين تصل إلى المعادلة (*)", "ar")]],
     280)
footer(x, y)

# ================================================================
# S4 — cards
# ================================================================
x, y, _ = screens[3]
header(x, y, "بطاقات المراجعة")
w = PW - 80
y1 = y + 120
card(x, y1, w, 1, "حفظ الطاقة",
     [[("E = E_k + E_p = const", "la")],
      [("E_k = (1/2)IΔ·ω² · E_p = (1/2)K·θ²", "la")],
      [("الطاقة الميكانيكية محفوظة", "ar")]],
     268)
card(x, y1+286, w, 2, "الاشتقاق من الطاقة",
     [[("IΔ·ωα + K·θω = 0", "la")],
      [("ω[IΔ·α + K·θ] = 0", "la")],
      [("بما أن ω ≠ 0: ", "ar"), ("IΔ·α + K·θ = 0", "la")]],
     268)
card(x, y1+572, w, 3, "النتيجة",
     [[("IΔ·θ̈ = −K·θ", "la")],
      [("θ̈ = (−K/IΔ)·θ …(*)", "la")],
      [("نفس المعادلة ⟹ الحركة جيبية دورانية", "ar")]],
     268)
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([("الطاقة الميكانيكية الكلية لنواس الفتل هي:", "ar")],
     ["E = E_k + E_p = const", "E = E_k − E_p", "E = (1/2)K·θ² فقط", "E = IΔ·ω²"], 0),
    ([("الطاقة الكامنة لنواس الفتل هي:", "ar")],
     ["E_p = (1/2)K·θ²", "E_p = (1/2)IΔ·ω²", "E_p = K·θ", "E_p = (1/2)IΔ·α"], 0),
    ([("بإشتقاق معادلة الطاقة نحصل على:", "ar")],
     ["IΔ·ωα + K·θω = 0", "IΔ·α = 0", "K·θ = 0", "ω + α = 0"], 0),
    ([("في ω[IΔ·α + K·θ] = 0 نلغي ω لأن:", "ar")],
     ["ω ≠ 0 (النواس في حركة)", "ω = 0 دائمًا", "ω ثابت", "السعة كبيرة"], 0),
    ([("الاشتقاق من الطاقة يؤدي إلى:", "ar")],
     [[("نفس المعادلة ", "ar"), ("θ̈ = (−K/IΔ)·θ", "la")],
      "معادلة مختلفة",
      "θ̈ = (K/IΔ)·θ",
      "لا تتحصل على معادلة تفاضلية"], 0),
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

out = "unit-2.3-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
