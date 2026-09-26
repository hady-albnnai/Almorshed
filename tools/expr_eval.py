#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/expr_eval.py — مقيّم تعابير مستقلّ (لا `eval`) لقوالب المسائل (parts-v1).

الهدف: نواة رياضيّة **قابلة للنقل حرفياً إلى Dart** حتى يولّد التطبيق مسائل بلا
حدّ على الجهاز. القواعد المدعومة تغطّي كل تعابير قوالب الـparts الـ69:
  • أعداد (صحيحة/عشرية/علمية 1e-3) · سلاسل 'نص'
  • أسماء من الفضاء الاسمي (g, pi, pi_sq, ثوابت، متغيّرات)
  • + - * / ** (أُس يمينيّ) · سالب أحاديّ
  • مقارنات == != < > <= >= (وسلسلتها بأسلوب بايثون a<b<c)
  • منطق and / or / not · عضويّة x in (…)
  • شرطيّ ثلاثيّ: a if cond else b
  • نداء دوال: sqrt(x) · abs(x) … (من الفضاء الاسمي)

المطابقة مع بايثون مقصودة بدقّة: `/` قسمة حقيقيّة، `int()` بتر نحو الصفر،
`round()` تقريب مصرفيّ (banker's)، `**` لأساس سالب بأُس كسريّ ⇒ خطأ (كبايثون→عقدي).
النقل إلى Dart في app/lib/core/gen/expr_eval.dart يحاكي هذه الدلالات نفسها.
"""
from __future__ import annotations

import math


class ExprError(Exception):
    """خطأ تقييم (قسمة على صفر، جذر سالب، أُس غير صالح…) ⇒ يُرفض السحب."""


# ───────────────────────────── المُحلّل اللفظي (Tokenizer) ─────────────────────────────
_KEYWORDS = {"if", "else", "and", "or", "not", "in", "True", "False", "None"}
_TWO = {"**", "==", "!=", "<=", ">=", "//"}
_ONE = set("+-*/()<>,%")


def tokenize(s: str):
    toks, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c in " \t\n\r":
            i += 1
            continue
        # سلسلة حرفية '…' أو "…"
        if c in "'\"":
            q = c
            j = i + 1
            buf = []
            while j < n and s[j] != q:
                buf.append(s[j])
                j += 1
            if j >= n:
                raise ExprError(f"سلسلة غير مغلقة: {s!r}")
            toks.append(("str", "".join(buf)))
            i = j + 1
            continue
        # عدد (صحيح/عشري/علمي)
        if c.isdigit() or (c == "." and i + 1 < n and s[i + 1].isdigit()):
            j = i
            while j < n and (s[j].isdigit() or s[j] == "."):
                j += 1
            if j < n and s[j] in "eE":
                j += 1
                if j < n and s[j] in "+-":
                    j += 1
                while j < n and s[j].isdigit():
                    j += 1
            raw = s[i:j]
            val = float(raw) if any(ch in raw for ch in ".eE") else int(raw)
            toks.append(("num", val))
            i = j
            continue
        # معرّف/كلمة مفتاحية
        if c.isalpha() or c == "_":
            j = i
            while j < n and (s[j].isalnum() or s[j] == "_"):
                j += 1
            word = s[i:j]
            toks.append(("kw", word) if word in _KEYWORDS else ("name", word))
            i = j
            continue
        # عامل ثنائي الحرف ثمّ أحادي
        two = s[i:i + 2]
        if two in _TWO:
            toks.append(("op", two))
            i += 2
            continue
        if c in _ONE:
            toks.append(("op", c))
            i += 1
            continue
        raise ExprError(f"رمز غير متوقّع {c!r} في {s!r}")
    toks.append(("eof", None))
    return toks


# ───────────────────────────── المُحلّل النحوي + المُقيّم (Pratt/تنازليّ) ─────────────────────────────
class _Parser:
    def __init__(self, toks, ns):
        self.toks = toks
        self.pos = 0
        self.ns = ns

    def peek(self):
        return self.toks[self.pos]

    def next(self):
        t = self.toks[self.pos]
        self.pos += 1
        return t

    def expect_op(self, op):
        t = self.next()
        if t[0] != "op" or t[1] != op:
            raise ExprError(f"توقّعت {op!r} فوجدت {t!r}")

    # الأولوية من الأدنى (ثلاثيّ) إلى الأعلى (أُس/نداء/ذرّة)
    def parse(self):
        v = self.ternary()
        if self.peek()[0] != "eof":
            raise ExprError(f"رموز زائدة: {self.peek()!r}")
        return v

    def ternary(self):
        v = self.or_()
        t = self.peek()
        if t[0] == "kw" and t[1] == "if":
            self.next()
            cond = self.or_()
            e = self.next()
            if not (e[0] == "kw" and e[1] == "else"):
                raise ExprError("توقّعت else في الشرطيّ")
            other = self.ternary()
            return v if _truth(cond) else other
        return v

    def or_(self):
        v = self.and_()
        while self.peek() == ("kw", "or"):
            self.next()
            r = self.and_()
            v = v if _truth(v) else r
        return v

    def and_(self):
        v = self.not_()
        while self.peek() == ("kw", "and"):
            self.next()
            r = self.not_()
            v = r if _truth(v) else v
        return v

    def not_(self):
        if self.peek() == ("kw", "not"):
            self.next()
            return not _truth(self.not_())
        return self.comparison()

    _CMP = {"==", "!=", "<", ">", "<=", ">="}

    def comparison(self):
        v = self.add()
        # سلسلة مقارنات بأسلوب بايثون: a < b < c ≡ (a<b) and (b<c)
        result = None
        left = v
        while True:
            t = self.peek()
            is_in = t == ("kw", "in")
            if t[0] == "op" and t[1] in self._CMP:
                self.next()
                right = self.add()
                ok = _cmp(t[1], left, right)
            elif is_in:
                self.next()
                right = self.add()
                ok = left in right
            else:
                break
            result = ok if result is None else (result and ok)
            left = right
        return v if result is None else result

    def add(self):
        v = self.mul()
        while self.peek()[0] == "op" and self.peek()[1] in ("+", "-"):
            op = self.next()[1]
            r = self.mul()
            v = _arith(op, v, r)
        return v

    def mul(self):
        v = self.unary()
        while self.peek()[0] == "op" and self.peek()[1] in ("*", "/", "//", "%"):
            op = self.next()[1]
            r = self.unary()
            v = _arith(op, v, r)
        return v

    def unary(self):
        t = self.peek()
        if t[0] == "op" and t[1] in ("-", "+"):
            self.next()
            v = self.unary()
            return -v if t[1] == "-" else +v
        return self.power()

    def power(self):
        base = self.postfix()
        if self.peek() == ("op", "**"):
            self.next()
            exp = self.unary()          # الأُس يمينيّ ويقبل سالباً أحاديّاً
            return _pow(base, exp)
        return base

    def postfix(self):
        v = self.atom()
        # نداء دالّة: name(args)
        while self.peek() == ("op", "("):
            if not callable(v):
                raise ExprError("نداء غير قابل للاستدعاء")
            self.next()
            args = []
            if self.peek() != ("op", ")"):
                args.append(self.ternary())
                while self.peek() == ("op", ","):
                    self.next()
                    args.append(self.ternary())
            self.expect_op(")")
            try:
                v = v(*args)
            except ExprError:
                raise
            except (ValueError, ZeroDivisionError, OverflowError, TypeError) as e:
                raise ExprError(str(e))
        return v

    def atom(self):
        t = self.next()
        if t[0] == "num":
            return t[1]
        if t[0] == "str":
            return t[1]
        if t[0] == "kw" and t[1] in ("True", "False", "None"):
            return {"True": True, "False": False, "None": None}[t[1]]
        if t[0] == "name":
            if t[1] not in self.ns:
                raise ExprError(f"اسم غير معرّف: {t[1]}")
            return self.ns[t[1]]
        if t == ("op", "("):
            # قوس تجميع أو صفّ (tuple) لعامل in
            v = self.ternary()
            if self.peek() == ("op", ","):
                items = [v]
                while self.peek() == ("op", ","):
                    self.next()
                    if self.peek() == ("op", ")"):
                        break
                    items.append(self.ternary())
                self.expect_op(")")
                return tuple(items)
            self.expect_op(")")
            return v
        raise ExprError(f"ذرّة غير متوقّعة: {t!r}")


def _truth(v):
    return bool(v)


def _cmp(op, a, b):
    if op == "==":
        return a == b
    if op == "!=":
        return a != b
    if op == "<":
        return a < b
    if op == ">":
        return a > b
    if op == "<=":
        return a <= b
    if op == ">=":
        return a >= b
    raise ExprError(op)


def _arith(op, a, b):
    if isinstance(a, str) or isinstance(b, str):
        if op == "+" and isinstance(a, str) and isinstance(b, str):
            return a + b
        raise ExprError(f"عامل {op} على سلسلة")
    try:
        if op == "+":
            return a + b
        if op == "-":
            return a - b
        if op == "*":
            return a * b
        if op == "/":
            return a / b
        if op == "//":
            return a // b
        if op == "%":
            return a % b
    except ZeroDivisionError:
        raise ExprError("قسمة على صفر")
    raise ExprError(op)


def _pow(a, b):
    try:
        r = a ** b
    except (ValueError, ZeroDivisionError, OverflowError) as e:
        raise ExprError(str(e))
    if isinstance(r, complex):
        raise ExprError("أُس ناتجه عقديّ")
    return r


def evaluate(expr, ns):
    """قيّم تعبيراً نصياً ضمن فضاء اسميّ (dict). يرمي ExprError عند أي تعذّر."""
    if not isinstance(expr, str):
        return expr
    return _Parser(tokenize(expr), ns).parse()


if __name__ == "__main__":
    # فحص سريع
    ns = {"sqrt": math.sqrt, "pi": math.pi, "abs": abs, "g": 10, "pi_sq": 10}
    for e in ["2**3", "-2**2", "2**-1", "sqrt(2)", "3 if 1==1 else 4",
              "1/2 + 0.5", "abs(-5)", "2 in (1,2,3)", "1 < 2 < 3", "'a'+'b'"]:
        print(f"{e:20} = {evaluate(e, ns)!r}")
