#!/usr/bin/env python3
# Review screens for U3-08 — قراءة الخط البياني + أسئلة امتحانات (map 3.8, blocks 1819–1916)
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
    (X1, SY,  "قراءة الخط البياني"),
    (X2, SY,  "التوابع الزمنية + (2/16)"),
    (X3, SY,  "امتحانات: (3/26) و (1/25) و (1/16)"),
    (X1, SY2, "هزازتان (3/16) + النابض الأفقي"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 3.8 · الخط البياني والامتحانات", "ar")]

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
# S1 — قراءة الخط البياني
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "تقسيمات المحور الزمني",
     [[("2T₀, 7T₀/4, 3T₀/2, 5T₀/4", "la")],
      [("T₀, 3T₀/4, T₀/2, T₀/4", "la")],
      [("مع ماكس المقدار الموجب والسالب", "ar")]],
     300)
card(x, y1+330, w, 2, "القراءة",
     [[("كل تقاطع مع المحور = ربع دور", "ar")],
      [("كل تغيير اتجاه = ربع دور", "ar")],
      [("نقرا φ من وضع t = 0", "ar")]],
     300)
card(x, y1+660, w, 3, "العلاقات",
     [[("ω₀ = 2π/T₀", "la")],
      [("v_max = ω₀X_max", "la")],
      [("a_max = ω₀²X_max", "la")],
      [("ω₀ = a_max/v_max", "la")]],
     360)
footer(x, y)

# ================================================================
# S2 — التوابع الزمنية + (2/16)
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "التوابع الزمنية الثلاثة",
     [[("x = Xmax cos(ω₀t+φ)", "la")],
      [("v = −ω₀Xmax sin(ω₀t+φ)", "la")],
      [("a = −ω₀²Xmax cos(ω₀t+φ)", "la")]],
     300)
card(x, y1+330, w, 2, "(2/16) أولا: T₀ = 1 s",
     [[("ω₀ = 2π rad/s, φ = 0", "la")],
      [("v_max = 0.12π m/s", "la")],
      [("v = −0.12π sin(2πt)", "la")]],
     300)
card(x, y1+660, w, 3, "لو طلب المطال أو التسارع",
     [[("Xmax = v_max/ω₀ = 0.06", "la")],
      [("x = 0.06cos(2πt)", "la")],
      [("a_max = ω₀v_max = 2.4", "la")],
      [("a = −2.4cos(2πt)", "la")]],
     360)
footer(x, y)

# ================================================================
# S3 — (3/26) و (1/25) و (1/16)
# ================================================================
x, y, _ = screens[2]
header(x, y, screens[2][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "(3/26) أولا: 2T₀ = 8",
     [[("T₀ = 4 s, ω₀ = π/2, φ = 0", "la")],
      [("ωmax = ω₀θmax = π²/8", "la")],
      [("ω = −(π²/8)sin((π/2)t)", "la")]],
     300)
card(x, y1+330, w, 2, "(1/25) أولا: نواس فتل",
     [[("ابتعدت الكتلتان عن المحور:", "ar")],
      [("يزداد IΔ ⟹ يزداد T₀", "ar")],
      [("T₀ = 2π√(IΔ/k)", "la")],
      [("الإجابة: c", "ar")]],
     340)
card(x, y1+690, w, 3, "(1/16) أولا",
     [[("ω₀ = π, Xmax = 0.08 m", "la")],
      [("φ = π rad", "la")],
      [("الإجابة: a", "ar")]],
     300)
footer(x, y)

# ================================================================
# S4 — هزازتان + النابض الأفقي
# ================================================================
x, y, _ = screens[3]
header(x, y, [( "هزازتان (3/16) + النابض الأفقي", "ar")])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "هزازتان من +Xmax بعد t = 3 s",
     [[("T₀₁ = 2π√(1/10) = 2 s", "la")],
      [("T₀₂ = 2π√((1/2)/20) = 1 s", "la")],
      [("n = t/T₀:", "la")]],
     300)
card(x, y1+330, w, 2, "المواقع بعد 3 s",
     [[("n₁ = 3/2 = 1.5 ", "la"), ("دور ⟹ ", "ar"), ("الهزازة (1) في −Xmax", "ar")],
      [("n₂ = 3/1 = 3 ", "la"), ("دورات ⟹ ", "ar"), ("الهزازة (2) في +Xmax", "ar")],
      [("الإجابة: d", "ar")]],
     320)
card(x, y1+670, w, 3, "(a-2/17) ثانياً: النابض الأفقي",
     [[("لا يوجد x₀: القوى W, R, F_s", "ar")],
      [("الإسقاط على الأفق: −F_s = m·a", "ar")],
      [("F_s = kx ⟹ −kx = m·x″", "la")],
      [("x″ = −(k/m)·x", "la")]],
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
    ([("كل تقاطع مع المحور في خط (مطال–زمن):", "ar")],
     ["ربع دور", "نصف دور", "دور كامل", "ربع سرعة"], 0),
    ([("العلاقة بين العظميين:", "ar"), ("  ω₀ =", "la")],
     ["a_max/v_max", "v_max/a_max", "a_max·v_max", "2πv_max"], 0),
    ([("نواس فتل ابتعدت كتلتاه عن المحور:", "ar")],
     ["يزداد T₀", "ينقص T₀", "تنقص θmax", "تزداد θmax"], 0),
    ([("هزازتان من +Xmax، T₀₁=2s، T₀₂=1s، بعد 3s:", "ar")],
     ["الأولى في −Xmax والثانية في +Xmax", "كلاهما في +Xmax", "كلاهما في المركز", "الأولى في +Xmax"], 0),
    ([("جسم بنابض شاقولي في المطال الأعظمي — عند القطع:", "ar")],
     ["سقوط حر", "قذف شاقولي", "يبقى ساكنًا", "قذف أفقي"], 0),
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

out = "unit-3.8-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
