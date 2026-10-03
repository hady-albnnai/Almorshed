# -*- coding: utf-8 -*-
"""مراجعة المادة — الوحدة 1.14: أنماط مسائل متقدمة (تجميعية) — مسألة (2)
معادلة الحركة + أزمنة المرور + محصلة القوى + k + كتلة بدور جديد — الكتل 670–716"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from review_common import *
from review_common import ReviewCanvas, _c4
from rtl_text import (draw_rtl, draw_ltr, text_width,
                      NASKH, SANS, DEJAVU, DEJAVU_B, DEJAVU_SI)

W = 2480
H = 3420
cv = ReviewCanvas(W, H)
d = cv.d
img = cv.img
XR = 2400

# ============================ الرأس ============================
draw_rtl(img, XR, 84, "مراجعة المادة — نوطة النواسات", 24, BRAND2, path=SANS, bold=True)
cv.draw_flow(XR, 162, [("الوحدة 1.14", "ar"), (" — ", "la"), ("أنماط متقدمة تجميعية: ", "ar"), ("(2)", "la")], 44, TXT, bold=True)
pr = XR
for segs, tc, bc, bg in [
    ([("النص حرفي من النوط ", "ar"), ("+ ", "la"), ("تصحيحات ", "ar"), ("R1–R14", "la")], BRAND, (45, 212, 167, 100), (45, 212, 167, 16)),
    ([("فلاشات النوط: ", "ar"), ("F0105–F0108 ", "la"), ("نص المسألة والحل", "ar")], TXT2, LINE, CARD),
    ([("مسألة تجميعية ", "ar"), ("5", "la"), (" متطلبات ", "ar"), ("+ ", "la"), ("4 بطاقات ", "ar"), ("+ ", "la"), ("5 أسئلة", "ar")], TXT2, LINE, CARD),
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
SUB = "الوحدة 1.14 · النواس المرن"


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


# ---------- S1 (X1): مسألة (2) — النص + البيانات ----------
pl, pr = cv.phone(X1, SY, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY, [("مسألة ", "ar"), ("(2) — ", "la"), ("سلسلة التطبيقات", "ar")], extra="من المسألة")
yy = SY + 196
cv.draw_flow(pr - 24, yy, [("تهتز نقطة مادية كتلتها ", "ar"), ("m = 0.5 kg", "la"),
                           (" ممرودة بنابض مهمل الكتلة حلقاته متباعدة.", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("بحركة توافقية بسيطة دورها الخاص ", "ar"), ("T₀ = 4 s", "la"),
                           (" وسعة اهتزازها ", "ar"), ("Xmax = 8 cm", "la"), (".", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("عند ", "ar"), ("t = 0", "la"), (" كانت النقطة في موضع مطالها ", "ar"),
                           ("Xmax/2", "la"), (" وهي تتحرك بالاتجاه السالب.", "ar")], 18, TXT); yy += 30
cv.draw_flow(pr - 24, yy, [("المطلوب: ", "ar"), ("1)", "la"), (" تابع الزمن ثم تعيين الثوابت  ", "ar"),
                           ("2)", "la"), (" مرور المركز الأول والثالث  ", "ar"),
                           ("3)", "la"), (" محصلة القوى  ", "ar"), ("4)", "la"), (" k", "la"),
                           (" 5)", "la"), (" كتلة تجعل الدور ", "ar"), ("1 s", "la")], 18, BRAND, bold=True)
yy += 50
by = yy
by = sol_box(pl, pr, by, 1, [("قراءة البيانات", "ar")],
             ["T₀ = 4 s  ·  Xmax = 8×10⁻² m",
              "m = 5×10⁻¹ kg",
              [("t = 0:  x = Xmax/2  ·  v < 0 ", "la"), ("اتجاه سالب", "ar")]])
answer_pill(pl, pr, by + 10, [("T₀ = 4 s  ·  Xmax = 8×10⁻² m  ·  m = 5×10⁻¹ kg", "la")])
cv.bottom_bar(X1, SY + PH - 96, PW)

# ---------- S2 (X2): الحل 1) معادلة الحركة ----------
pl, pr = cv.phone(X2, SY, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY, [("الحل ", "ar"), ("1)", "la")])
by = SY + 196
by = sol_box(pl, pr, by, 1, [("الشكل العام", "ar")],
             ["x = Xmax·cos(ω₀t + φ)",
              "ω₀ = 2π/T₀ = 2π/4 = π/2 rad·s⁻¹"])
by = sol_box(pl, pr, by, 2, [("الطور الابتدائي ", "ar"), ("φ", "la")],
             ["t = 0:  x = Xmax/2  ⟹  cos φ = 1/2",
              "⟹  φ = ±π/3",
              [("φ = π/3 ⟹ ", "la"), ("v < 0", "la"), (" مقبول، والاتجاه سالب", "ar")],
              [("φ = −π/3 ⟹ ", "la"), ("v > 0", "la"), (" مرفوض", "ar")]])
by = sol_box(pl, pr, by, 3, [("معادلة الحركة", "ar")],
             ["x = 0.08·cos((π/2)t + π/3)"])
answer_pill(pl, pr, by + 10, [("x = 0.08·cos((π/2)t + π/3)", "la")])
cv.bottom_bar(X2, SY + PH - 96, PW)

# ---------- S3 (X3): الحل 2) أزمنة المرور ----------
pl, pr = cv.phone(X3, SY, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY, [("الحل ", "ar"), ("2)", "la")])
by = SY + 196
by = sol_box(pl, pr, by, 1, [("المرور في مركز التوازن ", "ar"), ("x = 0", "la")],
             ["0 = 0.08·cos((π/2)t + π/3)",
              "cos((π/2)t + π/3) = 0",
              "(π/2)t + π/3 = π/2 + πK"])
by = sol_box(pl, pr, by, 2, [("أزمنة المرور", "ar")],
             [[("أول مرور ", "ar"), ("(K = 0):  (1/2)t₁ = 1/2 − 1/3 = 1/6", "la")],
              "⟹  t₁ = 1/3 s",
              [("ثالث مرور ", "ar"), ("(K = 2):  (1/2)t₃ = 1/2 + 2 − 1/3 = 13/6", "la")],
              "⟹  t₃ = 13/3 s"])
answer_pill(pl, pr, by + 10, [("t₁ = 1/3 s  ·  t₃ = 13/3 s", "la")])
cv.bottom_bar(X3, SY + PH - 96, PW)

# ---------- S4 (X1, صف 2): الحل 3) 4) ----------
pl, pr = cv.phone(X1, SY2, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY2, [("الحل ", "ar"), ("3)", "la"), (" و", "ar"), ("4)", "la")])
by = SY2 + 196
by = sol_box(pl, pr, by, 3, [("3)", "la"), (" محصلة القوى الخارجية ", "ar"), ("= ", "la"), ("قوة ارجاع", "ar")],
             ["F = −k·x",
              [("عظمى شدة في المطالين الأعظميين:  ", "ar"), ("Fmax = k·Xmax", "la")],
              "(5/4)×8×10⁻² = 10⁻¹ N",
              [("معدومة في مركز الاهتزاز:  ", "ar"), ("F = 0  ⇐  x = 0", "la")]])
by = sol_box(pl, pr, by, 4, [("4)", "la"), (" ثابت الصلابة", "ar")],
             ["k = ω₀²·m = (10/4)×5×10⁻¹ = 5/4 = 1,25 N/m"])
by = sol_box(pl, pr, by, 5, [("هل يتغير ", "ar"), ("k", "la"), (" بتغير الكتلة؟", "ar")],
             ["k = ω₀²·m = (k/m)·m = k",
              [("ثابت الصلابة لا يتعلق بكتلة الجسم، يتغير بتغير النابض", "ar")]])
answer_pill(pl, pr, by + 10, [("Fmax = 10⁻¹ N  ·  k = 1,25 N/m", "la")])
cv.bottom_bar(X1, SY2 + PH - 96, PW)

# ---------- S5 (X2, صف 2): الحل 5) + بطاقات ----------
pl, pr = cv.phone(X2, SY2, PW, PH, "نواس المرن", SUB)
top_pill(pl, pr, SY2, [("الحل ", "ar"), ("5)", "la"), (" + ", "la"), ("البطاقات", "ar")])
by = SY2 + 196
by = sol_box(pl, pr, by, 5, [("5)", "la"), (" كتلة تجعل الدور ", "ar"), ("T₀′ = 1 s", "la")],
             ["T₀′ = 2π√(m′/k)",
              "m′ = (T₀′²·k)/40 = (1×5/4)/40",
              "m′ = 5/160 = 1/32 kg"])
by = answer_pill(pl, pr, by + 10, [("m′ = 1/32 kg", "la")])
by += 40
cards = [
    ([("ω₀", "la"), (" من الدور", "ar")],
     [[("ω₀ = 2π/T₀ ", "la"), ("عند ", "ar"), ("T₀ = 4 s", "la"), (" يكون ", "ar"), ("ω₀ = π/2", "la")]]),
    ("محصلة القوى",
     [[("F = −k·x", "la")],
      [("عظمى شدة في المطالين الأعظميين ", "ar"), ("(Fmax = k·Xmax)", "la"),
       (" ومعدومة في مركز الاهتزاز", "ar")]]),
    ("معادلة الحركة",
     [[("x = Xmax·cos(ω₀t + φ)", "la")],
      [("الإشارة من اتجاه الحركة عبر ", "ar"), ("v = −ω₀Xmax·sin φ", "la")]]),
    ([("k", "la"), (" والكتلة", "ar")],
     [[("k = ω₀²·m", "la"), ("  لا يتعلق بكتلة الجسم، يتغير بالنابض", "ar")],
      [("m′ = (T₀′²·k)/40", "la")]]),
]
for ci, (title, lines) in enumerate(cards):
    ch = 70 + len(lines) * 30 + 12
    cv.card(pl + 8, by, pr - pl - 16, ch, 18, CARD, border=LINE)
    cv.number_badge(pl + 24, by + 16, ci + 1, BRAND)
    title_segs = title if isinstance(title, list) else [(title, "ar")]
    cv.draw_flow(pr - 40, by + 40, title_segs, 20, TXT, bold=True)
    d.line([(pl + 40, by + 54), (pr - 32, by + 54)], fill=_c4(LINE), width=2)
    yy = by + 82
    for line in lines:
        cv.draw_flow(pr - 40, yy, line, 16, TXT2)
        yy += 30
    by += ch + 14
cv.bottom_bar(X2, SY2 + PH - 96, PW)

# ---------- S6 (X3, صف 2): الاختبار الذاتي (5) ----------
pl, pr = cv.phone(X3, SY2, PW, PH, "الاختبار الذاتي", SUB)
qs = [
    ([[("نواس بدور خاص ", "ar"), ("T₀ = 4 s", "la"), ("، ", "ar"), ("ω₀", "la"), (" يساوي:", "ar")]],
     [[("π/2 rad/s", "la")], [("2π rad/s", "la")], [("π/4 rad/s", "la")], [("4π rad/s", "la")]]),
    ([[("عند ", "ar"), ("t = 0", "la"), (" النقطة عند ", "ar"), ("Xmax/2", "la"),
       (" متحركة بالاتجاه السالب، ", "ar"), ("φ", "la"), (" يساوي:", "ar")]],
     [[("π/3", "la")], [("−π/3", "la")], [("π/2", "la")], [("صفر", "ar")]]),
    ([[("شدة محصلة القوى المؤثرة تكون عظمى عند:", "ar")]],
     [[("المطالين الأعظميين", "ar")], [("مركز الاهتزاز", "ar")], [("أحد المطالين فقط", "ar")], [("كل المواضع", "ar")]]),
    ([[("أول مرور في مركز التوازن ", "ar"), ("t₁", "la"), (" يساوي:", "ar")]],
     [[("1/3 s", "la")], [("1/12 s", "la")], [("13/3 s", "la")], [("1/6 s", "la")]]),
    ([[("عندما ", "ar"), ("k = 1,25 N/m", "la"), ("، الكتلة الجديدة التي تجعل الدور ", "ar"),
       ("1 s", "la"), (" تساوي:", "ar")]],
     [[("1/32 kg", "la")], [("1/40 kg", "la")], [("5/4 kg", "la")], [("0,5 kg", "la")]]),
]
by = SY2 + 88
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
cv.a_rounded(pr - 230, SY2 + PH - 104, pr - 24, SY2 + PH - 56, 24,
             fill=(45, 212, 167, 26), outline=(45, 212, 167, 120))
cv.refresh(pr - 130, SY2 + PH - 80, 14, BRAND, wdt=4)
draw_rtl(img, pr - 24, SY2 + PH - 68, "سؤال جديد", 20, BRAND, bold=True)

# ============================ التسميات ============================
row1 = [
    ([("مسألة ", "ar"), ("(2): ", "la"), ("النص والبيانات", "ar")], X1),
    ([("1)", "la"), (" معادلة الحركة", "ar")], X2),
    ([("2)", "la"), (" أزمنة المرور", "ar")], X3),
]
for segs, x in row1:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY + PH + 56, segs, 23, TXT, bold=True)
row2 = [
    ([("3)", "la"), (" محصلة القوى ", "ar"), ("4)", "la"), (" k", "la")], X1),
    ([("5)", "la"), (" كتلة جديدة ", "ar"), ("+ ", "la"), ("البطاقات", "ar")], X2),
    ([("الاختبار الذاتي ", "ar"), ("(5", "la"), (" قوالب", "ar"), (")", "la")], X3),
]
for segs, x in row2:
    w = cv.flow_width(segs, 23, True)
    cv.draw_flow(x + PW // 2 + w // 2, SY2 + PH + 56, segs, 23, TXT, bold=True)
cv.draw_flow(XR, SY2 + PH + 130, [
    ("المراجعة: الأستاذ فداء البني", "ar"), (" · ", "la"), ("الوحدة 1.14 من 73", "ar"), (" · ", "la"), ("2026-10-03", "la"),
], 20, TXT2)

cv.save("/home/user/Almorshed/ui-mockup/unit-1.14-review.png")
