// app/lib/core/gen/problem_engine.dart
//
// محرّك توليد مسائل «سطراً سطراً» على الجهاز — توليد لا متناهٍ بلا أصل ضخم.
// نقلٌ حرفيّ لـ tools/engine_ref.py المُثبَت مطابقته لمولّد بايثون المتحقَّق
// (69/69 · 22138/22138) على 3537 تجهيزة ذهبية (صفر اختلاف).
//
// يقرأ assets/content/templates.json (≈177KB) ويولّد مسائل صحيحة لأي توليفة
// قيم؛ RNG داخليّ خاصّ بالإنتاج، بينما النواة الحتميّة تُختبر ذهبياً في
// test/gen_golden_test.dart. كل دالّة تقابل نظيرتها في engine_ref.py.
library;

import 'dart:math' as math;

import 'expr_eval.dart';

const String kMinus = '−';
const double kTol = 0.02;
const Map<String, int> _linePoints = {
  'relation': 5,
  'substitution': 3,
  'result': 1,
  'unit': 1,
};
const _sup = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
};

// ───────────────────────────── منسّقات (نظائرها في engine_ref.py) ─────────────────────────────
String _rstrip(String s, String ch) {
  var e = s.length;
  while (e > 0 && s[e - 1] == ch) {
    e--;
  }
  return s.substring(0, e);
}

String _lstrip(String s, String ch) {
  var b = 0;
  while (b < s.length && s[b] == ch) {
    b++;
  }
  return s.substring(b);
}

String _supStr(int e) =>
    e.toString().split('').map((c) => _sup[c] ?? c).join();

/// تقريب إلى [nd] منزلة — القيم المارّة من nice/nice_sci تكون على الدقّة أصلاً
/// فلا يبقى للتساوي أثر عمليّ (يطابق round بايثون على مادّتنا).
double _round(double x, int nd) {
  final p = math.pow(10, nd).toDouble();
  return (x * p).roundToDouble() / p;
}

/// floor(log10|x|) صحيح رياضياً (يعالج أخطاء الحدود العائمة).
int _floorLog10(double x) {
  x = x.abs();
  var e = (math.log(x) / math.ln10).floor();
  while (math.pow(10, e + 1) <= x) {
    e++;
  }
  while (math.pow(10, e) > x) {
    e--;
  }
  return e;
}

String fmt(num x, {int nd = 4}) {
  final xd = x.toDouble();
  String s;
  if ((xd - xd.roundToDouble()).abs() < 1e-9) {
    s = xd.round().toString();
  } else {
    s = _rstrip(_rstrip(xd.toStringAsFixed(nd), '0'), '.');
  }
  return s.replaceAll('-', kMinus);
}

String fmtSci(num x, {int sig = 3}) {
  final xd = x.toDouble();
  if (xd == 0) return '0';
  var e = _floorLog10(xd);
  var m = _round(xd / math.pow(10, e).toDouble(), sig - 1);
  if (m.abs() >= 10) {
    m = m / 10;
    e += 1;
  }
  final ms = fmt(m);
  if (e == 0) return ms;
  if (ms == '1' || ms == '−1') {
    return '${m < 0 ? '−' : ''}10${_supStr(e)}';
  }
  return '$ms×10${_supStr(e)}';
}

bool nice(num x) {
  final xd = x.toDouble();
  if (!xd.isFinite) return false;
  final r = _round(xd, 4);
  if ((xd - r).abs() > 1e-9) return false;
  var d = r.abs().toStringAsFixed(4);
  d = _rstrip(_rstrip(d, '0'), '.');
  d = d.replaceAll('.', '');
  d = _lstrip(d, '0');
  return d.length <= 3;
}

bool niceSci(num x, {int sig = 3}) {
  final xd = x.toDouble();
  if (xd == 0 || !xd.isFinite) return false;
  final e = _floorLog10(xd);
  final m = xd / math.pow(10, e).toDouble();
  return (m - _round(m, sig - 1)).abs() < 1e-9 * math.max(1, m.abs());
}

String norm(Object? s) => s.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

bool close(num? a, num? b) {
  if (a == null || b == null) return false;
  if (a == b) return true;
  return (a - b).abs() <= kTol * math.max(a.abs(), b.abs());
}

