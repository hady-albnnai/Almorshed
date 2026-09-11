#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
فحص عميق لملفات الأستاذ فداء (docx) — استخراج بنى OMML (m:sSub) مع الترميز الدقيق.
الهدف: حسم البنود المعلّقة:
  1) Γ_η أم Γ_n  2) ∆ (U+2206) مقابل Δ (U+0394) في I_Δ  3) P_evg مقابل P_avg
  4) توثيق صيغ التوابع الأخرى (T_0/T_o, Xmax/XmaX, E_s/E_S)
"""
import zipfile, re, sys, json, unicodedata
from collections import Counter, defaultdict
from xml.etree import ElementTree as ET

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'

def qn(ns, tag): return f'{{{ns}}}{tag}'

def parse_docx(path):
    """يرجع: runs_riyadiyat (كل m:t بالترتيب مع نوع العقدة الأب), subs (بنى sSub), نص عادي"""
    with zipfile.ZipFile(path) as z:
        xml = z.read('word/document.xml')
    root = ET.fromstring(xml)
    subs = []          # (base, sub, base_cp, sub_cp)
    math_runs = []     # كل محارف m:t
    plain_runs = []    # كل محارف w:t
    # نمشي على الشجرة كاملة
    for ssub in root.iter(qn(M, 'sSub')):
        e = ssub.find(qn(M, 'e'))
        sub = ssub.find(qn(M, 'sub'))
        def text_of(el):
            if el is None: return ''
            return ''.join(t.text or '' for t in el.iter(qn(M, 't')))
        base, sb = text_of(e), text_of(sub)
        if base or sb:
            subs.append((base, sb))
    for t in root.iter(qn(M, 't')):
        math_runs.append(t.text or '')
    for t in root.iter(qn(W, 't')):
        plain_runs.append(t.text or '')
    return subs, ''.join(math_runs), ''.join(plain_runs)

def cps(s):
    return ' '.join(f'U+{ord(c):04X}' for c in s)

def main():
    files = sys.argv[1:]
    grand = {}
    report = {}
    for path in files:
        name = path.split('/')[-1]
        subs, math_text, plain_text = parse_docx(path)
        r = {}
        # 1) عزوم: قواعد sSub التي تبدأ بـ Γ
        gamma_subs = Counter()
        for base, sb in subs:
            b = base.replace(' ', '')
            if b == 'Γ' or (len(b) >= 1 and b[0] == 'Γ'):
                gamma_subs[(b, sb)] += 1
        r['gamma_sSub'] = {f'{b}[{cps(s)}]': c for (b, s), c in gamma_subs.most_common()}
        # 2) I_Δ — كل صيغ الدلتا في القواعد والتوابع
        delta_forms = Counter()
        i_subs = Counter()
        for base, sb in subs:
            for c in base + sb:
                if c in 'Δ∆△':
                    delta_forms[f'{c} {cps(c)}'] += 1
            b = base.replace(' ', '')
            if b and b[-1] in 'IıΙ' and b != 'I':
                pass
            if b == 'I':
                i_subs[f'sub=[{sb}] {cps(sb)}'] += 1
        r['delta_forms_in_math'] = dict(delta_forms)
        r['I_base_subs'] = dict(i_subs)
        # في النص الرياضي المسطّح كله
        r['flat_math_delta'] = {f'{c} {cps(c)}': math_text.count(c) for c in 'Δ∆△' if math_text.count(c)}
        r['flat_math_U2206'] = math_text.count('∆')
        r['flat_math_U0394'] = math_text.count('Δ')
        # 3) IΔ المسطّح (بدون بنية sSub) — نمط I متبوعاً بدلتا
        r['flat_I_delta_U2206'] = len(re.findall(r'I\s*∆', math_text))
        r['flat_I_delta_U0394'] = len(re.findall(r'I\s*Δ', math_text))
        # 4) P_avg / P_evg
        r['P_evg_math'] = len(re.findall(r'P\s*_?\s*e\s*v\s*g', math_text))
        r['P_avg_math'] = len(re.findall(r'P\s*_?\s*a\s*v\s*g', math_text))
        r['P_evg_plain'] = len(re.findall(r'P\s*_?\s*e\s*v\s*g', plain_text))
        r['P_avg_plain'] = len(re.findall(r'P\s*_?\s*a\s*v\s*g', plain_text))
        # كل توابع P
        p_subs = Counter()
        for base, sb in subs:
            if base.strip() == 'P':
                p_subs[f'sub=[{sb}] {cps(sb)}'] += 1
        r['P_base_subs'] = dict(p_subs)
        # 5) تابع كل القواعد أحادية الحرف اللاتينية المهمة (T, X, E, f, ...)
        interesting = {}
        for base, sb in subs:
            b = base.strip()
            if b in ('T', 'X', 'E', 'f', 'U', 'Q', 'I', 'Γ'):
                interesting.setdefault(b, Counter())[f'[{sb}] {cps(sb)}'] += 1
        r['interesting_subs'] = {k: dict(v.most_common(8)) for k, v in sorted(interesting.items())}
        # 6) نص عادي: ذكر "η" أو "ايتا"
        r['eta_in_plain'] = plain_text.count('η') + math_text.count('η')
        report[name] = r
    print(json.dumps(report, ensure_ascii=False, indent=1))

if __name__ == '__main__':
    main()
