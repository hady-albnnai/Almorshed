#!/usr/bin/env python3
# Review screens for U2-01 — نواس الفتل (map 2.1, blocks 717–746)
import math
from PIL import Image, ImageDraw
import review_common as cv

W, H = 2480, 3420
img = cv.make_bg(W, H)
d = ImageDraw.Draw(img)

GOLD = (255, 200, 87)

# ---------------- layout (3 + 2) ----------------
SY, SY2 = 330, 1860
PW, PH  = 760, 1350
X1, X2, X3 = 1640, 850, 60
screens = [
    (X1, SY, "نواس الفتل"),
    (X2, SY, "الشرح"),
    (X3, SY, "وحدات الكميات"),
    (X1, SY2, "بطاقات المراجعة"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 1.2 · نواس الفتل", "ar")]

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
# S1 — definition + figure (F0109 redrawn)
# ================================================================
x, y, _ = screens[0]
header(x, y, "نواس الفتل")
pill(x+PW-44, y+186, [("التعريف", "ar")])

dx, dw = x+50, PW-100
def_lines = [
    [("كل جسم (ساق أو قرص مع أو بدون كتل) معلّق من", "ar")],
    [("مركز عطالته بسلك فتل شقليو ثابت فتلته ", "ar"), ("K", "la"), (".", "ar")],
    [("يمكنه أن يهتز إلى جانب نقطة ثابتة", "ar")],
    [("تسمى مركز الاهتزاز (موضع اتزونه).", "ar")],
]
ly = y + 262
for i, segs in enumerate(def_lines):
    lw = cv.flow_width(segs, 29)
    assert lw <= dw, f"def line {i} too wide: {lw} > {dw}"
    color = cv.TEAL if i == len(def_lines)-1 else cv.WHITE
    cv.draw_flow(dx+dw, ly+24, segs, 29, color, bold=(i == len(def_lines)-1))
    ly += 52

# figure panel
fx, fy, fw, fh = x+75, ly+30, PW-150, 330
d.rounded_rectangle([fx, fy, fx+fw, fy+fh], radius=20, outline=cv.CARD_BORDER, width=3)
bar = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(bar)
cx, cy = x+PW//2, fy+180
ang, bl = -18, 195
bd.line([(cx, cy), (cx, cy-118)], fill=cv.DIM+(255,), width=9)
for xx in range(fx+25, fx+fw-20, 44):
    bd.line([(xx, cy), (xx+26, cy)], fill=(94, 234, 212, 255), width=4)
ex1 = cx-bl*math.cos(math.radians(ang)); ey1 = cy-bl*math.sin(math.radians(ang))
ex2 = cx+bl*math.cos(math.radians(ang)); ey2 = cy+bl*math.sin(math.radians(ang))
bd.line([(ex1, ey1), (ex2, ey2)], fill=cv.CYAN+(255,), width=14)
for ex, ey in ((ex1, ey1), (ex2, ey2)):
    bd.rounded_rectangle([ex-9, ey-9, ex+9, ey+9], radius=4, fill=cv.CYAN+(255,))
img.alpha_composite(bar)  # in-place: cv._IMG المرجع يبقى صالحًا
d = ImageDraw.Draw(img)
d.arc([cx-58, cy-58, cx+58, cy+58], start=105, end=165, fill=GOLD+(255,), width=5)
d.arc([cx-58, cy-58, cx+58, cy+58], start=285, end=345, fill=GOLD+(255,), width=5)
d.text((cx+112, cy-92), "+θmax", font=cv.load_la(26, bold=True), fill=GOLD)
d.polygon([(cx+104, cy-56), (cx+70, cy-34), (cx+78, cy-50)], fill=GOLD)
d.text((cx-196, cy+52), "−θmax", font=cv.load_la(26, bold=True), fill=GOLD, anchor="rs")
d.polygon([(cx-104, cy+52), (cx-70, cy+32), (cx-78, cy+48)], fill=GOLD)
d.text((cx+140, cy-18), "θ = 0", font=cv.load_la(22), fill=cv.CYAN)
wmb = cv.flow_width([("مركز التوازن", "ar")], 24)
cv.draw_flow(cx+110+wmb, cy+110, [("مركز التوازن", "ar")], 24, cv.CYAN)
d.text((fx+30, fy+fh-46), "T₀/4", font=cv.load_la(26), fill=cv.LIGHT, anchor="ls")

pill(x+PW-44, y+PH-260, [("عزم الارجاع ", "ar"), ("Γₙ = −K·θ", "la")])
footer(x, y)

# ================================================================
# S2 — حالة السكون + حالة الحركة
# ================================================================
x, y, _ = screens[1]
header(x, y, "الشرح")
pill(x+PW-44, y+186, [("حالة السكون ", "ar"), ("+", "la"), (" حالة الحركة", "ar")])
w = PW - 80
y1 = y + 290
card(x, y1, w, 1, "حالة السكون",
     [[("الساق في وضع توازنها، محصلة العزوم عليها صفر", "ar")]],
     230, eq="ΣΓ = 0")
card(x, y1+260, w, 2, "حالة الحركة: عزم مزدوجة الفتل",
     [[("عند تدوير الساق عن وضع توازنها بزاوية ", "ar"), ("θ", "la")],
      [("ينشأ في سلك الفتل مزدوجة فتل،", "ar")],
      [("عزمها هو عزم ارجاع يعطى بالعلاقة", "ar")]],
     310, eq="Γₙ = −K·θ")
footer(x, y)

# ================================================================
# S3 — وحدات الكميات
# ================================================================
x, y, _ = screens[2]
header(x, y, "وحدات الكميات")
pill(x+PW-44, y+186, [("وحدات الكميات", "ar")])
card(x+40, y+290, PW-80, 1, "وحدات العلاقة",
     [[("المطال الزاوي ", "ar"), ("θ", "la"), (" بـ ", "ar"), ("(rad)", "la")],
      [("عزم مزدوجة الفتل بـ ", "ar"), ("(m.N)", "la")],
      [("ثابت فتل السلك ", "ar"), ("K", "la"), (" بـ ", "ar"), ("(m.N.rad⁻¹)", "la")]],
     300)
footer(x, y)

# ================================================================
# S4 — cards
# ================================================================
x, y, _ = screens[3]
header(x, y, "بطاقات المراجعة")
w = PW - 80
y1 = y + 120
card(x, y1, w, 1, "نواس الفتل",
     [[("كل جسم (ساق أو قرص مع أو بدون كتل) معلّق من", "ar")],
      [("مركز عطالته بسلك فتل شقليو ثابت فتلته ", "ar"), ("K", "la")],
      [("يهتز إلى جانب نقطة ثابتة: مركز الاهتزاز", "ar")]],
     268)
card(x, y1+286, w, 2, "مركز الاهتزاز",
     [[("نقطة ثابتة تسمى مركز الاهتزاز", "ar")],
      [("(موضع التوازن)؛ يهتز إليها الجسم", "ar")],
      [("في حالة السكون: ", "ar"), ("ΣΓ = 0", "la")]],
     268)
card(x, y1+572, w, 3, "عزم الارجاع (مزدوجة الفتل)",
     [[("عند تدوير الساق عن وضع توازنها بزاوية ", "ar"), ("θ", "la")],
      [("ينشأ في سلك الفتل مزدوجة فتل", "ar")]],
     268, eq="Γₙ = −K·θ")
card(x, y1+840, w, 4, "وحدات الكميات",
     [[("المطال الزاوي ", "ar"), ("θ", "la"), (" بـ ", "ar"), ("(rad)", "la")],
      [("عزم مزدوجة الفتل بـ ", "ar"), ("(m.N)", "la")],
      [("ثابت فتل السلك ", "ar"), ("K", "la"), (" بـ ", "ar"), ("(m.N.rad⁻¹)", "la")]],
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
    ([("في تعريف نواس الفتل، الجسم معلّق من مركز عطالته:", "ar")],
     ["بواسطة سلك فتل شقليو", "بواسطة نابض أفقي", "بواسطة وتر مرن", "بواسطة سلك مطاطي"], 0),
    ([("مركز الاهتزاز في نواس الفتل هو:", "ar")],
     ["موضع التوازن، نقطة ثابتة", "مركز كتلة الساق", "نقطة منتصف السلك", "نقطة تعليق الساق"], 0),
    ([("في حالة السكون، محصلة العزوم المؤثرة في الساق:", "ar")],
     ["ΣΓ = 0", "ΣΓ = K·θ", "ΣΓ = −K·θ", "ΣΓ = I·α"], 0),
    ([("عند تدوير الساق عن وضع توازنها بزاوية ", "ar"), ("θ", "la"),
      ("، عزم الفتل يعطى:", "ar")],
     ["Γₙ = −K·θ", "Γₙ = K·θ", "Γₙ = −K/θ", "Γₙ = K·θ²"], 0),
    ([("وحدة قياس ثابت الفتل ", "ar"), ("K", "la"), (" هي:", "ar")],
     ["m.N.rad⁻¹", "m.N", "rad", "N/m"], 0),
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
        osegs = [(opt, "ar" if cv.has_arabic(opt) else "la")]
        ow = cv.flow_width(osegs, 22)
        assert ow <= PW - 200, f"opt too wide: {ow}"
        cv.draw_flow(x+PW-116, oy+21, osegs, 22, cv.WHITE if sel else cv.LIGHT, bold=sel)
        oy += 34
    qy += qh + 8
footer(x, y)

out = "unit-2.1-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
