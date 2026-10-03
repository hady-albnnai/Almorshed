# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.13: أنماط مسائل (تطبيقات) — vmax في مركز الاهتزاز
مسألة (3/18) · مسألة (4/18) · مسألة (1)  —  الكتل 568–669"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
H = 4940
cv = ReviewCanvas(W, H)
d = cv.d
img = cv.img
XR = 2400

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.13", "ar"), (" — ", "la"), ("أنماط مسائل تطبيقية: ", "ar"), ("vmax", "la"), (" في مركز الاهتزاز", "ar")], 44, TXT, bold=True)
pr = XR
for segs, tc, bc, bg in [
    ([("النص حرفي من النوط ", "ar"), ("+ ", "la"), ("تصحيحات ", "ar"), ("R1–R14", "la")], BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ([("فلاشات النوط: ", "ar"), ("F0093–F0106 ", "la"), ("نصوص المسائل", "ar")], TXT2, LINE, CARD),
    ([("3 مسائل محلولة ", "ar"), ("+ ", "la"), ("4 بطاقات ", "ar"), ("+ ", "la"), ("5 أسئلة", "ar")], TXT2, LINE, CARD),
]:
    tw = cv.flow_width(segs, 22, True)
    w = tw + 48
    cv.alpha_rect(pr - w, 214, w, 54, bg, radius=27)
    d.rounded_rectangle([pr - w, 214, pr - 1, 267], radius=27, outline=_c4(bc), width=2)
    cv.draw_flow(pr - 24, 214 + 39, segs, 22, tc, bold=True)
    pr -= w + 20

# ============================ الشبكة ============================
SY, PW, PH = 330, 760, 1350
X1, X2, X3 = XR - PW, XR - 2 * PW - 30, XR - 3 * PW - 60
SY2 = 1860
SY3 = 3390
SUB = "الوحدة 1.13 · النواس المرن"


def top_pill(pl, pr, sy, segs, extra=None):
    w = cv.flow_width(segs, 19, True) + 44
    x = pr - 24
    cv.alpha_rect(x - w, sy + 100, w, 48, (45, 212, 167, 26), radius=24)
    d.rounded_rectangle([x - w, sy + 100, x - 1, sy + 147], radius=24, outline=(45, 212, 167, 100), width=2)
    cv.draw_flow(x - 22, sy + 134, segs, 19, BRAND, bold=True)
    x = x - w - 12
    if extra:
        x = cv.pill_r(x, sy + 100, extra, 19, TXT2, LINE, CARD2)
    return x


def sol_box(pl, pr, y, num, title_segs, math_lines, color=BRAND2):
    """صندوق حل: عنوان + أسطر معادلات. ي return y الجديد"""
    n_lines = len(math_lines)
    h = 64 + n_lines * 34 + 18
    cv.card(pl + 8, y, pr - pl - 16, h, 18, CARD2, border=LINE)
    cv.number_badge(pl + 24, y + 16, num, color)
    cv.draw_flow(pr - 40, y + 40, title_segs, 20, TXT, bold=True)
    d.line([(pl + 40, y + 56), (pr - 32, y + 56)], fill=_c4(LINE), width=2)
    yy = y + 90
    for line in math_lines:
        if isinstance(line, str):
            cv.draw_flow(pr - 40, yy, [(line, "la")], 19, MATHC)
        else:
            cv.draw_flow(pr - 40, yy, line, 19, MATHC)
        yy += 34
    return y + h + 16


def answer_pill(pl, pr, y, segs, h=64):
    w = cv.flow_width(segs, 22, True) + 56
    x = pr - 24
    cv.alpha_rect(x - w, y, w, h, (45, 212, 167, 20), radius=h // 2)
    d.rounded_rectangle([x - w, y, x - 1, y + h - 1], radius=h // 2, outline=(45, 212, 167, 110), width=2)
    cv.draw_flow(x - 28, y + h - 22, segs, 22, BRAND, bold=True)
    return y + h


# ---------- S1 (X1): مسألة 3/18 — النص + البيانات + x0 ----------
pl, pr = cv.phone(X1, SY, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY, [("مسألة ", "ar"), ("(3/18)", "la")], extra="من المسألة")
yy = SY + 196
cv.draw_flow(pr - 24, yy, [("نشكل هزازة توافقية بسيطة من جسم كتلته ", "ar"), ("m = 1 kg", "la"),
                           (" معلق بطرف نابض أفقي مهمل الكتلة حلقاته متباعدة ثابت صلابته ", "ar"), ("k", "la"), (".", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("فيبتزم ", "ar"), ("10", "la"), (" دورات في ", "ar"), ("10 s", "la"),
                           (" ويرسم في أثناء حركته قطعة مستقيمة طولها ", "ar"), ("16 cm", "la"), (".", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("المطلوب: ", "ar"), ("1)", "la"), (" ", "ar"), ("Ep–x", "la"), (" وقيمتها  ", "ar"),
                           ("2)", "la"), (" ", "ar"), ("vmax", "la"), ("  ", "ar"),
                           ("3)", "la"), (" ", "ar"), ("a", "la"), (" عند ", "ar"), ("x = 6 cm", "la"),
                           ("  ", "ar"), ("4)", "la"), (" ", "ar"), ("Ep", "la"), (" و", "ar"), ("Ek", "la"),
                           (" عند ", "ar"), ("x = −4 cm", "la")], 18, BRAND, bold=True)
yy += 50
by = yy
by = sol_box(pl, pr, by, 1, [("البيانات: ", "ar"), ("T₀", "la"), (" و", "ar"), ("Xmax", "la")],
             ["T₀ = t/n = 10/10 = 1 s",
              "Xmax = d/2 = (16×10⁻²)/2 = 8×10⁻² m"])
by = sol_box(pl, pr, by, 2, [("x₀ — ", "la"), ("استنتاج وحساب من النوط", "ar")],
             ["x₀ = (m·g)/k = g/ω₀²",
              "ω₀ = 2π/T₀ = 2π rad·s⁻¹",
              "k = ω₀²·m = 40×1 = 40 N/m",
              "x₀ = (1×10)/40 = 0,25 m"])
answer_pill(pl, pr, by + 10, [("T₀ = 1 s  ·  Xmax = 8×10⁻² m  ·  x₀ = 0,25 m", "la")])
cv.bottom_bar(X1, SY + PH - 96, PW)

# ---------- S2 (X2): مسألة 3/18 — الحل 1) 2) ----------
pl, pr = cv.phone(X2, SY, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY, [("الحل ", "ar"), ("1)", "la"), (" و", "ar"), ("2)", "la")])
by = SY + 196
by = sol_box(pl, pr, by, 1, [("1)", "la"), (" علاقة الطاقة الكامنة الاستطونة بمطاله", "ar")],
             ["Ep = ½kx²",
              "k = ω₀²·m = (2π)²×1 = 4π² ≈ 40 N/m",
              "Ep = ½×40×x² = 20x² J"])
by = sol_box(pl, pr, by, 2, [("2)", "la"), (" السرعة العظمى في مركز الاهتزاز", "ar")],
             ["vmax = ω₀Xmax",
              "vmax = 2π×8×10⁻² = 0,5 m/s"])
answer_pill(pl, pr, by + 10, [("k = 40 N/m  ·  Ep = 20x² J  ·  vmax = 0,5 m/s", "la")])
cv.bottom_bar(X2, SY + PH - 96, PW)

# ---------- S3 (X3): مسألة 3/18 — الحل 3) 4) ----------
pl, pr = cv.phone(X3, SY, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY, [("الحل ", "ar"), ("3)", "la"), (" و", "ar"), ("4)", "la")])
by = SY + 196
by = sol_box(pl, pr, by, 3, [("3)", "la"), (" التسارع عند ", "ar"), ("x = 6 cm", "la")],
             ["a = −ω₀²x",
              "a = −40×6×10⁻² = −2,4 m/s²"])
by = sol_box(pl, pr, by, 4, [("4)", "la"), (" الطاقات عند ", "ar"), ("x = −4 cm", "la")],
             ["Ep = ½kx² = ½×40×16×10⁻⁴",
              "Ep = 32×10⁻³ J",
              "Ek = ½k[X²max−x²] = ½×40×48×10⁻⁴",
              "Ek = 96×10⁻³ J",
              [("طريقة ثانية: ", "ar"), ("E = ½kX²max = 128×10⁻³ J", "la")],
              "Ek = E−Ep = (128−32)×10⁻³ = 96×10⁻³ J"])
answer_pill(pl, pr, by + 10, [("a = −2,4 m/s²  ·  Ep = 32×10⁻³ J  ·  Ek = 96×10⁻³ J", "la")])
cv.bottom_bar(X3, SY + PH - 96, PW)

# ---------- S4 (X1, صف 2): مسألة 4/18 — النص + معادلة الحركة ----------
pl, pr = cv.phone(X1, SY2, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY2, [("مسألة ", "ar"), ("(4/18)", "la")], extra="من المسألة")
yy = SY2 + 196
cv.draw_flow(pr - 24, yy, [("تتدلى كرة معدنية كتلتها ", "ar"), ("m", "la"),
                           (" بمرونة نابض شاقولي مهمل الكتلة حلقاته متباعدة ثابت صلابته ", "ar"),
                           ("k = 16 N/m", "la"), (".", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("بحركة توافقية بسيطة دورها الخاص ", "ar"), ("T₀ = 1 s", "la"),
                           (" وسعة اهتزازها ", "ar"), ("Xmax = 0,1 m", "la"), (".", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("وبفرض مبدأ الزمن لحظة مرورها بنقطة مطالها ", "ar"), ("Xmax/2", "la"),
                           (" وهي تتحرك بالاتجاه السالب.", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("المطلوب: ", "ar"), ("1)", "la"), (" معادلة الحركة  ", "ar"),
                           ("2)", "la"), (" مرور المركز الأول والثالث  ", "ar"),
                           ("3)", "la"), (" ", "ar"), ("F", "la"), (" عند ", "ar"),
                           ("x = +0,1 m", "la"), ("  ", "ar"), ("4)", "la"), (" كتلة الكرة", "ar")], 18, BRAND, bold=True)
yy += 50
by = yy
by = sol_box(pl, pr, by, 1, [("1)", "la"), (" معادلة الحركة", "ar")],
             ["x = Xmax·cos(ω₀t + φ)",
              "ω₀ = 2π/T₀ = 2π rad·s⁻¹",
              "t = 0:  x = Xmax/2  ⟹  cos φ = 1/2",
              "⟹  φ = ±π/3"])
by = sol_box(pl, pr, by, 2, [("اختيار إشارة ", "ar"), ("φ", "la"), (" من اتجاه الحركة", "ar")],
             ["v = −ω₀Xmax·sin φ",
              [("φ = π/3 ⟹ ", "la"), ("v < 0", "la"), (" مقبول، والاتجاه سالب", "ar")],
              [("φ = −π/3 ⟹ ", "la"), ("v > 0", "la"), (" مرفوض", "ar")],
              "x = 0,1·cos(2πt + π/3)"])
answer_pill(pl, pr, by + 10, [("x = 0,1·cos(2πt + π/3)", "la")])
cv.bottom_bar(X1, SY2 + PH - 96, PW)

# ---------- S5 (X2, صف 2): مسألة 4/18 — الحل 2) 3) 4) ----------
pl, pr = cv.phone(X2, SY2, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY2, [("الحل ", "ar"), ("2) 3) 4)", "la")])
by = SY2 + 196
by = sol_box(pl, pr, by, 2, [("2)", "la"), (" المرور الأول والثالث في مركز التوازن", "ar")],
             ["x = 0:  cos(2πt + π/3) = 0",
              "2πt + π/3 = π/2 + πK",
              [("أول مرور ", "ar"), ("(K = 0):  2t₁ = 1/2 − 1/3 = 1/6", "la")],
              "⟹  t₁ = 1/12 s",
              [("ثالث مرور ", "ar"), ("(K = 2):  2t₃ = 1/2 + 2 − 1/3 = 13/6", "la")],
              "⟹  t₃ = 13/12 s"])
by = sol_box(pl, pr, by, 3, [("3)", "la"), (" شدة قوة الارجاع عند ", "ar"), ("x = +0,1 m", "la")],
             ["F = k·x = 16×0,1 = 1,6 N"])
by = sol_box(pl, pr, by, 4, [("4)", "la"), (" كتلة الكرة", "ar")],
             ["ω₀² = k/m  ⟹  m = k/ω₀²",
              "m = 16/40 = 0,4 kg"])
answer_pill(pl, pr, by + 10, [("t₁ = 1/12 s  ·  t₃ = 13/12 s  ·  F = 1,6 N  ·  m = 0,4 kg", "la")])
cv.bottom_bar(X2, SY2 + PH - 96, PW)

# ---------- S6 (X3, صف 2): بطاقات المراجعة (4) ----------
pl, pr = cv.phone(X3, SY2, PW, PH, "بطاقات المراجعة", SUB)
cards = [
    ("الثوابت من البيان",
     [[("T₀ = t/n", "la"), (" عدد الدورات ", "ar"), ("n", "la"), (" في زمن ", "ar"), ("t", "la"),
       ("  ·  ", "la"), ("Xmax = d/2", "la"), (" حيث ", "ar"), ("d", "la"),
       (" القطعة المقطوعة بين المطالين الأعظميين", "ar")]]),
    ("السرعة العظمى",
     [[("vmax = ω₀Xmax = (2π/T₀)·Xmax", "la")],
      [("السرعة أعظمى في مركز الاهتزاز ومعدومة في المطالين الأعظميين", "ar")]]),
    ([("الطور الابتدائي ", "ar"), ("φ", "la")],
     [[("من ", "ar"), ("x(t=0) = Xmax·cos φ", "la"), (" يكون ", "ar"), ("cos φ = x₀/Xmax", "la")],
      [("ثم تختار الإشارة من اتجاه الحركة عبر ", "ar"), ("v = −ω₀Xmax·sin φ", "la")]]),
    ("المرور في مركز الاهتزاز",
     [[("x = 0  ⟹  ω₀t + φ = π/2 + πK", "la")],
      [("أول مرور ", "ar"), ("K = 0", "la"), ("  ·  ", "la"), ("ثاني مرور ", "ar"), ("K = 1", "la"),
       ("  ·  ", "la"), ("ثالث مرور ", "ar"), ("K = 2", "la")]]),
]
by = SY2 + 100
for ci, (title, lines) in enumerate(cards):
    ch = 70 + len(lines) * 34 + 14
    cv.card(pl + 8, by, pr - pl - 16, ch, 18, CARD, border=LINE)
    cv.number_badge(pl + 24, by + 18, ci + 1, BRAND)
    title_segs = title if isinstance(title, list) else [(title, "ar")]
    cv.draw_flow(pr - 40, by + 42, title_segs, 21, TXT, bold=True)
    d.line([(pl + 40, by + 58), (pr - 32, by + 58)], fill=_c4(LINE), width=2)
    yy = by + 88
    for line in lines:
        cv.draw_flow(pr - 40, yy, line, 17, TXT2)
        yy += 34
    by += ch + 18
cv.bottom_bar(X3, SY2 + PH - 96, PW)

# ---------- S7 (X1, صف 3): مسألة (1) — النص + vmax + ω₀ + Xmax ----------
pl, pr = cv.phone(X1, SY3, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY3, [("مسألة ", "ar"), ("(1) — ", "la"), ("سلسلة التطبيقات", "ar")])
yy = SY3 + 196
cv.draw_flow(pr - 24, yy, [("هزازة توافقية بسيطة مؤلفة من نابض مرن شاقولي مهمل الكتلة حلقاته متباعدة", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("ثابت صلابته ", "ar"), ("k = 10 N/m", "la"),
                           ("، مربوط عند نهايته الثانية بجسم كتلته ", "ar"), ("m = 0,1 kg", "la"),
                           (" مثبت بنقطة ثابتة.", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("مبدأ الزمن لحظة مرور الجسم في مركز الاهتزاز متحركًا سالبًا بسرعة ", "ar"),
                           ("v = −3 m/s", "la"), (".", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("المطلوب: ", "ar"), ("1)", "la"), (" الدور  ", "ar"),
                           ("2)", "la"), (" معادلة الحركة  ", "ar"), ("3)", "la"), (" ", "ar"),
                           ("F", "la"), (" عند مطال ", "ar"), ("3 cm", "la")], 18, BRAND, bold=True)
yy += 50
by = yy
by = sol_box(pl, pr, by, 1, [("مرور في مركز الاهتزاز", "ar")],
             [[("v = vmax = −3 m/s", "la"), ("  السرعة عظمى في مركز الاهتزاز، و", "ar"), ("v < 0", "la")]])
by = sol_box(pl, pr, by, 2, [("1)", "la"), (" الدور عبر ", "ar"), ("ω₀", "la")],
             ["ω₀ = √(k/m) = √(10/10⁻¹) = 10 rad·s⁻¹",
              "T₀ = 2π/ω₀ = 2π/10 s"])
by = sol_box(pl, pr, by, 3, [("2)", "la"), (" السعة والطور", "ar")],
             ["Xmax = vmax/ω₀ = 3/10 = 0,3 m",
              "t = 0:  0 = Xmax·cos φ  ⟹  φ = ±π/2",
              [("φ = π/2 ⟹ ", "la"), ("v < 0", "la"), (" مقبول  ", "ar"), ("·  ", "la"),
               ("φ = −π/2 ⟹ ", "la"), ("v > 0", "la"), (" مرفوض", "ar")]])
cv.bottom_bar(X1, SY3 + PH - 96, PW)

# ---------- S8 (X2, صف 3): مسألة (1) — معادلة الحركة + F + الأنماط ----------
pl, pr = cv.phone(X2, SY3, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY3, [("الحل ", "ar"), ("2)", "la"), (" و", "ar"), ("3)", "la"), (" والأنماط", "ar")])
by = SY3 + 196
by = sol_box(pl, pr, by, 2, [("2)", "la"), (" معادلة الحركة", "ar")],
             ["x = 0,3·cos(10t + π/2)"])
by = sol_box(pl, pr, by, 3, [("3)", "la"), (" شدة قوة الارجاع عند ", "ar"), ("x = 3 cm", "la")],
             ["F = k·x = 10×3×10⁻² = 0,3 N"])
# صندوق الأنماط (أسود)
by += 24
cv.card(pl + 8, by, pr - pl - 16, 316, 18, (14, 24, 42), border=(45, 212, 167, 90))
cv.draw_flow(pr - 40, by + 34, [("أنماط الوحدة ", "ar"), ("— ", "la"), ("خلاصة", "ar")], 21, BRAND, bold=True)
d.line([(pl + 40, by + 50), (pr - 32, by + 50)], fill=_c4((45, 212, 167, 60)), width=2)
pat = [
    [("①  ", "la"), ("T₀ = t/n", "la"), (" و", "ar"), ("Xmax = d/2", "la")],
    [("②  ", "la"), ("vmax = ω₀Xmax", "la"), (" في المركز، و", "ar"), ("a = −ω₀²x", "la")],
    [("③  ", "la"), ("Ep = ½kx²", "la"), (" و", "ar"), ("Ek = E − Ep", "la"), (" — ", "la"), ("E", "la"), (" ثابتة", "ar")],
    [("④  ", "la"), ("φ", "la"), (" من الشروط الابتدائية عبر ", "ar"), ("v = −ω₀Xmax·sin φ", "la")],
    [("⑤  ", "la"), ("مرور المركز: ", "ar"), ("ω₀t + φ = π/2 + πK", "la"), ("  أول: ", "ar"), ("K = 0", "la"), ("  ثالث: ", "ar"), ("K = 2", "la")],
]
yy = by + 82
for line in pat:
    cv.draw_flow(pr - 40, yy, line, 17, TXT)
    yy += 38
answer_pill(pl, pr, by + 340, [("ω₀ = 10 rad·s⁻¹  ·  x = 0,3·cos(10t + π/2)  ·  F = 0,3 N", "la")])
cv.bottom_bar(X2, SY3 + PH - 96, PW)

# ---------- S9 (X3, صف 3): الاختبار الذاتي (5) ----------
pl, pr = cv.phone(X3, SY3, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([[("10", "la"), (" دورات في ", "ar"), ("10 s", "la"), ("، الدور ", "ar"), ("T₀", "la"), (":", "la")]],
     [[("1 s", "la")], [("10 s", "la")], [("0,1 s", "la")], [("2 s", "la")]]),
    ([[("القطعة المقطوعة بين المطالين ", "ar"), ("16 cm", "la"), ("، ", "ar"), ("Xmax", "la"), (" تساوي:", "ar")]],
     [[("8 cm", "la")], [("16 cm", "la")], [("4 cm", "la")], [("32 cm", "la")]]),
    ([[("السرعة في مركز الاهتزاز:", "ar")]],
     [[("عظمى", "ar")], [("معدومة", "ar")], [("متوسطة", "ar")], [("أدنى", "ar")]]),
    ([[("عند ", "ar"), ("t = 0", "la"), (" الجسم عند ", "ar"), ("Xmax/2", "la"), (" متحركًا بالاتجاه السالب، ", "ar"), ("φ", "la"), (" يساوي:", "ar")]],
     [[("π/3", "la")], [("−π/3", "la")], [("π/2", "la")], [("صفر", "ar")]]),
    ([[("عند ", "ar"), ("x = −4×10⁻² m", "la"), (" وثابت الصلابة ", "ar"), ("k = 40 N/m", "la"), ("، ", "ar"), ("Ep", "la"), (" تساوي:", "ar")]],
     [[("32×10⁻³ J", "la")], [("16×10⁻³ J", "la")], [("96×10⁻³ J", "la")], [("128×10⁻³ J", "la")]]),
]
by = SY3 + 88
letters = ["أ", "ب", "ج", "د"]
for qi, (stem_lines, opts) in enumerate(qs):
    qh = 214
    cv.card(pl, by, pr - pl, qh, 22, CARD, border=LINE)
    cv.number_badge(pl + 18, by + 16, qi + 1, BRAND2)
    yy = by + 42
    for line in stem_lines:
        cv.draw_flow(pr - 24, yy, line, 18, TXT)
        yy += 28
    yy += 2
    for oi, segs in enumerate(opts[:4]):
        row_h = 36
        correct = (oi == 0)
        cv.a_rounded(pl + 24, yy, pr - 24, yy + row_h - 6, 11,
                     fill=(45, 212, 167, 30) if correct else (28, 43, 71, 120),
                     outline=(45, 212, 167, 140) if correct else None)
        d.ellipse([pl + 36, yy + 4, pl + 60, yy + 28], fill=CARD2, outline=_c4(LINE), width=2)
        lw_ = text_width(letters[oi], NASKH, 15, True)
        draw_rtl(img, pl + 48 + lw_ // 2, yy + 24, letters[oi], 15, TXT2, bold=True)
        opt_color = BRAND if correct else TXT2
        if correct:
            cv.check(pr - 44, yy + 16, 9, BRAND, wdt=4)
        cv.draw_flow(pr - 68, yy + 24, segs, 16, opt_color, bold=correct)
        yy += row_h + 4
    by += qh + 10
cv.a_rounded(pr - 230, SY3 + PH - 104, pr - 24, SY3 + PH - 56, 24,
             fill=(45, 212, 167, 26), outline=(45, 212, 167, 120))
cv.refresh(pr - 130, SY3 + PH - 80, 14, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY3 + PH - 68, "سؤال جديد", 20, BRAND, bold=True)

# ============================ التسميات ============================
row1 = [
    ([("مسألة ", "ar"), ("(3/18) — ", "la"), ("البيانات", "ar")], X1),
    ([("Ep–x", "la"), (" و", "ar"), (" vmax", "la")], X2),
    ([("a", "la"), (" و", "ar"), (" Ep", "la"), (" و", "ar"), ("Ek", "la")], X3),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([("مسألة ", "ar"), ("(4/18) — ", "la"), ("معادلة الحركة", "ar")], X1),
    ([("المرور و", "ar"), (" F", "la"), (" و", "ar"), (" m", "la")], X2),
    ([("بطاقات المراجعة ", "ar"), ("(4)", "la")], X3),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
row3 = [
    ([("مسألة ", "ar"), ("(1): ", "la"), ("ω₀", "la"), (" و", "ar"), (" Xmax", "la")], X1),
    ([("F", "la"), (" والأنماط", "ar")], X2),
    ([("الاختبار الذاتي ", "ar"), ("(5", "la"), (" قوالب", "ar"), (")", "la")], X3),
]
for segs, x in row3:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY3 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY3 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني", "ar"), (" · ", "la"), ("الوحدة 1.13 من 73", "ar"), (" · ", "la"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.13-review.png")
