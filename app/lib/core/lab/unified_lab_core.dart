import 'dart:math' as math;

import 'package:flutter/material.dart';

/// النواة المشتركة للنمط الموحّد المعتمد (2026-10-02): فيزياء واحدة ورسّامان.
/// فضاء كوني (#0C1017→#05070B + نجوم حتمية seed=7) + طاولة جوز داكن +
/// كاميرا مدارية orbit (سحب يدوّر، العجلة/القرص يقرّب) + project3 المشترك.
/// المرجع البصري: docs/prototypes/flash-*.html.
class P3 {
  const P3(this.x, this.y, this.z);
  final double x, y, z;
}

class Proj {
  const Proj(this.x, this.y, this.s, this.z);
  final double x, y, s, z;
}

class OrbitCam {
  OrbitCam({
    this.yaw = -0.5,
    this.pitch = 0.3,
    this.dist = 620,
    this.fov = 620,
  });
  double yaw, pitch, dist, fov;

  Proj project(P3 p, Size size) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final x = p.x * cy + p.z * sy;
    final z = -p.x * sy + p.z * cy;
    final y = p.y;
    final y2 = y * cp - z * sp;
    final z2 = y * sp + z * cp;
    final dz = z2 + dist;
    final s = fov / dz;
    return Proj(size.width / 2 + x * s, size.height * 0.475 - y2 * s, s, dz);
  }
}

class Star {
  const Star(this.dx, this.dy, this.r, this.a);
  final double dx, dy, r, a;
}

/// نجوم حتمية — نفس LCG (seed=7) المستعمل بالنماذج المعتمدة.
List<Star> makeStars({int n = 95, int seed = 7}) {
  int s = seed;
  int rnd() {
    s = (s * 16807) % 2147483647;
    return s;
  }

  final out = <Star>[];
  for (var i = 0; i < n; i++) {
    out.add(Star(
      rnd() / 2147483647,
      rnd() / 2147483647 * 0.72,
      0.5 + rnd() / 2147483647 * 1.1,
      0.10 + rnd() / 2147483647 * 0.45,
    ));
  }
  return out;
}

const Color kSpaceTop = Color(0xFF0C1017);
const Color kSpaceBot = Color(0xFF05070B);
const Color kWalnut1 = Color(0xFF2E2114);
const Color kWalnut2 = Color(0xFF160F08);
const Color kWalnutEdge = Color(0x1FFFD696);
const Color kGlow = Color(0xFFF0964A);
const Color kBeamGreen = Color(0xFF78FFBE);
const Color kBrass = Color(0xFFC89A5A);
const Color kInkLight = Color(0xFFE8E2D0);

/// خلفية الفضاء الكوني للوحة واقعية كاملة (علوية فقط عند groundTop>0).
void paintSpace(Canvas c, Size size, List<Star> stars, {double? groundTop}) {
  final h = groundTop ?? size.height;
  final g = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kSpaceTop, kSpaceBot],
    ).createShader(Rect.fromLTWH(0, 0, size.width, h));
  c.drawRect(Rect.fromLTWH(0, 0, size.width, h), g);
  for (final st in stars) {
    c.drawCircle(Offset(st.dx * size.width, st.dy * h), st.r,
        Paint()..color = Color.fromRGBO(226, 232, 240, st.a));
  }
}

/// شريط أزرق خافت تحت الحائط + طاولة جوز داكن بحافة دافئة وعروق.
void paintWalnutTable(Canvas c, Size size, double tableTop) {
  c.drawRect(
      Rect.fromLTWH(0, tableTop - 20, size.width, 20),
      Paint()
        ..color = const Color.fromRGBO(160, 190, 255, 0.05));
  c.drawRect(Rect.fromLTWH(0, tableTop - 2, size.width, 2),
      Paint()..color = const Color(0x50000000));
  final g = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kWalnut1, kWalnut2],
    ).createShader(Rect.fromLTWH(0, tableTop, size.width, size.height - tableTop));
  c.drawRect(Rect.fromLTWH(0, tableTop, size.width, size.height - tableTop), g);
  c.drawRect(Rect.fromLTWH(0, tableTop, size.width, 2),
      Paint()..color = kWalnutEdge);
  final veins = Paint()
    ..color = const Color(0x12FFD696)
    ..strokeWidth = 1.1;
  for (var i = 0; i < 5; i++) {
    final y = tableTop + 13.0 + i * 19;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 90) {
      final yy = y + math.sin(x / 110 + i * 2.4) * 1.8;
      x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
    }
    c.drawPath(path, veins);
  }
}

void line3(Canvas c, OrbitCam cam, Size size, P3 a, P3 b, Color col, double w) {
  final pa = cam.project(a, size);
  final pb = cam.project(b, size);
  c.drawLine(
      Offset(pa.x, pa.y), Offset(pb.x, pb.y),
      Paint()
        ..color = col
        ..strokeWidth = math.max(0.4, w * (pa.s / cam.fov) * 434));
}

void stroke3(Canvas c, OrbitCam cam, Size size, List<P3> pts, Color col,
    double w, {bool close = false}) {
  final p = Paint()
    ..color = col
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final q = cam.project(pts[i], size);
    i == 0 ? path.moveTo(q.x, q.y) : path.lineTo(q.x, q.y);
  }
  if (close) path.close();
  c.drawPath(path, p);
}

/// حلقة بمستوى y-z عند إحداثي x (وشيعة/طوق).
void ring3(Canvas c, OrbitCam cam, Size size, double x, double r, Color col,
    double w) {
  final pts = <P3>[];
  for (var i = 0; i <= 40; i++) {
    final a = i / 40 * 2 * math.pi;
    pts.add(P3(x, math.cos(a) * r, math.sin(a) * r));
  }
  stroke3(c, cam, size, pts, col, w, close: true);
}

void paintGrid3(Canvas c, OrbitCam cam, Size size) {
  for (var x = -380.0; x <= 380; x += 76) {
    line3(c, cam, size, P3(x, -150, -300), P3(x, -150, 300),
        const Color(0x21CDD7E6), 1);
  }
  for (var z = -300.0; z <= 300; z += 75) {
    line3(c, cam, size, P3(-380, -150, z), P3(380, -150, z),
        const Color(0x21CDD7E6), 1);
  }
}

/// زر تبديل المنظور 🧊/🔬 المعتمد.
class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.view3d, required this.onChanged});
  final bool view3d;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onChanged(!view3d),
      icon: Text(view3d ? '🔬' : '🧊',
          style: const TextStyle(fontSize: 16)),
      label: Text(view3d ? 'المنظور الواقعي' : 'منظور 3D'),
      style: OutlinedButton.styleFrom(
        foregroundColor: view3d ? const Color(0xFFDD6E42) : null,
        side: BorderSide(
            color: view3d ? const Color(0xFFDD6E42) : Colors.white24),
      ),
    );
  }
}

/// صف منزلق مع تسمية وقيمة عربية.
class LabSlider extends StatelessWidget {
  const LabSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });
  final String label;
  final double value, min, max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label ',
          style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
      Text(display,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}

const List<String> kArabicDigits = [
  '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'
];

String toAr(Object s) => s
    .toString()
    .replaceAllMapped(RegExp(r'[0-9]'), (m) => kArabicDigits[int.parse(m[0]!)]);
