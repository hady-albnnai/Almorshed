#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Builds the teacher review forms (HTML + DOCX + JSON) from terms_data.py,
adding an EVIDENCE column computed from the official textbook text.

Nothing is pre-approved: the decision column ships empty.
The HTML saves progress in the browser (localStorage) and can export a
WhatsApp-ready plain-text summary.
"""
import json
import re
import unicodedata
from collections import OrderedDict
from pathlib import Path

from terms_data import CHAPTERS, TERMS

ROOT = Path(__file__).resolve().parent
BOOK = ROOT.parent / "sources" / "book.norm.txt"

# ----------------------------------------------------------------- evidence
def norm(s: str) -> str:
    s = unicodedata.normalize("NFKC", s)
    s = re.sub(r"[\u064B-\u0652\u0670\u0640]", "", s)          # diacritics, tatweel
    s = s.replace("\u200c", "").replace("\u200e", "").replace("\u200f", "")
    s = re.sub(r"[^\u0621-\u063A\u0641-\u064A0-9A-Za-z ]", " ", s)
    s = (s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
           .replace("ى", "ي").replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي"))
    s = re.sub(r"\s+", " ", s).strip()
    return s


def load_pages():
    if not BOOK.exists():
        return {}
    raw = BOOK.read_text(encoding="utf-8")
    parts = re.split(r"<<<PAGE (\d+)>>>", raw)
    return {int(parts[i]): norm(parts[i + 1]) for i in range(1, len(parts) - 1, 2)}


PAGES = load_pages()
PAGES_NOAL = {k: v.replace("ال", "") for k, v in PAGES.items()}


def _cores(n: str):
    out = []
    for base in (n, n.replace("ال", "")):
        out.append(base)
        out.append(" ".join(re.sub(r"[يىهاو]+$", "", w) for w in base.split()))
    return [c.strip() for c in out if len(c.strip()) >= 3]


def evidence(ar: str):
    """Return (found, [printed page numbers]) for the normalised term."""
    clean = re.sub(r"\(.*?\)", " ", ar)          # drop parenthetical notes
    clean = clean.split("\u2014")[0]             # drop trailing explanations
    n = norm(clean)
    n = re.sub(r"^(ال|و)", "", n).strip()
    n = re.sub(r"\s+", " ", n).strip()
    if len(n) < 2:
        return False, []
    variants = _cores(n)
    hits = set()
    for pdf_page in PAGES:
        a, b = PAGES[pdf_page], PAGES_NOAL[pdf_page]
        if any(v in a or v in b for v in variants):
            hits.add(pdf_page - 1)
    hits = sorted(hits)
    return (len(hits) > 0), hits[:6]


# ----------------------------------------------------------------- rows
rows = OrderedDict()
for key, _title in CHAPTERS:
    rows[key] = []

for ar, en, sym, unit, ch, tier in TERMS:
    found, pages = evidence(ar)
    rows.setdefault(ch, []).append({
        "ar": ar, "en": en, "sym": sym, "unit": unit, "tier": tier,
        "found": found, "pages": pages,
        "src": {"k": "الكلمات المفتاحية", "g": "جدول المصطلحات الرسمي",
                "s": "معادلات الكتاب", "v": "نص الكتاب"}[tier],
    })

total = sum(len(v) for v in rows.values())

# ----------------------------------------------------------------- CSS
CSS = """
:root{--bg:#f6f7f9;--card:#fff;--line:#dfe3e8;--ink:#1b1f24;--mut:#6b7280;
--ok:#0f7b3f;--no:#c0392b;--hdr:#1f3a5f;--unit:#0d47a1;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font-family:"Segoe UI","Noto Naskh Arabic","Tahoma",system-ui,sans-serif;direction:rtl;line-height:1.7}
header{background:var(--hdr);color:#fff;padding:20px 24px}
header h1{margin:0 0 6px;font-size:21px}
header p{margin:0;opacity:.85;font-size:13px}
.bar{position:sticky;top:0;z-index:9;background:#fff;border-bottom:1px solid var(--line);
padding:9px 14px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.bar input[type=search]{flex:1;min-width:150px;padding:8px 11px;border:1px solid var(--line);
border-radius:8px;font-size:15px;font-family:inherit}
select{padding:8px 10px;border:1px solid var(--line);border-radius:8px;font-size:14px;
font-family:inherit;background:#fff}
.btn{border:1px solid var(--line);background:#fff;border-radius:8px;padding:8px 12px;
cursor:pointer;font-size:14px;font-family:inherit}
.btn:hover{background:#eef2f7}
.btn.pri{background:var(--unit);color:#fff;border-color:var(--unit)}
.btn.warn{color:#b45309;border-color:#fcd34d;background:#fffbeb}
.stat{font-size:13px;color:var(--mut)}
#saved{font-size:12px;color:var(--ok);min-width:52px}
.pw{flex:1 1 100%;height:8px;background:#e5e7eb;border-radius:5px;overflow:hidden;margin-top:2px}
.pw i{display:block;height:100%;width:0;background:var(--ok);transition:width .25s}
main{padding:14px;max-width:1500px;margin:0 auto}
section{background:var(--card);border:1px solid var(--line);border-radius:12px;margin:0 0 16px;overflow:hidden}
h2{font-size:16px;margin:0;padding:11px 15px;background:#eef2f7;border-bottom:1px solid var(--line);
display:flex;justify-content:space-between;align-items:center;gap:10px}
h2 .t{font-weight:600}
h2 .p{font-weight:400;color:var(--mut);font-size:12px;background:#fff;border:1px solid var(--line);
border-radius:20px;padding:2px 10px;white-space:nowrap}
h2 .p.done{background:#ecfdf5;color:var(--ok);border-color:#a7f3d0}
table{width:100%;border-collapse:collapse;font-size:14px}
th{background:#f8fafc;text-align:right;padding:8px 9px;border-bottom:1px solid var(--line);
font-size:12.5px;color:#374151}
td{padding:6px 9px;border-bottom:1px solid #f1f3f5;vertical-align:middle}
tr:hover td{background:#fafbfc}
.term{font-weight:600}
.en{direction:ltr;text-align:right;color:#334155;font-size:12.5px}
.sym{direction:ltr;text-align:center;font-weight:600;color:var(--unit)}
.unit{font-size:12.5px;color:#475569;text-align:center}
.ev{font-size:12px;color:var(--mut);text-align:center;white-space:nowrap}
.ev .y{color:var(--ok);font-weight:700}
.ev .n{color:#9ca3af}
.dec{text-align:center;white-space:nowrap}
.dec button{border:1px solid var(--line);background:#fff;border-radius:7px;width:34px;height:30px;
cursor:pointer;font-size:15px;margin:0 1px;line-height:1}
.dec button.on[data-v="ok"]{background:var(--ok);color:#fff;border-color:var(--ok)}
.dec button.on[data-v="no"]{background:var(--no);color:#fff;border-color:var(--no)}
.dec button.on[data-v="na"]{background:#6b7280;color:#fff;border-color:#6b7280}
input.corr{width:100%;min-width:130px;padding:6px 9px;border:1px solid var(--line);border-radius:7px;
font-family:inherit;font-size:14px;background:#fff;color:var(--ink)}
.note{background:#fffbeb;border:1px solid #fde68a;border-radius:10px;padding:12px 15px;
margin:0 0 16px;font-size:14px}
.note b{color:#92400e}
.q{border:1px solid var(--line);border-radius:10px;background:#fff;padding:10px 14px;margin:8px 0}
.q b{display:block;margin-bottom:4px}
.q .evd{font-size:12px;color:var(--mut);margin:4px 0}
.q textarea{width:100%;min-height:54px;border:1px solid var(--line);border-radius:8px;padding:8px;
font-family:inherit;font-size:14px}
@media print{.bar{display:none}section{break-inside:avoid}}
"""

# ----------------------------------------------------------------- JS
JS = r"""
const KEY='murshid-glossary-v1';
let DB={rows:{},q:{}};
try{const o=JSON.parse(localStorage.getItem(KEY)||'{}');DB.rows=o.rows||{};DB.q=o.q||{};}catch(e){}
let tSave=null;
function save(){localStorage.setItem(KEY,JSON.stringify(DB));
 const el=document.getElementById('saved');el.textContent='✓ حُفظ';
 clearTimeout(tSave);tSave=setTimeout(()=>{el.textContent='';},1400);}
function st(id){return DB.rows[id]||(DB.rows[id]={d:null,t:''});}
function paint(r){const s=DB.rows[r.dataset.row]||{d:null,t:''};
 r.querySelectorAll('.dec button').forEach(b=>b.classList.toggle('on',b.dataset.v===s.d));
 const c=r.querySelector('input.corr');if(c.value!==(s.t||''))c.value=s.t||'';}

document.addEventListener('click',e=>{const b=e.target.closest('.dec button');if(!b)return;
 const r=b.closest('tr'),id=r.dataset.row,v=b.dataset.v,s=st(id);
 s.d=(s.d===v)?null:v;paint(r);save();count();});

document.addEventListener('input',e=>{
 if(e.target.matches('input.corr')){st(e.target.closest('tr').dataset.row).t=e.target.value;save();}
 if(e.target.matches('textarea[data-q]')){DB.q[e.target.dataset.q]=e.target.value;save();}});

function count(){let ok=0,no=0,na=0,tot=0;
 document.querySelectorAll('section[data-key]').forEach(s=>{
  let a=0,b=0,c=0,n=0;
  s.querySelectorAll('tr[data-row]').forEach(r=>{n++;const d=(DB.rows[r.dataset.row]||{}).d;
   if(d==='ok')a++;else if(d==='no')b++;else if(d==='na')c++;});
  ok+=a;no+=b;na+=c;tot+=n;
  const p=s.querySelector('h2 .p');p.textContent=a+'/'+n+' مُقيَّم'+(b?' · '+b+' خطأ':'');
  p.classList.toggle('done',a+b+c===n&&n>0);});
 const done=ok+no+na;
 document.getElementById('stat').textContent=
  '✅ '+ok+'   ❌ '+no+'   ➖ '+na+'   ·   أُنجز '+done+' من '+tot;
 document.getElementById('pw').style.width=(tot?(done/tot*100):0)+'%';}

function applyFilter(){
 const v=document.getElementById('flt').value;
 const q=norm(document.getElementById('q').value);
 document.querySelectorAll('section[data-key]').forEach(s=>{
  let vis=0;
  s.querySelectorAll('tr[data-row]').forEach(r=>{
   const d=(DB.rows[r.dataset.row]||{}).d;
   let show=true;
   if(q&&!norm(r.textContent).includes(q))show=false;
   if(show&&v==='undone'&&d)show=false;
   if(show&&v==='no'&&d!=='no')show=false;
   if(show&&v==='na'&&d!=='na')show=false;
   if(show&&v==='nf'&&r.dataset.nf!=='1')show=false;
   r.style.display=show?'':'none';if(show)vis++;});
  s.style.display=vis?'':'none';});}

document.getElementById('q').addEventListener('input',applyFilter);
document.getElementById('flt').addEventListener('change',applyFilter);

function summary(){
 const L=[];let n=0;
 document.querySelectorAll('section[data-key]').forEach(s=>{
  const bad=[];
  s.querySelectorAll('tr[data-row]').forEach(r=>{const o=DB.rows[r.dataset.row]||{};
   const t=r.querySelector('.term').textContent.trim();
   if(o.d==='no'){bad.push('❌ '+t+(o.t?'  →  '+o.t:'  (بدون تصحيح)'));n++;}
   else if(o.d==='na'){bad.push('➖ '+t+(o.t?'  —  '+o.t:''));n++;}});
  if(bad.length){L.push('### '+s.querySelector('h2 .t').textContent.trim());L.push(...bad);L.push('');}});
 const qs=[];
 document.querySelectorAll('textarea[data-q]').forEach(t=>{const v=t.value.trim();
  if(v)qs.push('س'+t.dataset.q+': '+v);});
 if(qs.length){L.push('=== إجابات أسئلة التحكيم ===');L.push(...qs);}
 const head='تصحيحات مصطلحات فيزياء ثالث ثانوي — '+n+' بند\n';
 return {text:head+'\n'+L.join('\n'),n};}

function dl(name,text,type){const b=new Blob(['\ufeff'+text],{type});
 const u=URL.createObjectURL(b),a=document.createElement('a');
 a.href=u;a.download=name;a.click();URL.revokeObjectURL(u);}

document.getElementById('copy').onclick=()=>{const s=summary();
 const t=s.text;
 if(navigator.clipboard&&navigator.clipboard.writeText){
  navigator.clipboard.writeText(t).then(()=>alert('نُسخ الملخص ('+s.n+' بند) — الصقه في واتساب'),
   ()=>{dl('ملخص-التصحيحات.txt',t,'text/plain');});}
 else{dl('ملخص-التصحيحات.txt',t,'text/plain');}};

document.getElementById('exp').onclick=()=>{
 const out=[];document.querySelectorAll('tr[data-row]').forEach(r=>{const o=DB.rows[r.dataset.row]||{};
  out.push({id:r.dataset.row,term:r.querySelector('.term').textContent.trim(),
   en:r.querySelector('.en').textContent.trim(),decision:o.d||null,note:o.t||''});});
 const qa={};document.querySelectorAll('textarea[data-q]').forEach(t=>qa[t.dataset.q]=t.value);
 dl('review-results.json',JSON.stringify({rows:out,questions:qa},null,1),'application/json');};

document.getElementById('prn').onclick=()=>window.print();
document.getElementById('clr').onclick=()=>{if(!confirm('مسح كل ما قيَّمته في هذا الجهاز؟'))return;
 localStorage.removeItem(KEY);location.reload();};

function norm(s){return (s||'').replace(/[\u064B-\u0652\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا')
 .replace(/ى/g,'ي').replace(/ة/g,'ه').replace(/ؤ/g,'و').replace(/ئ/g,'ي').toLowerCase()}

document.querySelectorAll('tr[data-row]').forEach(paint);
document.querySelectorAll('textarea[data-q]').forEach(t=>{t.value=DB.q[t.dataset.q]||'';});
count();applyFilter();
"""

QUESTIONS = [
    ("ما الرمز المعتمد لثابت فتل السلك: C أم K أم غيرهما؟",
     "دليل من النص: ص21 «سلك فتل فولاذي ثابت فتله k» — أي أن الكتاب استعمل k. الرجاء التثبيت."),
    ("ما الفرق بين «المطال» و«السعة» في الكتاب؟",
     "الكتاب يستعمل الاثنين في الكلمات المفتاحية للفصل الأول (ص6)، وص11: «قوة إرجاع… تتناسب طرداً مع المطال x». "
     "الرجاء تحرير الفرق أو توحيده."),
    ("ما الرمز المعتمد لعزم العطالة؟",
     "دليل من النص: ص22 «TI عزم عطالة الساق حول محور الدوران (السلك)» — الرمز I. الرجاء التأكيد."),
    ("ما الرمز المعتمد للتدفق المغناطيسي؟",
     "يظهر الرمز Φ في نص ص83. الرجاء التأكيد."),
    ("الفاصلة العشرية المعتمدة في الكتاب: , أم . ؟",
     "تظهر الأعداد في المسائل بصيغة 2.5 و 0.40 و 20.0 — الرجاء تأكيد ما يجب اعتماده في التطبيق."),
    ("ما قيمة تسارع الجاذبية الأرضية g المعتمدة في المسائل؟",
     "يذكر الكتاب «تسارع الجاذبية الأرضية g» (ص35)؛ وفي المسائل تظهر قيم مقرّبة. الرجاء التثبيت على 9.8 أم 10."),
    ("هل «الدور» تعني الزمن الدوري أم الطور؟",
     "جدول المصطلحات ص284 يترجم «الدور» بـ Phase، بينما «الطور» واردة في النص بمعنى Phase أيضاً "
     "— يبدو خطأً مطبعياً في الجدول الرسمي. الرجاء التحكيم."),
    ("ترجمة «النسبية الخاصة» ظهرت في الجدول الرسمي Conjugate Pairs",
     "يبدو أن سطراً من كتاب الكيمياء تسرّب إلى الجدول (ص285). الرجاء إقرار التصحيح: Special Relativity."),
    ("«المحلوات الكهربائية» في الجدول الرسمي (ص286)",
     "الصحيح على الأغلب «المحوّلات الكهربائية» Electric Transformer. الرجاء التأكيد."),
    ("تهجئة اسم العالم في قانون فاراداي",
     "النص ص109 يكتب «قانون فارداي» بالألف، بينما الشائع «فاراداي». الرجاء التثبيت على واحدة."),
    ("تهجئة «تمثيل فرينل»",
     "النص ص13 يكتب «تمثيل فرينل». الرجاء التأكيد."),
    ("هل يستخدم الكتاب «شبه موصل / نصف ناقل / ترانزستور»؟",
     "لا يظهر أي منها في نص الكتاب المستخرج (288 صفحة). الرجاء تأكيد عدم إدخالها في التطبيق."),
    ("هل «القوة الكهربائية» في الكتاب تعني Electric Power أم Electric Force؟",
     "الجدول الرسمي ص287 يعطي Electric Power. الرجاء التأكيد."),
    ("ما المقابل المعتمد لـ Transformer في الفصل 6 من الوحدة الثانية؟",
     "النص يستعمل «المحوّلة»، والجدول الرسمي «المحلوات». الرجاء التثبيت على واحد."),
    ("هل يجوز استخدام «التردد» بدل «التواتر» و«الجهد» بدل «التوتر»؟",
     "الرجاء تأكيد حظر المصطلحات المصرية نهائياً في التطبيق."),
    ("هل «القصور الذاتي» مقبول أم «العطالة» فقط؟",
     "النص ص37 يذكر الاثنين: «بفعل ما يسمى القصور الذاتي (أو العطالة)». الرجاء التثبيت."),
]

# answers received from the reviewing teacher (round 1)
ANSWERS = [
    "K",                                   # س1 ثابت فتل السلك
    "الصحيح ما ورد في الصفحة 11",           # س2 المطال / السعة
    "I والدليل دلتا",                       # س3 عزم العطالة
    "صح",                                  # س4 التدفق المغناطيسي Φ
    "20.0",                                # س5 الفاصلة العشرية
    "10",                                  # س6 قيمة g
    "الزمن الدوري",                        # س7 الدور
    "الغيه لأنه تسرب",                      # س8 Conjugate Pairs
    "المحولات الكهربائية",                  # س9 Transformer في الجدول
    "فاراداي",                             # س10 تهجئة فاراداي
    "صح",                                  # س11 تمثيل فرينل
    "غير موجود في المنهاج",                 # س12 شبه موصل… الخ
    "electric force",                      # س13 القوة الكهربائية
    "المحولة",                             # س14 Transformer
    "يجوز",                                # س15 التردد / الجهد
    "العطالة فقط",                          # س16 القصور الذاتي
]

# the teacher's own wording, verbatim (audit trail)
RAWCORR = [
    ("المطال", "x"),
    ("السعة", "Xmax والماكس دليل"),
    ("الطاقة الحركية", "EK"),
    ("الطاقة الميكانيكية", "E"),
    ("مركز الاهتزاز", "0"),
    ("الطور", "ω0t+φ والزيرو دليل"),
    ("الطور الابتدائي", "φ"),
    ("قوة توتر النابض", "F ودليلها S"),
    ("ثابت فتل السلك", "K"),
    ("مزدوجة الفتل", "جما ايتا"),
    ("المطال الزاوي", "θ"),
    ("السعة الزاوية", "θ ودليلها max"),
    ("عزم القوة", "جما — الوحدة متر نيوتن"),
    ("مركز العطالة", "c"),
    ("النواس البسيط المواقت", "المصطلح العربي هو: طول النواس البسيط المواقت، الرمز l"),
    ("معدل التدفق", "قسمان: الكتلي Q واحدته كيلوغرام/ثانية، والحجمي Q_v واحدته متر مكعب/ثانية"),
    ("نظرية تور يشيلي", "نظرية تورشيللي"),
    ("الكثافة", "خطأ، يجب أن تكون: الكتلة الحجمية"),
    ("شعاع السطح", "اسمها: السطح، أو شدة شعاع السطح"),
    ("التدفق المغناطيسي", "الواحدة Wb"),
    ("المزدوجة الكهرطيسية", "الرمز جما دلتا، والواحدة متر نيوتن وليس نيوتن متر"),
    ("قوة محركة كهربائية متحرّضة", "الرمز إپسلون ε"),
    ("طاقة كهرطيسية", "الرمز E والدليل L"),
    ("دور التفريغ", "الرمز T والدليل صفر"),
    ("التوتر الأعظمي", "الرمز U والدليل max"),
    ("التوتر المنتج", "الرمز U والدليل eff"),
    ("الشدة العظمى", "الدليل max"),
    ("الشدة المنتجة", "أضف الدليل eff"),
    ("الاستطاعة المتوسطة", "الاستطاعة المتوسطة المستهلكة، الرمز P والدليل avg"),
    ("شدة التيار المنتجة", "نفسها شدة التيار — مُكرّر"),
    ("نسبة التحويل", "الرمز ميو μ"),
    ("قوة الشد", "الرمز F والدليل T"),
    ("القوة الكهربائية", "المصطلح العربي هو: الاستطاعة الكهربائية"),
    ("كتلة الإلكترون", "الرمز m والدليل e"),
    ("عتبة الكمون / التواتر العتبة", "الرمز f والدليل s"),
    ("عمل الانتزاع", "الرمز W والدليل s"),
    ("النبض", "الرمز أوميغا، والواحدة راديان/ثانية = rad·s⁻¹"),
    ("الشحنة الكهربائية", "الرمز q فقط"),
    ("النفاذية المغناطيسية للخلاء", "الواحدة تيسلا·متر/أمبير"),
    ("الويبر", "الواحدة Wb"),
    ("يتناسب طرداً مع", "الرمز ~"),
    ("شعاع السرعة", "v وعكفة وأعلاها شعاع → v⃗"),
]

# items the teacher's answers left ambiguous — must not be guessed
OPEN_ITEMS = [
    ("مزدوجة الفتل — الرمز «جما ايتا»",
     "قُرئت كـ Γ مع دليل η. الرجاء تأكيد كتابة الرمز والدليل."),
    ("المزدوجة الكهرطيسية — الرمز «جما دلتا»",
     "قُرئت كـ Γ مع دليل Δ. هل الدليل Δ أم شيء آخر؟"),
    ("السؤال 15 — التردد / الجهد",
     "جاء الجواب «يجوز». هل المقصود: يجوز استخدام «التردد» بدل «التواتر» و«الجهد» بدل «التوتر» داخل التطبيق؟ "
     "هذا ينسف شرط مطابقة المنهاج السوري، لذا أرجو التأكيد (قد تكون «لا يجوز» وسقطت «لا» في الإملاء)."),
    ("عتبة التواتر — الرمز f مع الدليل s",
     "هل الدليل حرف s أم الرقم 0؟ المعتاد f₀ للتواتر العتبة."),
    ("27 مدخلاً لم تُعثر في نص الكتاب",
     "مثل: الكتلة الحجمية، شدة شعاع السطح، قانون فاراداي، المفاعلة، التواتر العتبة، التجويف الرنان، "
     "ثابت الجذب العام، الكيلوغرام، الكولون، السنتيمتر، الإلكترون فولط، جيب التمام… "
     "الرجاء إما إقرار صياغتها أو شطبها من الاستخدام."),
    ("القوة / الاستطاعة الكهربائية — محسوم بالدليل، أرجو تأكيده",
     "النص ص200 يعطي «القوة الكهربائية … F = k·e²/r²» أي Electric Force، وص125 «الاستطاعة الكهربائية … "
     "والاستطاعة الحرارية» أي Electric Power. إذن خطأ الجدول الرسمي ص287 في المقابل الإنكليزي لا في المصطلح العربي."),
]

# mistakes found INSIDE the official textbook's own bilingual glossary
BOOK_ERRORS = [
    ("القوة الكهربائية", "Electric Power (ص287)",
     "خطأ: القوة الكهربائية = Electric Force "
     "(الدليل ص200: F = k·e²/r²، وص268 من طبعة 2025–2026). "
     "الذي يعني Electric Power هو «الاستطاعة الكهربائية» (ص125).",
     "محسوم بالدليل + قرار الأستاذ (س13)"),
    ("الدور", "Phase (ص284)",
     "خطأ مطبعي: «الدور» = الزمن الدوري T. «الطور» هي Phase.",
     "محسوم — قرار الأستاذ (س7)"),
    ("النسبية الخاصة", "Conjugate Pairs (ص285)",
     "سطر تسرّب من كتاب الكيمياء إلى جدول الفيزياء. الصحيح: Special Relativity.",
     "محسوم — قرار الأستاذ (س8): يُلغى"),
    ("المحلوات الكهربائية", "Electric Transformer (ص286)",
     "الصحيح: «المحولة / المحولات الكهربائية».",
     "محسوم — قرار الأستاذ (س9 + س14)"),
    ("قانون فارداي", "كتابة بالألف في ص109",
     "التهجئة المعتمدة: فاراداي.",
     "محسوم — قرار الأستاذ (س10)"),
]


def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build_html(out: Path):
    h = ['<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width,initial-scale=1">',
         '<title>قائمة مصطلحات الفيزياء – الصف الثالث الثانوي العلمي</title>',
         f'<style>{CSS}</style></head><body>',
         '<header><h1>قائمة المصطلحات والرموز — فيزياء الصف الثالث الثانوي (الفرع العلمي)</h1>',
         f'<p>{total} مدخلاً، مبنية على نص الكتاب الرسمي. عمود القرار فارغ بالكامل للمراجعة.</p></header>',
         '<div class="bar">',
         '<input id="q" type="search" placeholder="ابحث عن مصطلح…">',
         '<select id="flt">'
         '<option value="all">كل المدخلات</option>'
         '<option value="undone">ما لم أقيّمه بعد</option>'
         '<option value="nf">التي لم تُعثر في الكتاب</option>'
         '<option value="no">التي علّمتها خطأ</option>'
         '<option value="na">غير المتأكد منها</option></select>',
         '<button class="btn" id="prn">طباعة</button>',
         '<button class="btn pri" id="copy">نسخ ملخص للواتساب</button>',
         '<button class="btn" id="exp">تصدير JSON</button>',
         '<button class="btn warn" id="clr">مسح</button>',
         '<span class="stat" id="stat"></span><span id="saved"></span>',
         '<div class="pw"><i id="pw"></i></div></div><main>',
         '<div class="note"><b>كيف تعمل:</b> لكل صف ثلاثة أزرار: '
         '✅ = المصطلح صحيح كما هو، ❌ = خاطئ (اكتب التصحيح في الحقل الأخير)، ➖ = غير متأكد.<br>'
         '<b>ثلاث درجات:</b> مصطلح رسمي (يُستعمل في الأسئلة دائماً) · '
         'مرادف مسموح (قسم ٧-أ: يُذكر في الشرح فقط) · ممنوع (قسم ٧-ب).<br>'
         '<b>عملك يُحفظ تلقائياً في المتصفح</b> — أغلق الملف وارجع متى شئت، وستجد ما أنجزته كما هو. '
         'عند الانتهاء اضغط «نسخ ملخص للواتساب» وأرسل النص.<br>'
         '<b>عمود «ورد في ص»</b> رقم الصفحة في الكتاب الذي ظهر فيه المصطلح — دليل للمراجعة فقط، وليس توكيداً.</div>']

    for key, title in CHAPTERS:
        items = rows.get(key) or []
        banned = key in ("BAN", "SYN")
        if not items:
            continue
        h.append(f'<section data-key="{key}">')
        h.append(f'<h2><span class="t">{esc(title)}</span><span class="p"></span></h2>')
        h.append('<table><thead><tr>'
                 '<th style="width:32px">#</th><th>المصطلح العربي</th>'
                 '<th style="width:180px">المقابل الإنكليزي</th>'
                 '<th style="width:70px">الرمز</th><th style="width:78px">وحدة القياس</th>'
                 '<th style="width:104px">المصدر</th><th style="width:92px">ورد في ص</th>'
                 '<th style="width:118px">القرار</th><th style="width:220px">تصحيح / ملاحظة</th>'
                 '</tr></thead><tbody>')
        for i, it in enumerate(items, 1):
            rid = f"{key}-{i}"
            if it["found"]:
                ev = '<span class="y">ص ' + "، ".join(str(p) for p in it["pages"]) + '</span>'
            elif banned:
                ev = ('<span class="y">غير وارد في الكتاب</span>' if key == "BAN"
                      else '<span class="y">مرادف مسموح</span>')
            else:
                ev = '<span class="n">لم يُعثر</span>'
            h.append(
                f'<tr data-row="{rid}" data-nf="{0 if it["found"] else 1}"><td>{i}</td>'
                f'<td class="term">{esc(it["ar"])}</td>'
                f'<td class="en">{esc(it["en"])}</td>'
                f'<td class="sym">{esc(it["sym"])}</td>'
                f'<td class="unit">{esc(it["unit"])}</td>'
                f'<td class="ev">{esc(it["src"])}</td>'
                f'<td class="ev">{ev}</td>'
                f'<td class="dec">'
                f'<button data-v="ok" title="صحيح">✅</button>'
                f'<button data-v="no" title="خاطئ">❌</button>'
                f'<button data-v="na" title="غير متأكد">➖</button></td>'
                f'<td><input class="corr" placeholder="اكتب التصحيح…"></td></tr>')
        h.append('</tbody></table></section>')

    h.append('<section><h2><span class="t">سجل القرارات — إجابات الأستاذ (١٦ سؤالاً)</span>'
             '<span class="p">مُجاب</span></h2>')
    h.append('<table><thead><tr><th style="width:32px">#</th><th>السؤال</th>'
             '<th style="width:330px">القرار</th></tr></thead><tbody>')
    for i, ((q, _evd), a) in enumerate(zip(QUESTIONS, ANSWERS), 1):
        h.append(f'<tr><td>{i}</td><td class="term">{esc(q)}</td>'
                 f'<td class="en" style="font-size:15px;color:#0f7b3f;font-weight:600">{esc(a)}</td></tr>')
    h.append('</tbody></table></section>')

    h.append(f'<section><h2><span class="t">التصحيحات المطبّقة — بنص الأستاذ ({len(RAWCORR)} بنداً)</span>'
             '<span class="p">مُطبّق</span></h2>')
    h.append('<table><thead><tr><th style="width:32px">#</th><th style="width:280px">المدخل</th>'
             '<th>التصحيح كما ورد</th></tr></thead><tbody>')
    for i, (t, c) in enumerate(RAWCORR, 1):
        h.append(f'<tr><td>{i}</td><td class="term">{esc(t)}</td><td>{esc(c)}</td></tr>')
    h.append('</tbody></table></section>')

    h.append(f'<section><h2><span class="t">بنود معلّقة تحتاج حسم ({len(OPEN_ITEMS)})</span>'
             '<span class="p" style="background:#fef2f2;color:#c0392b;border-color:#fecaca">'
             'لم تُحسم</span></h2>')
    for i, (t, d) in enumerate(OPEN_ITEMS, 1):
        h.append(f'<div class="q" style="background:#fff5f5;border-color:#fecaca">'
                 f'<b>{i}. {esc(t)}</b><div class="evd">{esc(d)}</div></div>')
    h.append(f'<section><h2><span class="t">أخطاء موجودة داخل الكتاب الرسمي نفسه ({len(BOOK_ERRORS)})</span>'
             '<span class="p" style="background:#fef2f2;color:#c0392b;border-color:#fecaca">'
             'لا تُنسخ</span></h2>')
    h.append('<table><thead><tr><th style="width:32px">#</th><th style="width:200px">المدخل</th>'
             '<th style="width:230px">ما في الكتاب</th><th>الصواب</th>'
             '<th style="width:170px">الحالة</th></tr></thead><tbody>')
    for i,(term,booktext,correct,st) in enumerate(BOOK_ERRORS,1):
        h.append(f'<tr><td>{i}</td><td class="term">{esc(term)}</td>'
                 f'<td style="color:#c0392b">{esc(booktext)}</td><td>{esc(correct)}</td>'
                 f'<td class="ev">{esc(st)}</td></tr>')
    h.append('</tbody></table></section>')
    h.append('</section></main>')
    h.append(f'<script>{JS}</script></body></html>')
    out.write_text("\n".join(h), encoding="utf-8")
    return out


# ----------------------------------------------------------------- DOCX
def build_docx(out: Path):
    from docx import Document
    from docx.enum.section import WD_ORIENT
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt

    doc = Document()
    s = doc.sections[0]
    s.orientation = WD_ORIENT.LANDSCAPE
    s.page_width, s.page_height = s.page_height, s.page_width
    st = doc.styles["Normal"]
    st.font.name = "Tahoma"
    st.font.size = Pt(10)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("قائمة المصطلحات والرموز — فيزياء الصف الثالث الثانوي العلمي\n"
                  "نسخة مراجعة الأستاذ — حقول القرار فارغة")
    r.bold = True
    r.font.size = Pt(15)

    for key, title in CHAPTERS:
        items = rows.get(key) or []
        if not items:
            if key in ("U1", "U2", "U3", "U4", "U5"):
                doc.add_heading(title, level=1)
            continue
        doc.add_heading(title, level=2)
        t = doc.add_table(rows=1, cols=8)
        t.style = "Table Grid"
        for j, htxt in enumerate(["#", "المصطلح", "الإنكليزي", "الرمز", "الوحدة",
                                  "المصدر", "ص", "☐ صحيح  ☐ خاطئ — التصحيح:"]):
            cell = t.rows[0].cells[j]
            cell.text = htxt
            for pp in cell.paragraphs:
                for rr in pp.runs:
                    rr.bold = True
        for i, it in enumerate(items, 1):
            c = t.add_row().cells
            c[0].text = str(i)
            c[1].text = it["ar"]
            c[2].text = it["en"]
            c[3].text = it["sym"]
            c[4].text = it["unit"]
            c[5].text = it["src"]
            c[6].text = (("ص " + "، ".join(str(x) for x in it["pages"]))
                         if it["found"] else ("غير وارد" if key == "BAN" else "—"))
            c[7].text = "☐ صحيح   ☐ خاطئ   التصحيح: ______________________"

    doc.add_page_break()
    doc.add_heading("أسئلة تحكيم", level=1)
    for i, (q, evd) in enumerate(QUESTIONS, 1):
        doc.add_paragraph(f"{i}. {q}").bold = True
        doc.add_paragraph(evd)
        doc.add_paragraph("القرار: ______________________________________________________")
    doc.save(out)
    return out


if __name__ == "__main__":
    payload = {"chapters": [{"key": k, "title": t,
                             "items": rows.get(k, [])} for k, t in CHAPTERS],
               "questions": [{"q": q, "evidence": e} for q, e in QUESTIONS]}
    (ROOT / "terminology.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")

    h = build_html(ROOT / "review.html")
    d = build_docx(ROOT / "review.docx")
    miss = [it["ar"] for k, v in rows.items() if k != "BAN" for it in v if not it["found"]]
    print(f"items: {total}  |  html: {h.stat().st_size//1024} KB  |  docx: {d.stat().st_size//1024} KB")
    print(f"not found in the book (excluding the banned list): {len(miss)}")
