import re
import sys

def is_arab(ch):
    return 0x0600 <= ord(ch) <= 0x06FF

# ماسح مقاطع ar/la: يكشف كل رمز لا يستطيع الخط رسمه
#   ar (SANS نوتو سانس عربي) + رمز غير عربي/لاتيني/رقم (تغطية SANS محدودة بالرموز المسموحة أدناه)
#   la (DejaVu) + عربي (DejaVu لا يحوي عربيًا)
s = open(sys.argv[1] if len(sys.argv) > 1 else 'render_unit_1_12_review.py', encoding='utf-8').read()
pat = re.compile(r'\("([^"\\]+)",\s*"(ar|la)"\)')

# تغطية SANS المؤكدة بفحص charmap: العربية + لاتيني + 0-9 + ':' '.' '·' '(' ')' '−' '=' '/'
OK_AR = set(':.·()−=/')

seen_ar, seen_la = set(), set()
print("== AR segments with non-Arabic/non-digit chars (font can't render):")
for m in pat.finditer(s):
    txt, kind = m.group(1), m.group(2)
    if kind == 'ar':
        bad = sorted({c for c in txt
                      if c != ' ' and not is_arab(c)
                      and not (0x30 <= ord(c) <= 0x39)
                      and c not in OK_AR
                      and not (0x41 <= ord(c) <= 0x5A)
                      and not (0x61 <= ord(c) <= 0x7A)})
        if bad:
            k = txt[:80]
            if k not in seen_ar:
                seen_ar.add(k)
                print("  %r  chars=%r" % (txt[:120], ''.join(bad)))

print("== LA segments with Arabic (DejaVu can't render):")
for m in pat.finditer(s):
    txt, kind = m.group(1), m.group(2)
    if kind == 'la':
        bad = sorted({c for c in txt if is_arab(c)})
        if bad:
            k = txt[:80]
            if k not in seen_la:
                seen_la.add(k)
                print("  %r  chars=%r" % (txt[:120], ''.join(bad)))