// ───────────────────────────── كسور (نقل CPython Fraction) ─────────────────────────────
class Frac {
  Frac(this.num_, this.den) {
    if (den < BigInt.zero) {
      num_ = -num_;
      den = -den;
    }
    final g = num_.abs().gcd(den);
    if (g > BigInt.one) {
      num_ = num_ ~/ g;
      den = den ~/ g;
    }
  }

  BigInt num_;
  BigInt den;

  /// النسبة الصحيحة الدقيقة لعدد عائم (نظير float.as_integer_ratio).
  factory Frac.fromDouble(double x) {
    if (x == 0) return Frac(BigInt.zero, BigInt.one);
    final neg = x < 0;
    var y = x.abs();
    var k = 0;
    while (y != y.truncateToDouble() && k < 1100) {
      y *= 2;
      k++;
    }
    var numer = BigInt.from(y);
    var den = BigInt.one << k;
    if (neg) numer = -numer;
    return Frac(numer, den);
  }

  double toDouble() => num_.toDouble() / den.toDouble();

  /// نظير Fraction.limit_denominator بخوارزمية الكسور المستمرّة نفسها.
  Frac limitDenominator(int maxDen) {
    final md = BigInt.from(maxDen);
    if (den <= md) return this;
    var p0 = BigInt.zero, q0 = BigInt.one, p1 = BigInt.one, q1 = BigInt.zero;
    var n = num_, d = den;
    while (true) {
      final a = n ~/ d;
      final q2 = q0 + a * q1;
      if (q2 > md) break;
      final tmpP = p0 + a * p1;
      p0 = p1;
      q0 = q1;
      p1 = tmpP;
      q1 = q2;
      final tmpN = d;
      d = n - a * d;
      n = tmpN;
    }
    final k = (md - q0) ~/ q1;
    final bound1 = Frac(p0 + k * p1, q0 + k * q1);
    final bound2 = Frac(p1, q1);
    final self = toDouble();
    if ((bound2.toDouble() - self).abs() <= (bound1.toDouble() - self).abs()) {
      return bound2;
    }
    return bound1;
  }
}

BigInt? _isqrtExact(BigInt n) {
  if (n < BigInt.zero) return null;
  if (n < BigInt.two) return n;
  var x = BigInt.from(math.sqrt(n.toDouble()).floor());
  // ضبط دقيق
  while (x * x > n) {
    x -= BigInt.one;
  }
  while ((x + BigInt.one) * (x + BigInt.one) <= n) {
    x += BigInt.one;
  }
  return (x * x == n) ? x : null;
}

String sqrtStr(num val) {
  final fr = Frac.fromDouble(val.toDouble()).limitDenominator(10000);
  final p = fr.num_, q = fr.den;
  final sp = _isqrtExact(p), sq = _isqrtExact(q);
  if (sp != null && sq != null) {
    return fmt(sp.toDouble() / sq.toDouble());
  }
  if (q == BigInt.one) return '√$p';
  if (sq != null) return '√$p/$sq';
  return '√($p/$q)';
}

String piStr(num c) {
  final fr = Frac.fromDouble(c.toDouble()).limitDenominator(1000);
  final sign = fr.num_ < BigInt.zero ? kMinus : '';
  final num_ = fr.num_.abs(), den = fr.den;
  if (num_ == BigInt.zero) return '0';
  if (num_ == den) return '${sign}π';
  if (den == BigInt.one) return '$sign${num_}π';
  if (num_ == BigInt.one) return '${sign}π/$den';
  return '$sign${num_}π/$den';
}

// ───────────────────────────── الفضاء الاسميّ للتقييم ─────────────────────────────
num _sqrt(num x) {
  if (x < 0) throw ExprError('جذر عدد سالب');
  return math.sqrt(x);
}

num _log(num x) {
  if (x <= 0) throw ExprError('لوغاريتم مجاله موجب');
  return math.log(x);
}

num _log10(num x) {
  if (x <= 0) throw ExprError('لوغاريتم مجاله موجب');
  return math.log(x) / math.ln10;
}

num _acos(num x) {
  if (x < -1 || x > 1) throw ExprError('acos مجاله [−1,1]');
  return math.acos(x);
}

num _asin(num x) {
  if (x < -1 || x > 1) throw ExprError('asin مجاله [−1,1]');
  return math.asin(x);
}

Object _pyround(num x, [num? nd]) {
  if (nd == null) return x.round();
  final p = math.pow(10, nd.toInt()).toDouble();
  return (x.toDouble() * p).roundToDouble() / p;
}

