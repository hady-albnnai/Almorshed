#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
فحص فيزيائي مستقلّ لبنك المسائل (parts-v1).
لكل قالب مغطّى: نستخرج المعطيات من نصّ المسألة ونعيد حساب كل جزء بصيغة
فيزيائية مكتوبة يدوياً (مصدر مستقلّ عن مولّد المسائل tools/gen_items.py)،
ثم نقارن النتيجة بقيمة الجزء المخزّنة في app/assets/content/items.json.
الهدف: كشف أي خطأ في صيغة `compute` داخل القوالب.  الاستعمال:
    python3 tools/verify_problems.py
"""
import json, re, math, sys, os

ITEMS = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "content", "items.json")
g = 10.0; pis = 10.0
e = 1.6e-19; me = 9.1e-31; c = 3e8; h = 6.63e-34
mu0 = 4 * math.pi * 1e-7; G = 6.67e-11


def N(pat, s):
    m = re.search(pat, s)
    if not m:
        raise ValueError(f"no match {pat!r}")
    return float(m.group(1))


def full(it):
    return it["stem"] + " " + " ".join(p["prompt"] for p in it["parts"])


def close(a, b, tol=0.02):
    if b == 0:
        return abs(a) < 1e-12
    return abs(a - b) / abs(b) <= tol


# كل مُدخل: يُعيد قائمة القيم المتوقّعة لأجزاء المسألة بالترتيب.
CHECKS = {
 # ── مجموعة A ──
 'U1.L1.P03': lambda it:(lambda k,m,X:[m*g/k,k*X,0.5*k*X**2])(N(r'k = ([\d.]+) N',it['stem']),N(r'm = ([\d.]+) kg',it['stem']),N(r'Xm = ([\d.]+) m',it['stem'])),
 'U1.L4.P03': lambda it:(lambda V,rL,rO:[V*1e-6,rL*g*V*1e-6,rO*g*V*1e-6])(N(r'V = ([\d.]+) cm',it['stem']),N(r'ρ_س = ([\d.]+)',it['stem']),N(r'كثافته ρ = ([\d.]+) kg',it['stem'])),
 'U2.L3.P03': lambda it:(lambda B,L,v,R:[(ee:=B*L*v),ee/R,B*(ee/R)*L])(N(r'B = ([\d.]+) T',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem']),N(r'v = ([\d.]+) m',it['stem']),N(r'R = ([\d.]+) Ω',it['stem'])),
 'U2.L4.P03': lambda it:(lambda Cu,Um:[(E:=0.5*Cu*1e-6*Um**2),E/4,0.75*E])(N(r'C = ([\d.]+) µF',it['stem']),N(r'Um = ([\d.]+) V',it['stem'])),
 'U4.L3.P03': lambda it:(lambda U:[U,1.24/U,c/((1.24/U)*1e-9)])(N(r'U = ([\d.]+) kV',it['stem'])),
 'U1.L1.P01': lambda it:(lambda k,m,X:[2*math.sqrt(pis)*math.sqrt(m/k),(k/m)*X,0.5*k*X**2])(N(r'k = ([\d.]+) N',it['stem']),N(r'm = ([\d.]+) kg',it['stem']),N(r'Xm = ([\d.]+) m',it['stem'])),
 'U1.L3.P02': lambda it:(lambda L,dt:[(T:=2*math.sqrt(pis*L/g)),1/T,dt/T])(N(r'خيطه L = ([\d.]+) m',it['stem']),N(r'Δt = ([\d.]+) s',full(it))),
 'U1.L4.P01': lambda it:(lambda h,s1,s2:[(v:=math.sqrt(2*g*h)),(Q:=s1*1e-4*v),Q/(s2*1e-4)])(N(r'عمق h = ([\d.]+) m',it['stem']),N(r'مساحتها s1 = ([\d.]+) cm',it['stem']),N(r'مقطعه s2 = ([\d.]+) cm',it['stem'])),
 'U3.L1.P01': lambda it:(lambda F,mu,L,n:[(v:=math.sqrt(F/(mu*1e-3))),n*v/(2*L),2*L/n])(N(r'بقوة توتر F = ([\d.]+) N',it['stem']),N(r'الطولية μ = ([\d.]+) g',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem']),N(r'رقم n = (\d+)',it['stem'])),
 'U3.L2.P01': lambda it:(lambda v,L:[v/(4*L),4*L,3*v/(4*L)])(N(r'بسرعة v = ([\d.]+) m',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem'])),
 'U4.L2.P01': lambda it:(lambda U:[e*U,(v:=math.sqrt(2*e*U/me)),me*v])(N(r'كمون U = ([\d.]+) V',it['stem'])),
 'U4.L3.P01': lambda it:(lambda lam,W0:[1240/lam,1240/lam-W0,1240/lam-W0])(N(r'موجته λ = ([\d.]+) nm',it['stem']),N(r'W0 = ([\d.]+) eV',it['stem'])),
 'U2.L5.P02': lambda it:(lambda R,X,U:[(Z:=math.hypot(R,X)),U/Z,R*(U/Z)**2])(N(r'R = ([\d.]+) Ω',it['stem']),N(r'XC\| = ([\d.]+) Ω',it['stem']),N(r'منتج U = ([\d.]+) V',it['stem'])),
 # ── مجموعة B ──
 'U2.L4.P01': lambda it:(lambda L,C,Um:[(T:=2*math.sqrt(pis*L*C*1e-6)),1/T,C*1e-6*Um])(N(r'ذاتيتها L = ([\d.]+) H',it['stem']),N(r'سعتها C = ([\d.]+) µF',it['stem']),N(r'Um = ([\d.]+) V',it['stem'])),
 'U4.L1.P02': lambda it:(lambda ni,nf:[(dE:=13.6*(1/nf**2-1/ni**2)),1240/dE,c/((1240/dE)*1e-9)])(N(r'ni = (\d+)',it['stem']),N(r'nf = (\d+)',it['stem'])),
 'U1.L4.P02': lambda it:(lambda rho,h,S,P0:[rho*g*h,P0+rho*g*h,(P0+rho*g*h)*S])(N(r'كثافته ρ = ([\d.]+) kg',it['stem']),N(r'عمق h = ([\d.]+) m',it['stem']),N(r'مساحتها S = ([\d.]+) m',it['stem']),N(r'P0 = ([\d.]+) Pa',it['stem'])),
 'U2.L6.P01': lambda it:(lambda Up,Np,Ns,Ip:[Up*Ns/Np,Up*Ip,Ip*Np/Ns])(N(r'Up = ([\d.]+) V',it['stem']),N(r'Np = ([\d.]+)',it['stem']),N(r'Ns = ([\d.]+)',it['stem']),N(r'Ip = ([\d.]+) A',it['stem'])),
 'U4.L2.P02': lambda it:(lambda U,B:[(v:=math.sqrt(2*e*U/me)),me*v/(e*B),2*math.pi*me/(e*B)])(N(r'كمون U = ([\d.]+) V',it['stem']),N(r'منتظماً B = ([\d.]+) T',it['stem'])),
 'U1.L5.P01': lambda it:(lambda b,dt0,L0:[(gm:=1/math.sqrt(1-b**2)),gm*dt0,L0/gm])(N(r'v = ([\d.]+)·c',it['stem']),N(r'Δt0 = ([\d.]+) s',it['stem']),N(r'L0 = ([\d.]+) m',it['stem'])),
 'U3.L2.P02': lambda it:(lambda v,L,n:[v/(2*L),2*L,n*v/(2*L)])(N(r'v = ([\d.]+) m',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem']),N(r'رقم n = (\d+)',full(it))),
 'U1.L2.P01': lambda it:(lambda I,C,th:[(T:=2*math.sqrt(pis*I/C)),1/T,C*th])(N(r'I = ([\d.]+) kg',it['stem']),N(r'ثابته C = ([\d.]+) N',it['stem']),N(r'θ = ([\d.]+) rad',full(it))),
 'U1.L3.P03': lambda it:(lambda T,dt:[g*T**2/(4*pis),1/T,dt/T])(N(r'T0 = ([\d.]+) s',it['stem']),N(r'Δt = ([\d.]+) s',full(it))),
 'U2.L1.P02': lambda it:(lambda I,d:[2e-7*I/d,2e-7*I/(2*d)])(N(r'شدّته I = ([\d.]+) A',it['stem']),N(r'بعد d = ([\d.]+) m',full(it))),
 # ── مجموعة C ──
 'U1.L1.P04': lambda it:(lambda k,X:[(E:=0.5*k*X**2),E/4,0.75*E])(N(r'نابضه k = ([\d.]+) N',it['stem']),N(r'Xm = ([\d.]+) m',it['stem'])),
 'U1.L2.P03': lambda it:(lambda C,I,th:[(w:=math.sqrt(C/I)),w*th,0.5*C*th**2])(N(r'فتله C = ([\d.]+) N',it['stem']),N(r'قرصه I = ([\d.]+) kg',it['stem']),N(r'θmax = ([\d.]+) rad',it['stem'])),
 'U2.L1.P03': lambda it:(lambda n,I,Rcm:[mu0*n*I/(2*(Rcm*1e-2)),(S:=math.pi*(Rcm*1e-2)**2),n*I*S])(N(r'لفّاتها N = (\d+)',it['stem']),N(r'تيار I = ([\d.]+) A',it['stem']),N(r'قطرها R = ([\d.]+) cm',it['stem'])),
 'U2.L2.P03': lambda it:(lambda B,I,L,dd,t:[(F:=B*I*L),F*dd,F*dd/t])(N(r'منتظم B = ([\d.]+) T',it['stem']),N(r'تيار I = ([\d.]+) A',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem']),N(r'مسافة d = ([\d.]+) m',it['stem']),N(r'زمن t = ([\d.]+) s',it['stem'])),
 'U3.L1.P03': lambda it:(lambda mug,L,f1:[(v:=2*L*f1),mug*1e-3*v**2,3*f1])(N(r'الطولية μ = ([\d.]+) g',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem']),N(r'f1 = ([\d.]+) Hz',it['stem'])),
 'U4.L1.P03': lambda it:(lambda n:[(Ei:=13.6/n**2),1240/Ei,c/((1240/Ei)*1e-9)])(N(r'المستوى n = (\d+)',it['stem'])),
 'U4.L2.P03': lambda it:(lambda U:[e*U,(p:=math.sqrt(2*me*e*U)),h/p])(N(r'كمون U = ([\d.]+) V',it['stem'])),
 'U1.L5.P03': lambda it:(lambda b,E0:[(gm:=1/math.sqrt(1-b**2)),E0*gm,b*E0*gm])(N(r'v = ([\d.]+)·c',it['stem']),N(r'E0 = ([\d.]+) MeV',it['stem'])),
 # ── مجموعة D ──
 'U3.L2.P03': lambda it:(lambda v,f1:[v/(4*f1),v/f1,3*f1])(N(r'الهواء v = ([\d.]+) m',it['stem']),N(r'f1 = ([\d.]+) Hz',it['stem'])),
 'U2.L6.P03': lambda it:(lambda Up,Np,Ns,R:[(Us:=Up*Ns/Np),Us/R,Us*(Us/R)])(N(r'Up = ([\d.]+) V',it['stem']),N(r'Np = ([\d.]+)',it['stem']),N(r'Ns = ([\d.]+)',it['stem']),N(r'R = ([\d.]+) Ω',it['stem'])),
 'U1.L4.P04': lambda it:(lambda s1,s2,v1:[(v2:=(s1/s2)*v1),(s2*1e-4)*v2,0.5*1000*(v2**2-v1**2)])(N(r's1 = ([\d.]+) cm',it['stem']),N(r's2 = ([\d.]+) cm',it['stem']),N(r'v1 = ([\d.]+) m',it['stem'])),
 'U2.L3.P04': lambda it:(lambda L,dI,dt,I:[L*dI/dt,L*I,0.5*L*I**2])(N(r'ذاتيتها L = ([\d.]+) H',it['stem']),N(r'ΔI = ([\d.]+) A',it['stem']),N(r'Δt = ([\d.]+) s',it['stem']),N(r'شدّة I = ([\d.]+) A',it['stem'])),
 'U2.L5.P03': lambda it:(lambda R,XL,XC,U:[(Z:=math.sqrt(R**2+(XL-XC)**2)),U/Z,R*(U/Z)**2])(N(r'R = ([\d.]+) Ω',it['stem']),N(r'حثّية XL = ([\d.]+) Ω',it['stem']),N(r'سعوية XC = ([\d.]+) Ω',it['stem']),N(r'منتج U = ([\d.]+) V',it['stem'])),
 # ── مجموعة E ──
 'U1.L1.P05': lambda it:(lambda m,T,X:[(k:=4*pis*m/T**2),(4*pis/T**2)*X,0.5*k*X**2])(N(r'كتلته m = ([\d.]+) kg',it['stem']),N(r'T0 = ([\d.]+) s',it['stem']),N(r'Xm = ([\d.]+) m',it['stem'])),
 'U2.L1.P04': lambda it:(lambda Nk,Scm,ell,I:[(L:=mu0*Nk**2*(Scm*1e-4)/ell),L*I,0.5*L*I**2])(N(r'لفّاتها N = (\d+)',it['stem']),N(r'مقطعها S = ([\d.]+) cm',it['stem']),N(r'طولها ℓ = ([\d.]+) m',it['stem']),N(r'تيار I = ([\d.]+) A',it['stem'])),
 'U4.L1.P04': lambda it:(lambda n:[0.0529*n**2,2.18e6/n,-13.6/n**2])(N(r'المستوى n = (\d+)',it['stem'])),
 'U4.L3.P04': lambda it:(lambda lam,Pmw:[(E:=h*c/(lam*1e-9)),(Nr:=(Pmw*1e-3)/(h*c/(lam*1e-9))),Nr*e])(N(r'موجته λ = ([\d.]+) nm',it['stem']),N(r'P = ([\d.]+) mW',it['stem'])),
 'U5.L1.P03': lambda it:(lambda m1,m2,dd:[(F:=G*m1*m2/dd**2),F/m2,F/m1])(N(r'm1 = ([\d.]+) kg',it['stem']),N(r'm2 = ([\d.]+) kg',it['stem']),N(r'd = ([\d.]+) m',it['stem'])),
 'U3.L1.P04': lambda it:(lambda mg,L,F:[(mu:=mg*1e-3/L),(v:=math.sqrt(F/mu)),v/(2*L)])(N(r'كتلته m = ([\d.]+) g',it['stem']),N(r'طوله L = ([\d.]+) m',it['stem']),N(r'F = ([\d.]+) N',it['stem'])),
 # ── مجموعة F ──
 'U1.L2.P04': lambda it:(lambda C,th:[(E:=0.5*C*th**2),E/4,0.75*E])(N(r'فتله C = ([\d.]+) N',it['stem']),N(r'θmax = ([\d.]+) rad',it['stem'])),
 'U1.L3.P04': lambda it:(lambda L,T,m:[(gp:=4*pis*L/T**2),1/T,m*gp])(N(r'خيطه L = ([\d.]+) m',it['stem']),N(r'T0 = ([\d.]+) s',it['stem']),N(r'الكرية m = ([\d.]+) kg',it['stem'])),
 'U2.L2.P04': lambda it:(lambda v,B:[1.6e-19*v*B,1.67e-27*v/(1.6e-19*B),2*math.pi*1.67e-27/(1.6e-19*B)])(N(r'بسرعة v = ([\d.]+) m',it['stem']),N(r'منتظماً B = ([\d.]+) T',it['stem'])),
 'U2.L4.P04': lambda it:(lambda f0,L,Um:[(C:=1/(4*pis*f0**2*L)),C*Um,1/f0])(N(r'f0 = ([\d.]+) Hz',it['stem']),N(r'وشيعتها L = ([\d.]+) H',it['stem']),N(r'Um = ([\d.]+) V',it['stem'])),
 'U2.L6.P04': lambda it:(lambda P,U,R:[(I:=P/U),R*I**2,R*I])(N(r'استطاعة كهربائية P = ([\d.]+) W',it['stem']),N(r'توتره U = ([\d.]+) V',it['stem']),N(r'الكلية R = ([\d.]+) Ω',it['stem'])),
 'U3.L2.P04': lambda it:(lambda v,f1,n:[v/(2*f1),v/f1,n*f1])(N(r'الهواء v = ([\d.]+) m',it['stem']),N(r'f1 = ([\d.]+) Hz',it['stem']),N(r'رقم n = (\d+)',full(it))),
 'U4.L2.P04': lambda it:(lambda U,dd:[U/dd,1.6e-19*U/dd,1.6e-19*U/(9.1e-31*dd)])(N(r'توتر U = ([\d.]+) V',it['stem']),N(r'بينهما d = ([\d.]+) m',it['stem'])),
 # ── مجموعة G (توسيع الفصول المحدودة) ──
 'U1.L5.P04': lambda it:(lambda E0,b:[(gm:=1/math.sqrt(1-b**2)),b*E0*gm,E0*gm])(N(r'E0 = ([\d.]+) MeV',it['stem']),N(r'v = ([\d.]+)·c',it['stem'])),
 'U2.L5.P04': lambda it:(lambda L,C,R,U:[1/(2*math.pi*math.sqrt(L*C*1e-6)),U/R,R*(U/R)**2])(N(r'ذاتيتها L = ([\d.]+) H',it['stem']),N(r'سعتها C = ([\d.]+) µF',it['stem']),N(r'مقاومتها R = ([\d.]+) Ω',it['stem']),N(r'المنتج U = ([\d.]+) V',it['stem'])),
 'U5.L1.P04': lambda it:(lambda m,R,g0,h:[R*math.sqrt(g0/(R+h)),0.5*m*R**2*g0/(R+h),-m*R**2*g0/(R+h)])(N(r'كتلته m = ([\d.]+) kg',it['stem']),N(r'قطره R = ([\d.]+) m',it['stem']),N(r'g0 = ([\d.]+) m',it['stem']),N(r'h = ([\d.]+) m',it['stem'])),
}


def main():
    data = json.load(open(ITEMS, encoding="utf-8"))
    items = data["items"]
    tot = okc = 0
    fails = []
    covered = 0
    for tid, fn in CHECKS.items():
        its = [i for i in items if i.get("templateId") == tid]
        if its:
            covered += 1
        for it in its:
            try:
                exp = fn(it)
            except Exception as ex:  # noqa
                fails.append((tid, it["id"], "EXTRACT", str(ex)))
                continue
            got = [p["answer"]["value"] for p in it["parts"]]
            for j, ev in enumerate(exp):
                tot += 1
                if j < len(got) and close(got[j], ev):
                    okc += 1
                else:
                    fails.append((tid, it["id"], j + 1, ev, got[j] if j < len(got) else None))
    print(f"templates covered: {covered}/{len(CHECKS)}")
    print(f"part-checks: {tot} | matched: {okc} | issues: {len(fails)}")
    for f in fails[:40]:
        print("  MISMATCH", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
