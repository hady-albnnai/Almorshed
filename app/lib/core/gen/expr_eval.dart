// app/lib/core/gen/expr_eval.dart
//
// مقيّم تعابير مستقلّ (لا تنفيذ ديناميكيّ) — نقلٌ حرفيّ لـ tools/expr_eval.py
// المُثبَت تكافؤه مع Python.eval على 30006 نداء عبر قوالب المسائل الـ69 (صفر اختلاف).
//
// يدعم: أعداد/سلاسل/أسماء · + - * / ** (أُس يمينيّ) · سالب أحاديّ ·
// == != < > <= >= (وسلسلتها) · and/or/not · x in (…) · a if c else b ·
// نداء دوال من الفضاء الاسميّ. المطابقة مع بايثون مقصودة بدقّة.
library;

import 'dart:math' as math;

/// خطأ تقييم (قسمة على صفر، جذر سالب، أُس عقديّ…) ⇒ يُرفض السحب.
class ExprError implements Exception {
  ExprError(this.message);
  final String message;
  @override
  String toString() => 'ExprError: $message';
}

const _keywords = {'if', 'else', 'and', 'or', 'not', 'in', 'True', 'False', 'None'};
const _two = {'**', '==', '!=', '<=', '>=', '//'};
const _one = {'+', '-', '*', '/', '(', ')', '<', '>', ',', '%'};

class _Tok {
  const _Tok(this.type, this.value);
  final String type; // num, str, name, kw, op, eof
  final Object? value;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isAlpha(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;
bool _isAlnum(int c) => _isDigit(c) || _isAlpha(c);

List<_Tok> tokenize(String s) {
  final toks = <_Tok>[];
  int i = 0;
  final n = s.length;
  while (i < n) {
    final c = s[i];
    final cc = s.codeUnitAt(i);
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      i++;
      continue;
    }
    // سلسلة حرفية '…' أو "…"
    if (c == "'" || c == '"') {
      final q = c;
      int j = i + 1;
      final buf = StringBuffer();
      while (j < n && s[j] != q) {
        buf.write(s[j]);
        j++;
      }
      if (j >= n) throw ExprError('سلسلة غير مغلقة: $s');
      toks.add(_Tok('str', buf.toString()));
      i = j + 1;
      continue;
    }
    // عدد (صحيح/عشري/علمي)
    if (_isDigit(cc) || (c == '.' && i + 1 < n && _isDigit(s.codeUnitAt(i + 1)))) {
      int j = i;
      while (j < n && (_isDigit(s.codeUnitAt(j)) || s[j] == '.')) {
        j++;
      }
      if (j < n && (s[j] == 'e' || s[j] == 'E')) {
        j++;
        if (j < n && (s[j] == '+' || s[j] == '-')) j++;
        while (j < n && _isDigit(s.codeUnitAt(j))) {
          j++;
        }
      }
      final raw = s.substring(i, j);
      final isFloat = raw.contains('.') || raw.contains('e') || raw.contains('E');
      toks.add(_Tok('num', isFloat ? double.parse(raw) : int.parse(raw)));
      i = j;
      continue;
    }
    // معرّف/كلمة مفتاحية
    if (_isAlpha(cc)) {
      int j = i;
      while (j < n && _isAlnum(s.codeUnitAt(j))) {
        j++;
      }
      final word = s.substring(i, j);
      toks.add(_Tok(_keywords.contains(word) ? 'kw' : 'name', word));
      i = j;
      continue;
    }
    // عامل ثنائي ثمّ أحادي
    final two = (i + 1 < n) ? s.substring(i, i + 2) : '';
    if (_two.contains(two)) {
      toks.add(_Tok('op', two));
      i += 2;
      continue;
    }
    if (_one.contains(c)) {
      toks.add(_Tok('op', c));
      i++;
      continue;
    }
    throw ExprError('رمز غير متوقّع "$c" في $s');
  }
  toks.add(const _Tok('eof', null));
  return toks;
}

class _Parser {
  _Parser(this.toks, this.ns);
  final List<_Tok> toks;
  final Map<String, Object?> ns;
  int pos = 0;

  _Tok peek() => toks[pos];
  _Tok next() => toks[pos++];

  void expectOp(String op) {
    final t = next();
    if (t.type != 'op' || t.value != op) {
      throw ExprError('توقّعت "$op" فوجدت ${t.value}');
    }
  }

  bool _isOp(_Tok t, String v) => t.type == 'op' && t.value == v;
  bool _isKw(_Tok t, String v) => t.type == 'kw' && t.value == v;

  Object? parse() {
    final v = ternary();
    if (peek().type != 'eof') throw ExprError('رموز زائدة: ${peek().value}');
    return v;
  }

  Object? ternary() {
    final v = or_();
    final t = peek();
    if (_isKw(t, 'if')) {
      next();
      final cond = or_();
      final e = next();
      if (!_isKw(e, 'else')) throw ExprError('توقّعت else في الشرطيّ');
      final other = ternary();
      return _truth(cond) ? v : other;
    }
    return v;
  }

  Object? or_() {
    var v = and_();
    while (_isKw(peek(), 'or')) {
      next();
      final r = and_();
      v = _truth(v) ? v : r;
    }
    return v;
  }

  Object? and_() {
    var v = not_();
    while (_isKw(peek(), 'and')) {
      next();
      final r = not_();
      v = _truth(v) ? r : v;
    }
    return v;
  }

  Object? not_() {
    if (_isKw(peek(), 'not')) {
      next();
      return !_truth(not_());
    }
    return comparison();
  }

