#!/usr/bin/env python3
# Review screens for U2-04 — نواس الفتل: طرق حل المسألة (map 2.4, blocks 804–843)
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
    (X1, SY, "الشكل العام للتابع الزمني"),
    (X2, SY, "IΔ و K"),
    (X3, SY, "Γn و α"),
    (X1, SY2, "الطاقات"),
    (X2, SY2, "الاختبار الذاتي"),
]
SUB = [("وحدة 2.4 · نواس الفتل", "ar")]

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
        cv.draw_flow(x+w-44, ly+16, [(eq, "la")], 34, cv.CYAN, bold=True)

# ================================================================
# S1 — الشكل العام للتابع الزمني
# ================================================================
x, y, _ = screens[0]
header(x, y, "الشكل العام للتابع الزمني")
dx, dw = x+50, PW-100
cv.draw_flow(dx+dw, y+300, [("θ = θmax·cos(ω₀t+φ)", "la")], 36, cv.CYAN, bold=True)

y1 = y + 400
card(x+40, y1, PW-80, 1, "نجد الثوابت ونعوض",
     [[("سعة الاهتزاز: ", "ar"), ("θmax (rad)", "la")],
      [("سعة الإرسال: ", "ar"), ("θmax = θ", "la"), (" — ترك دون سرعة ابتدائية", "ar")],
      [("النبض الخاص: ", "ar"), ("ω₀ = √(K/IΔ) = 2π/T₀", "la")],
      [("الطور الابتدائي: ", "ar"), ("φ (rad)", "la"), (" — غالباً φ = 0", "ar")]],
     340)
pill(x+PW-44, y+PH-260, [("نعوض الثوابت في التابع الزمني العام", "ar")])
footer(x, y)

# ================================================================
# S2 — IΔ و K
# ================================================================
x, y, _ = screens[1]
header(x, y, [("نحدد ", "ar"), ("IΔ", "la"), (" و ", "ar"), ("K", "la")])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "المطلوب",
     [[("عزم عطالة النواس: ", "ar"), ("IΔ (kg.m²)", "la")],
      [("ثابت فتل السلك: ", "ar"), ("K (m.N.rad⁻¹)", "la")]],
     250)
card(x, y1+280, w, 2, "من أين نجدهما؟",
     [[("إما من: ", "ar"), ("ω₀² = K/IΔ", "la")],
      [("أو من: ", "ar"), ("T₀ = 2π√(IΔ/K)", "la")],
      [("و K أيضاً من: ", "ar"), ("E = (1/2)Kθmax²", "la")],
      [("و IΔ أيضاً من قوانين عزم العطالة", "ar")]],
     360)
footer(x, y)

# ================================================================
# S3 — Γn و α
# ================================================================
x, y, _ = screens[2]
header(x, y, [("Γn", "la"), (" و ", "ar"), ("α", "la")])
w = PW - 80
y1 = y + 250
card(x, y1, w, 1, "عند θ معلومة",
     [[("عزم الارجاع (مزدوجة الفتل): ", "ar"), ("Γn (m.N)", "la")],
      [("التسارع الزاوي: ", "ar"), ("α (rad.s⁻²)", "la")],
      [("−Kθ = Γn", "la"), (" و ", "ar"), ("α = −ω₀²θ", "la")]],
     310)
card(x, y1+340, w, 2, "عند t معلومة",
     [[("ω = −ω₀θmax·sin(ω₀t+φ)", "la")],
      [("α = −ω₀²θmax·cos(ω₀t+φ)", "la")]],
     250)
card(x, y1+620, w, 3, "عند مركز الاهتزاز",
     [[("α = 0", "la"), (" و ", "ar"), ("ωmax = ∓ω₀·θmax", "la")],
      [("المرورات الزوجية موجبة", "ar"), (" — إذا انطلق من مطال موجب", "ar")],
      [("سالبة — إذا انطلق من مطال سالب", "ar")]],
     310)
footer(x, y)

# ================================================================
# S4 — الطاقات
# ================================================================
x, y, _ = screens[3]
header(x, y, [("الطاقات ", "ar"), ("E (J)", "la")])
w = PW - 80
y1 = y + 270
card(x, y1, w, 1, "عند θ معلومة",
     [[("E = (1/2)Kθmax²", "la"), (" ← ", "la"), ("Ep = (1/2)Kθ²", "la"), (" ← ", "la"), ("Ek = E − Ep", "la")],
      [("أو مباشرة: ", "ar"), ("Ek = (1/2)K[θmax² − θ²]", "la")]],
     260)
card(x, y1+290, w, 2, "عند ω معلومة",
     [[("Ek = (1/2)IΔ·ω²", "la"), (" ← ", "la"), ("E = (1/2)Kθmax²", "la"), (" ← ", "la"), ("Ep = E − Ek", "la")],
      [("نبدأ من الطاقة الحركية Ek", "ar")]],
     260)
pill(x+PW-44, y+PH-260,
     [("IΔ و K تحسبان هنا من ω₀² أو T₀", "ar")])
footer(x, y)

# ================================================================
# S5 — MCQ
# ================================================================
x, y, _ = screens[4]
header(x, y, "الاختبار الذاتي")
pill(x+PW-44, y+186, [("سؤال متجدد ", "ar"), ("⟳", "la")])
qy = y + 260
qs = [
    ([(("التابع الزمني للمطال لنواس الفتل بالشكل العام هو:", "ar"))],
     ["θ = θmax·cos(ω₀t+φ)", "θ = θmax·sin(ω₀t)", "θ = ω₀·t", "θ = θmax/ω₀"], 0),
    ([(("النبض الخاص ω₀ نوجده من:", "ar"))],
     ["ω₀ = √(K/IΔ) = 2π/T₀", "ω₀ = K/IΔ", "ω₀ = IΔ/K", "ω₀ = T₀/2π"], 0),
    ([(("IΔ و K نحددهما من:", "ar"))],
     ["ω₀² = K/IΔ أو T₀ = 2π√(IΔ/K)", "ω₀ = K/IΔ", "T₀ = √(K/IΔ)", "E = (1/2)IΔ·ω"], 0),
    ([(("عند θ معلومة، عزم الارجاع والتسارع الزاوي هما:", "ar"))],
     ["Γn = −K·θ و α = −ω₀²·θ", "Γn = K·θ و α = ω₀²·θ", "Γn = −K·ω و α = 0", "Γn = IΔ·θ و α = K·θ"], 0),
    ([(("عند مرور نواس الفتل في مركز الاهتزاز:", "ar"))],
     ["α = 0 و ωmax = ∓ω₀θmax", "α = ω₀²θmax و ω = 0", "α = 0 و ω = 0", "α = K·θmax و ωmax = ω₀/θmax"], 0),
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

out = "unit-2.4-review.png"
img.convert("RGB").save(out)
print("saved", img.size, "->", out)
