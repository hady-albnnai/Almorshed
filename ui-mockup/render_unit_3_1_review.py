#!/usr/bin/env python3
# Review screens for U3-01 — الاهتزازات غير التوافقية: النواس الثقلي المركب (map 3.1, blocks 1113–1191)
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
    (X1, SY, "التعريف + أنواع التوازن"),
    (X2, SY, "التحريكية: d و d′"),
    (X3, SY, "س1) غير توافقية"),
    (X1, SY2, "سعات صغيرة + T₀"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 3.1 · الاهتزازات غير التوافقية", "ar")]

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
# S1 — التعريف + أنواع التوازن + ملاحظات T₀
# ================================================================
x, y, _ = screens[0]
header(x, y, screens[0][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "التعريف",
     [[("كل جسم: ساق أو قرص أو حلقة،", "ar")],
      [("مع أو بدون كتل، يهتز في مستوى شاقولي", "ar")],
      [("حول محور دوران أفقي مار منه ولا يمر في مركز عطالته", "ar")]],
     300)
card(x, y1+330, w, 2, "أنواع التوازن",
     [[("مطلق: ((لا ينوس))", "ar")],
      [("مستقر: ينوس إلى جانبي وضع التوازن", "ar")],
      [("قلق: يعود إلى وضع التوازن المستقر", "ar")]],
     300)
card(x, y1+660, w, 3, "ملاحظات T₀",
     [[("لا يتعلق بسعة الاهتزاز (في السعات الصغيرة)", "ar")],
      [("في السعات الكبيرة: كلما زادت θmax زاد T₀", "ar")],
      [("يتعلق بـ g: كلما ارتفعنا زاد T₀", "ar")],
      [("لا يتعلق بالكتلة", "ar")]],
     340)
footer(x, y)

# ================================================================
# S2 — التحريكية: d و d′
# ================================================================
x, y, _ = screens[1]
header(x, y, screens[1][2])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, [("d = oc", "la")],
     [[("d = oc", "la")],
      [("البعد بين نقطة التعليق (محور الدوران)", "ar")],
      [("ومركز عطالة النواس", "ar")]],
     300)
card(x, y1+330, w, 2, "ذراع قوة الثقل",
     [[("d′ = d·sin(θ)", "la")],
      [("ذراع قوة الثقل", "ar")]],
     250)
footer(x, y)

# ================================================================
# S3 — س1) غير توافقية
# ================================================================
x, y, _ = screens[2]
header(x, y, screens[2][2])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "العلاقة الأساسية",
     [[("ΣΓ = IΔ·α", "la")],
      [("Γ_R = 0", "la"), ("  لأن حاملها يلاقي محور الدوران", "ar")],
      [("−d′·W = IΔ·α", "la")],
      [("−mg·d·sin(θ) = IΔ·(θ)″", "la")]],
     380)
card(x, y1+410, w, 2, "النتيجة: غير توافقية",
     [[("(θ)″ = (−mgd/IΔ)·sinθ", "la")],
      [("لوجود sinθ بدلاً من θ ⇐ حركة غير توافقية", "ar")]],
     250)
footer(x, y)

# ================================================================
# S4 — سعات صغيرة + T₀
# ================================================================
x, y, _ = screens[3]
header(x, y, screens[3][2])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, [("سعات صغيرة: ", "ar"), ("θ ≤ 0.24 rad", "la")],
     [[("θ ≤ 0.24 rad", "la"), ("أو", "ar"), ("θ ≤ 14°", "la"), ("⟹", "la"), ("sinθ ≃ θ", "la")],
      [("(θ)″ = −(mgd/IΔ)·θ  …(*)", "la")],
      [("معادلة تفاضلية تقبل حلاً جيبياً", "ar")]],
     300)
card(x, y1+330, w, 2, "الحل + المقارنة",
     [[("θ = θmax·cos(ω₀t+φ)", "la")],
      [("α = −ω₀²·θmax·cos(ω₀t+φ) = −ω₀²·θ", "la")],
      [("بالمقارنة مع (*): ", "ar"), ("ω₀² = mgd/IΔ", "la")],
      [("ω₀ = √(mgd/IΔ) > 0", "la"), ("(", "la"), ("موجبة تماماً", "ar"), (")", "la")]],
     380)
card(x, y1+740, w, 3, "الدور الخاص", [], 200, eq="T₀ = 2π√(IΔ/(mgd)) (s)")
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([("حركة النواس الثقلي المركب جيبية دورانية:", "ar")],
     ["في السعات الصغيرة فقط", "في جميع السعات", "في السعات الكبيرة فقط", "لا يهتز أبداً"], 0),
    ([("شرط الحل الجيبي ", "ar"), ("(sinθ ≃ θ)", "la"), ("هو:", "ar")],
     [[("θ ≤ 0.24 rad", "la"), ("(", "la"), ("أي", "ar"), ("14°)", "la")], "θ ≤ 14 rad", "θ ≥ 0.24 rad", "أي سعة"], 0),
    ([("المعادلة التفاضلية (قبل التقريب):", "ar")],
     ["(θ)″ = (−mgd/IΔ)·sinθ", "(θ)″ = (−mgd/IΔ)·θ", "(θ)″ = (mg/IΔ)·sinθ", "(θ)″ = −ω₀²·sinθ"], 0),
    ([("النبض الخاص ω₀ هو:", "ar")],
     ["√(mgd/IΔ)", "√(IΔ/mgd)", "mgd/IΔ", "2π√(IΔ/mgd)"], 0),
    ([("الدور الخاص T₀ (سعات صغيرة):", "ar")],
     ["2π√(IΔ/(mgd)) (s)", "2π√(mgd/IΔ) (s)", "√(IΔ/mgd) (s)", "2π/(mgd) (s)"], 0),
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

out = "unit-3.1-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