  static const _cmpOps = {'==', '!=', '<', '>', '<=', '>='};

  Object? comparison() {
    final v = add();
    bool? result;
    Object? left = v;
    while (true) {
      final t = peek();
      final isIn = _isKw(t, 'in');
      bool ok;
      Object? right;
      if (t.type == 'op' && _cmpOps.contains(t.value)) {
        next();
        right = add();
        ok = _cmp(t.value as String, left, right);
      } else if (isIn) {
        next();
        right = add();
        ok = _inOp(left, right);
      } else {
        break;
      }
      result = (result == null) ? ok : (result && ok);
      left = right;
    }
    return result ?? v;
  }

  Object? add() {
    var v = mul();
    while (peek().type == 'op' && (peek().value == '+' || peek().value == '-')) {
      final op = next().value as String;
      final r = mul();
      v = _arith(op, v, r);
    }
    return v;
  }

  Object? mul() {
    var v = unary();
    while (peek().type == 'op' &&
        (peek().value == '*' || peek().value == '/' || peek().value == '//' || peek().value == '%')) {
      final op = next().value as String;
      final r = unary();
      v = _arith(op, v, r);
    }
    return v;
  }

  Object? unary() {
    final t = peek();
    if (t.type == 'op' && (t.value == '-' || t.value == '+')) {
      next();
      final v = unary();
      if (v is! num) throw ExprError('سالب أحاديّ على غير عدد');
      return t.value == '-' ? -v : v;
    }
    return power();
  }

  Object? power() {
    final base = postfix();
    if (_isOp(peek(), '**')) {
      next();
      final exp = unary();
      return _pow(base, exp);
    }
    return base;
  }

  Object? postfix() {
    var v = atom();
    while (_isOp(peek(), '(')) {
      if (v is! Function) throw ExprError('نداء غير قابل للاستدعاء');
      next();
      final args = <Object?>[];
      if (!_isOp(peek(), ')')) {
        args.add(ternary());
        while (_isOp(peek(), ',')) {
          next();
          args.add(ternary());
        }
      }
      expectOp(')');
      v = _callFn(v, args);
    }
    return v;
  }

  Object? atom() {
    final t = next();
    switch (t.type) {
      case 'num':
        return t.value;
      case 'str':
        return t.value;
      case 'kw':
        if (t.value == 'True') return true;
        if (t.value == 'False') return false;
        if (t.value == 'None') return null;
        throw ExprError('كلمة مفتاحية غير متوقّعة: ${t.value}');
      case 'name':
        final name = t.value as String;
        if (!ns.containsKey(name)) throw ExprError('اسم غير معرّف: $name');
        return ns[name];
      case 'op':
        if (t.value == '(') {
          final v = ternary();
          if (_isOp(peek(), ',')) {
            final items = <Object?>[v];
            while (_isOp(peek(), ',')) {
              next();
              if (_isOp(peek(), ')')) break;
              items.add(ternary());
            }
            expectOp(')');
            return items; // صفّ (tuple) لعامل in
          }
          expectOp(')');
          return v;
        }
    }
    throw ExprError('ذرّة غير متوقّعة: ${t.value}');
  }
}

bool _truth(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty;
  if (v is List) return v.isNotEmpty;
  return true;
}

bool _inOp(Object? a, Object? b) {
  if (b is List) return b.any((x) => _eq(a, x));
  throw ExprError('عامل in على غير صفّ');
}

bool _eq(Object? a, Object? b) {
  if (a is num && b is num) return a == b; // مقارنة عدديّة كبايثون
  return a == b;
}

bool _cmp(String op, Object? a, Object? b) {
  switch (op) {
    case '==':
      return _eq(a, b);
    case '!=':
      return !_eq(a, b);
  }
  if (a is num && b is num) {
    switch (op) {
      case '<':
        return a < b;
      case '>':
        return a > b;
      case '<=':
        return a <= b;
      case '>=':
        return a >= b;
    }
  }
  throw ExprError('مقارنة $op على غير عدد');
}

Object? _arith(String op, Object? a, Object? b) {
  if (a is String || b is String) {
    if (op == '+' && a is String && b is String) return a + b;
    throw ExprError('عامل $op على سلسلة');
  }
  if (a is! num || b is! num) throw ExprError('عامل $op على غير عدد');
  switch (op) {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case '*':
      return a * b;
    case '/':
      if (b == 0) throw ExprError('قسمة على صفر');
      return a / b; // قسمة حقيقيّة (double) كبايثون
    case '//':
      if (b == 0) throw ExprError('قسمة على صفر');
      return (a / b).floor();
    case '%':
      if (b == 0) throw ExprError('قسمة على صفر');
      return a % b;
  }
  throw ExprError(op);
}

Object? _pow(Object? a, Object? b) {
  if (a is! num || b is! num) throw ExprError('أُس على غير عدد');
  if (a < 0 && b is double && b != b.roundToDouble()) {
    throw ExprError('أُس ناتجه عقديّ'); // أساس سالب بأُس كسريّ
  }
  final r = math.pow(a, b);
  if (r is! num || r.isNaN || r.isInfinite) throw ExprError('أُس غير صالح');
  return r;
}

Object? _callFn(Function f, List<Object?> args) {
  try {
    return Function.apply(f, args);
  } on ExprError {
    rethrow;
  } catch (e) {
    throw ExprError('$e');
  }
}

/// قيّم تعبيراً نصياً ضمن فضاء اسميّ. يرمي [ExprError] عند أي تعذّر.
Object? evaluate(String expr, Map<String, Object?> ns) =>
    _Parser(tokenize(expr), ns).parse();