final Map<String, Object?> _nsFuncs = {
  'sqrt': _sqrt,
  'sin': (num x) => math.sin(x),
  'cos': (num x) => math.cos(x),
  'tan': (num x) => math.tan(x),
  'acos': _acos,
  'asin': _asin,
  'atan': (num x) => math.atan(x),
  'abs': (num x) => x.abs(),
  'log': _log,
  'log10': _log10,
  'exp': (num x) => math.exp(x),
  'round': _pyround,
  'min': (num a, num b) => math.min(a, b),
  'max': (num a, num b) => math.max(a, b),
  'floor': (num x) => x.floor(),
  'ceil': (num x) => x.ceil(),
  'int': (num x) => x.toInt(),
  'float': (num x) => x.toDouble(),
  'radians': (num x) => x * math.pi / 180.0,
  'degrees': (num x) => x * 180.0 / math.pi,
  'pi': math.pi,
};

// ───────────────────────────── المحرّك ─────────────────────────────
class ProblemEngine {
  ProblemEngine(Map<String, dynamic> asset)
      : constants = Map<String, Object?>.from(asset['constants'] as Map? ?? {}),
        nsExtra = Map<String, Object?>.from(asset['namespace'] as Map? ?? {}),
        rules = ((asset['distractorRules'] as Map?)?.keys.cast<String>().toSet()) ?? <String>{},
        templates = {
          for (final t in (asset['templates'] as List))
            (t as Map)['id'] as String: Map<String, dynamic>.from(t)
        };

  final Map<String, Object?> constants;
  final Map<String, Object?> nsExtra;
  final Set<String> rules;
  final Map<String, Map<String, dynamic>> templates;

  Map<String, Object?> _ns(Map<String, Object?> env) => {
        ..._nsFuncs,
        ...constants,
        ...nsExtra,
        ...env,
      };

  Object? _ev(Object? expr, Map<String, Object?> env) {
    if (expr is! String) return expr;
    return evaluate(expr, _ns(env));
  }

  static final _renderRe =
      RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)(?::(sci|pi|sqrt))?\}');

  String _render(String text, Map<String, Object?> env) {
    return text.replaceAllMapped(_renderRe, (m) {
      final k = m.group(1)!;
      final spec = m.group(2);
      if (!env.containsKey(k)) return m.group(0)!;
      final v = env[k];
      if (v is bool) return v ? 'True' : 'False';
      if (v is num) {
        if (spec == 'sci') return fmtSci(v.toDouble());
        if (spec == 'sqrt') return sqrtStr(v);
        if (spec == 'pi') return piStr(v);
        final fv = v.toDouble();
        if (fv != 0 && fv.isFinite) {
          final isInt = (fv - fv.roundToDouble()).abs() < 1e-9;
          if (fv.abs() < 1e-4 ||
              fv.abs() >= 1e10 ||
              (fv.abs() >= 1e4 && !isInt)) {
            return fmtSci(fv);
          }
        }
        return fmt(v);
      }
      return v.toString();
    });
  }

  /// السحب: توليفة set كاملة عبر [base] ثمّ compute ثمّ constraints. null ⇒ مرفوض.
  Map<String, Object?>? draw(Map<String, dynamic> t, Map<String, Object?> base) {
    final env = <String, Object?>{};
    final vars = (t['vars'] as Map?) ?? const {};
    for (final entry in vars.entries) {
      final name = entry.key as String;
      final spec = entry.value;
      if (base.containsKey(name)) {
        env[name] = base[name];
      } else if (spec is Map && spec.containsKey('set')) {
        throw StateError('المحرّك يتطلّب توليفة set كاملة: $name');
      } else {
        env[name] = spec;
      }
    }
    final compute = (t['compute'] as Map?) ?? const {};
    for (final entry in compute.entries) {
      try {
        env[entry.key as String] = _ev(entry.value, env);
      } on ExprError {
        return null;
      }
    }
    final constraints = (t['constraints'] as List?) ?? const [];
    for (final c in constraints) {
      try {
        final r = _ev(c, env);
        if (!(r == true || (r is num && r != 0))) return null;
      } on ExprError {
        return null;
      }
    }
    return env;
  }

  _Key? _partKey(Map<String, dynamic> p, Map<String, Object?> penv) {
    final ans = (p['answer'] as Map?) ?? const {};
    final unit = _render((p['unit'] as String?) ?? '', penv);
    if (p['text'] != null && (p['text'] as String).isNotEmpty) {
      double? val;
      if (p['value'] != null) {
        Object? v;
        try {
          v = _ev(p['value'], penv);
        } on ExprError {
          return null;
        }
        if (v is! num || v is bool || !v.isFinite) return null;
        val = v.toDouble();
      }
      return _Key(_render(p['text'] as String, penv), val, unit);
    }
    Object? v;
    try {
      v = _ev(p['value'], penv);
    } on ExprError {
      return null;
    }
    if (v is! num || v is bool || !v.isFinite) return null;
    var val = v.toDouble();
    final sig = (ans['sig'] as int?) ?? 3;
    final mode = (ans['format'] as String?) ?? 'auto';
    final sci = mode == 'sci' ||
        (mode == 'auto' && (val.abs() >= 1e4 || (val.abs() > 0 && val.abs() < 1e-2)));
    if (ans['round'] == true && val != 0) {
      val = double.parse(val.toStringAsExponential(sig - 1));
    }
    if (sci) {
      if (!niceSci(val, sig: sig)) return null;
      return _Key('${fmtSci(val, sig: sig)} $unit'.trim(), val, unit);
    }
    if (!nice(val)) return null;
    return _Key('${fmt(val)} $unit'.trim(), val, unit);
  }

  _Rubric _partRubric(List<Map<String, Object?>> lines, String label, String keyText) {
    final out = <Map<String, Object?>>[];
    num total = 0;
    for (final ln in lines) {
      final pts = Map<String, int>.from(_linePoints);
      final over = ln['points'];
      if (over is Map) {
        over.forEach((k, val) => pts[k as String] = (val as num).toInt());
      }
      final relation = ln['relation'];
      if (relation != null) {
        out.add({'step': '$label · العلاقة: $relation', 'points': pts['relation'], 'kind': 'relation'});
        total += pts['relation']!;
      }
      if (ln['subst'] != null) {
        out.add({'step': "$label · التعويض: ${ln['subst']}", 'points': pts['substitution'], 'kind': 'substitution'});
        total += pts['substitution']!;
      }
      final resultFlag = ln.containsKey('result') ? ln['result'] : true;
      if (resultFlag != false) {
        final rv = (ln['result'] is String && (ln['result'] as String).isNotEmpty)
            ? ln['result']
            : (keyText.isNotEmpty ? keyText : 'القيمة الصحيحة');
        out.add({'step': '$label · النتيجة: $rv', 'points': pts['result'], 'kind': 'result'});
        total += pts['result']!;
      }
      final unitFlag = ln.containsKey('unit') ? ln['unit'] : true;
      if (unitFlag != false && relation != null) {
        out.add({'step': '$label · الوحدة', 'points': pts['unit'], 'kind': 'unit'});
        total += pts['unit']!;
      }
    }
    return _Rubric(out, total);
  }

  List<String> _partOptions(
      Map<String, dynamic> p, Map<String, Object?> penv, String keyText, double? keyVal) {
    final ds = <_Dist>[];
    for (final dRaw in (p['distractors'] as List?) ?? const []) {
      final d = dRaw as Map;
      final rule = d['rule'] as String?;
      if (rule == null || !rules.contains(rule)) {
        throw StateError('قاعدة مشتت غير موثّقة: $rule');
      }
      if (d.containsKey('text')) {
        ds.add(_Dist(_render(d['text'] as String, penv), null));
        continue;
      }
      Object? vRaw;
      try {
        vRaw = _ev(d['value'], penv);
      } on ExprError {
        continue;
      }
      if (vRaw is! num || !vRaw.isFinite) continue;
      final v = vRaw.toDouble();
      final txt = _render((d['value_format'] as String?) ?? '{v}', {...penv, 'v': v});
      if (keyVal == null) {
        ds.add(_Dist(txt, null));
      } else {
        if (!nice(v) && d['allow_rough'] != true) continue;
        ds.add(_Dist(txt, v));
      }
    }
    final chosen = <String>[];
    final seen = <String>{norm(keyText)};
    final vals = <double?>[keyVal];
    for (final dd in ds) {
      if (seen.contains(norm(dd.txt))) continue;
      if (dd.val != null && vals.any((x) => x != null && close(dd.val, x))) {
        continue;
      }
      seen.add(norm(dd.txt));
      vals.add(dd.val);
      chosen.add(dd.txt);
      if (chosen.length == 3) break;
    }
    if (chosen.length < 3) return const [];
    return [keyText, ...chosen];
  }

  /// يولّد مسألة كاملة من توليفة [base]. null ⇒ توليفة مرفوضة.
  Map<String, Object?>? fromParts(Map<String, dynamic> t, Map<String, Object?> base) {
    final env = draw(t, base);
    if (env == null) return null;
    final stem = _render(t['stem'] as String, env);
    const labels = ['١', '٢', '٣', '٤', '٥', '٦', '٧'];
    final parts = <Map<String, Object?>>[];
    num weight = 0;
    final penv = Map<String, Object?>.from(env);
    final rawParts = t['parts'] as List;
    for (var i = 0; i < rawParts.length; i++) {
      final p = rawParts[i] as Map<String, dynamic>;
      final label = (p['label'] ?? labels[i]).toString();
      final pc = (p['compute'] as Map?) ?? const {};
      for (final entry in pc.entries) {
        try {
          penv[entry.key as String] = _ev(entry.value, penv);
        } on ExprError {
          return null;
        }
      }
      final key = _partKey(p, penv);
      if (key == null) return null;
      final lines = <Map<String, Object?>>[];
      for (final lnRaw in (p['lines'] as List?) ?? const []) {
        final ln = lnRaw as Map;
        final rendered = <String, Object?>{};
        ln.forEach((k, v) {
          if (v is String) {
            rendered[k as String] = _render(v, penv);
          } else if (v is List) {
            rendered[k as String] = v.map((x) => x is String ? _render(x, penv) : x).toList();
          } else {
            rendered[k as String] = v;
          }
        });
        lines.add(rendered);
      }
      final rb = _partRubric(lines, 'الجزء $label', key.text);
      if (rb.steps.isEmpty) return null;
      final options = _partOptions(p, penv, key.text, key.val);
      if (key.val == null && options.isEmpty) return null;
      final ans = (p['answer'] as Map?) ?? const {};
      parts.add({
        'n': i + 1,
        'label': label,
        'prompt': _render((p['ask'] as String?) ?? '', penv),
        'weight': rb.weight,
        'rubric': rb.steps,
        'options': options,
        'answerText': key.text,
        'answerValue': key.val,
        'answerUnit': key.unit,
        'unitRequired': (ans['unit_required'] as bool?) ?? true,
        '_followRaw': p['follow'],
      });
      weight += rb.weight;
    }
    // متابعة الخطأ
    final followThrough = <Map<String, Object?>>[];
    for (final p in parts) {
      final fl = p['_followRaw'];
      if (fl == null) continue;
      final flm = fl as Map;
      final dep = parts.firstWhere(
        (q) => q['label'].toString() == flm['depends_on'].toString() || q['n'] == flm['depends_on'],
        orElse: () => const {},
      );
      if (dep.isEmpty || dep['answerValue'] == null || p['answerValue'] == null) return null;
      final specs = flm.containsKey('power')
          ? [flm]
          : [flm, ...((flm['also'] as List?) ?? const [])];
      final acc = <Map<String, Object?>>[];
      final dbase = (dep['answerValue'] as num).toDouble();
      for (final specRaw in specs) {
        final spec = specRaw as Map;
        final power = (spec['power'] as num).toDouble();
        final vv = (spec['value'] != null)
            ? (spec['value'] as num).toDouble()
            : (p['answerValue'] as num).toDouble();
        if (dbase <= 0 && power != power.truncateToDouble()) return null;
        double scale;
        try {
          scale = vv / math.pow(dbase, power);
        } catch (_) {
          return null;
        }
        if (!scale.isFinite || scale == 0) return null;
        acc.add({'dependsOn': dep['label'], 'power': power, 'scale': scale});
      }
      if (acc.isEmpty) return null;
      followThrough.add({'part': p['label'], 'accept': acc});
    }
    for (final p in parts) {
      p.remove('_followRaw');
    }
    return {
      'stem': stem,
      'weight': weight,
      'parts': parts,
      'followThrough': followThrough,
    };
  }
}

class _Key {
  _Key(this.text, this.val, this.unit);
  final String text;
  final double? val;
  final String unit;
}

class _Rubric {
  _Rubric(this.steps, this.weight);
  final List<Map<String, Object?>> steps;
  final num weight;
}

class _Dist {
  _Dist(this.txt, this.val);
  final String txt;
  final double? val;
}
