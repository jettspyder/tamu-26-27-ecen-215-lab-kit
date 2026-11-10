import 'package:flutter/material.dart';

import '../kit/kit_service.dart';
import '../labs/lab_model.dart';
import '../theme.dart';

// Wiring diagrams drawn in code, so they stay sharp on every screen size.
// Each painter draws in a fixed design grid (e.g. 330 × 244) and scales to fit.

const _wireGrey = Color(0xFF8C8C96);
const _bodyTan = Color(0xFFE9D8B4);
const _kitBody = Color(0xFF2B2B30);
const _maroon = AppColors.maroon;

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _rrect(Canvas c, double x, double y, double w, double h, double r, Paint p) =>
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p);

enum _Anchor { start, middle, end }

/// Draws text with its baseline at [y], like SVG.
void _text(Canvas c, String s, double x, double y,
    {double size = 9, FontWeight weight = FontWeight.w400, Color color = Colors.white, _Anchor anchor = _Anchor.start}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: AppFonts.sans, fontSize: size, fontWeight: weight, color: color)),
    textDirection: TextDirection.ltr,
  )..layout();
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = anchor == _Anchor.start ? x : (anchor == _Anchor.middle ? x - tp.width / 2 : x - tp.width);
  tp.paint(c, Offset(dx, y - base));
}

/// Scales a fixed design grid to the available width, keeping its aspect ratio.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.w, required this.h, required this.painter, required this.label});

  final double w;
  final double h;
  final CustomPainter painter;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      child: AspectRatio(aspectRatio: w / h, child: CustomPaint(painter: painter)),
    );
  }
}

void _scale(Canvas canvas, Size size, double w) {
  final s = size.width / w;
  canvas.scale(s, s);
}

void _resistorVertical(Canvas c, double cx, double top, List<Color> bands) {
  _rrect(c, cx - 7, top, 14, 28, 5, _fill(_bodyTan));
  for (var i = 0; i < 3; i++) {
    c.drawRect(Rect.fromLTWH(cx - 7, top + 4 + i * 6, 14, 3), _fill(bands[i]));
  }
  c.drawRect(Rect.fromLTWH(cx - 7, top + 22, 14, 2), _fill(BandColors.gold));
}

void _photoIcon(Canvas c, double cx, double cy, double r) {
  c.drawCircle(Offset(cx, cy), r, _fill(const Color(0xFFE8C26A)));
  c.drawCircle(Offset(cx, cy), r, _stroke(const Color(0xFFB88A2E), 1.5));
  final k = r / 18;
  final p = Path()
    ..moveTo(cx - 12 * k, cy - 6 * k)
    ..relativeLineTo(6 * k, 0)
    ..relativeLineTo(0, 6 * k)
    ..relativeLineTo(6 * k, 0)
    ..relativeLineTo(0, -6 * k)
    ..relativeLineTo(6 * k, 0)
    ..relativeLineTo(0, 6 * k)
    ..relativeLineTo(6 * k, 0)
    ..moveTo(cx - 12 * k, cy + 6 * k)
    ..relativeLineTo(6 * k, 0);
  c.drawPath(p, _stroke(const Color(0xFF7A4E12), r < 12 ? 1.5 : 2.0));
}

void _whiteWire(Canvas c, Path p) {
  c.drawPath(p, _stroke(const Color(0xFF9A9AA5), 6));
  c.drawPath(p, _stroke(Colors.white, 4));
}

// ---------------------------------------------------------------------------
// Breadboard (rows 8–24, columns a–e) with the Lab Kit on the left.
// ---------------------------------------------------------------------------

class BreadboardDiagram extends StatelessWidget {
  const BreadboardDiagram(this.state, {super.key});
  final BoardState state;

  @override
  Widget build(BuildContext context) =>
      _Scaled(w: 330, h: 244, painter: _BreadboardPainter(state), label: 'Breadboard wiring diagram for this step');
}

class _BreadboardPainter extends CustomPainter {
  _BreadboardPainter(this.s);
  final BoardState s;

  static double rowY(int r) => 30.0 + (r - 8) * 12;

  @override
  void paint(Canvas c, Size size) {
    _scale(c, size, 330);

    // Board
    _rrect(c, 130, 6, 134, 232, 8, _fill(const Color(0xFFF1EFEA)));
    _rrect(c, 130, 6, 134, 232, 8, _stroke(const Color(0xFFD8D4CA), 1));

    // Highlighted rows
    for (final r in s.highlightRows) {
      _rrect(c, 157, rowY(r) - 6, 90, 12, 3, _fill(const Color(0x1F500000)));
    }

    // Holes
    final hole = _fill(const Color(0xFFB5B0A4));
    for (var row = 0; row < 17; row++) {
      for (var col = 0; col < 5; col++) {
        _rrect(c, 157.0 + col * 18 + 7, 24.0 + row * 12 + 4, 4, 4, 1, hole);
      }
    }
    const letters = ['a', 'b', 'c', 'd', 'e'];
    for (var i = 0; i < 5; i++) {
      _text(c, letters[i], 166.0 + i * 18, 19, color: AppColors.muted, anchor: _Anchor.middle);
    }
    for (var r = 8; r <= 24; r++) {
      final key = r == 10 || r == 15 || r == 22;
      _text(c, '$r', key ? 150.0 : 148.0, rowY(r) + 3,
          size: key ? 10.0 : 8.0,
          weight: key ? FontWeight.w700 : FontWeight.w400,
          color: key ? AppColors.text : AppColors.faint,
          anchor: _Anchor.end);
    }

    // Lab Kit
    _rrect(c, 6, 40, 80, 170, 10, _fill(_kitBody));
    _text(c, 'LAB KIT', 46, 60, size: 10, weight: FontWeight.w700, anchor: _Anchor.middle);
    _text(c, '5 V', 80, 88, anchor: _Anchor.end);
    _text(c, 'GND', 80, 118, anchor: _Anchor.end);
    _text(c, 'METER +', 80, 158, anchor: _Anchor.end);
    _text(c, 'METER −', 80, 188, anchor: _Anchor.end);
    _rrect(c, 84, 80, 8, 10, 2, _fill(WireColor.red.fill));
    _rrect(c, 84, 110, 8, 10, 2, _fill(WireColor.black.fill));
    _rrect(c, 84, 150, 8, 10, 2, _fill(WireColor.blue.fill));
    _rrect(c, 84, 180, 8, 10, 2, _fill(Colors.white));
    _rrect(c, 84, 180, 8, 10, 2, _stroke(const Color(0xFF9A9AA5), 1));

    // R1 (rows 10–15, column b)
    final r1 = s.r1;
    if (r1 != null) {
      c.drawLine(const Offset(184, 54), const Offset(184, 114), _stroke(_wireGrey, 2));
      _resistorVertical(c, 184, 70, r1.bands);
      c.drawCircle(const Offset(184, 54), 3, _fill(_wireGrey));
      c.drawCircle(const Offset(184, 114), 3, _fill(_wireGrey));
      _text(c, r1 == PartKind.r10k ? '10 kΩ' : 'R1', 194, 76, weight: FontWeight.w700, color: _maroon);
    }

    // R2 (rows 15–22, column c)
    final r2 = s.r2;
    if (r2 != null) {
      c.drawLine(const Offset(202, 114), const Offset(202, 198), _stroke(_wireGrey, 2));
      c.drawCircle(const Offset(202, 114), 3, _fill(_wireGrey));
      c.drawCircle(const Offset(202, 198), 3, _fill(_wireGrey));
      if (r2.isResistor) {
        _resistorVertical(c, 202, 142, r2.bands);
      } else if (r2 == PartKind.photo) {
        _photoIcon(c, 202, 156, 11);
      } else {
        c.drawCircle(const Offset(202, 156), 7, _fill(const Color(0xFF3B3B40)));
      }
      final label = r2 == PartKind.photo ? 'Photo' : (r2 == PartKind.therm ? 'Therm' : 'R2');
      _text(c, label, 214, 148, weight: FontWeight.w700, color: _maroon);
    }

    // Power wires
    if (s.power) {
      final red = Path()
        ..moveTo(92, 85)
        ..cubicTo(125, 85, 130, 54, 166, 54);
      c.drawPath(red, _stroke(WireColor.red.fill, 4));
      c.drawCircle(const Offset(166, 54), 4, _fill(WireColor.red.fill));
      final black = Path()
        ..moveTo(92, 115)
        ..cubicTo(130, 115, 130, 198, 166, 198);
      c.drawPath(black, _stroke(WireColor.black.fill, 4));
      c.drawCircle(const Offset(166, 198), 4, _fill(WireColor.black.fill));
    }

    // Meter probes (column e)
    final probe = s.probeRows;
    if (probe != null && probe.length == 2) {
      final ya = rowY(probe[0]), yb = rowY(probe[1]);
      final blue = Path()
        ..moveTo(92, 155)
        ..cubicTo(200, 155, 205, ya, 238, ya);
      c.drawPath(blue, _stroke(WireColor.blue.fill, 4));
      c.drawCircle(Offset(238, ya), 4, _fill(WireColor.blue.fill));
      final white = Path()
        ..moveTo(92, 185)
        ..cubicTo(215, 185, 215, yb, 238, yb);
      _whiteWire(c, white);
      c.drawCircle(Offset(238, yb), 4, _fill(Colors.white));
      c.drawCircle(Offset(238, yb), 4, _stroke(const Color(0xFF9A9AA5), 1.5));
    }
  }

  @override
  bool shouldRepaint(covariant _BreadboardPainter old) => old.s != s;
}

// ---------------------------------------------------------------------------
// A single part with the meter wires clipped to its legs.
// ---------------------------------------------------------------------------

class LoosePartDiagram extends StatelessWidget {
  const LoosePartDiagram(this.part, {super.key});
  final LoosePart part;

  @override
  Widget build(BuildContext context) => _Scaled(
        w: 330,
        h: 150,
        painter: _LoosePainter(part),
        label: 'Blue and white meter wires clipped to the legs of the ${part.label}',
      );
}

class _LoosePainter extends CustomPainter {
  _LoosePainter(this.p);
  final LoosePart p;

  @override
  void paint(Canvas c, Size size) {
    _scale(c, size, 330);
    _rrect(c, 6, 30, 78, 90, 10, _fill(_kitBody));
    _text(c, 'LAB KIT', 45, 50, size: 10, weight: FontWeight.w700, anchor: _Anchor.middle);
    _text(c, 'METER +', 76, 78, anchor: _Anchor.end);
    _text(c, 'METER −', 76, 104, anchor: _Anchor.end);
    _rrect(c, 82, 70, 8, 10, 2, _fill(WireColor.blue.fill));
    _rrect(c, 82, 96, 8, 10, 2, _fill(Colors.white));
    _rrect(c, 82, 96, 8, 10, 2, _stroke(const Color(0xFF9A9AA5), 1));

    c.drawLine(const Offset(90, 75), const Offset(190, 75), _stroke(WireColor.blue.fill, 4));
    final white = Path()
      ..moveTo(90, 101)
      ..cubicTo(220, 101, 270, 101, 290, 82);
    _whiteWire(c, white);

    c.drawLine(const Offset(180, 75), const Offset(300, 75), _stroke(_wireGrey, 2.5));
    _rrect(c, 184, 68, 14, 14, 3, _fill(WireColor.blue.fill));
    _rrect(c, 282, 68, 14, 14, 3, _fill(Colors.white));
    _rrect(c, 282, 68, 14, 14, 3, _stroke(const Color(0xFF9A9AA5), 1.5));

    final k = p.kind;
    if (k.isResistor) {
      _rrect(c, 214, 63, 52, 24, 8, _fill(_bodyTan));
      for (var i = 0; i < 3; i++) {
        c.drawRect(Rect.fromLTWH(222.0 + i * 10, 63, 5, 24), _fill(k.bands[i]));
      }
      c.drawRect(const Rect.fromLTWH(255, 63, 4, 24), _fill(BandColors.gold));
    } else if (k == PartKind.photo) {
      _photoIcon(c, 240, 75, 18);
    } else {
      c.drawCircle(const Offset(240, 75), 10, _fill(const Color(0xFF3B3B40)));
    }
    _text(c, p.label, 240, 125, size: 12, weight: FontWeight.w600, color: AppColors.text, anchor: _Anchor.middle);
  }

  @override
  bool shouldRepaint(covariant _LoosePainter old) => old.p != p;
}

// ---------------------------------------------------------------------------
// Figure 1.1d schematic with breadboard row tags.
// ---------------------------------------------------------------------------

class DividerSchematic extends StatelessWidget {
  const DividerSchematic({super.key});

  @override
  Widget build(BuildContext context) => _Scaled(
        w: 330,
        h: 200,
        painter: _SchematicPainter(),
        label: 'Schematic: 5 volt source, R1 100 ohm in series with R2 220 ohm',
      );
}

class _SchematicPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    _scale(c, size, 330);
    final wire = _stroke(AppColors.text, 2)..strokeCap = StrokeCap.butt;
    final wires = Path()
      ..moveTo(60, 40)
      ..lineTo(130, 40)
      ..moveTo(210, 40)
      ..lineTo(280, 40)
      ..lineTo(280, 75)
      ..moveTo(280, 135)
      ..lineTo(280, 170)
      ..lineTo(60, 170)
      ..lineTo(60, 108)
      ..moveTo(60, 98)
      ..lineTo(60, 40);
    c.drawPath(wires, wire);

    final res = _stroke(_maroon, 2.4);
    final r1 = Path()..moveTo(130, 40);
    r1.relativeLineTo(5, -8);
    for (var i = 0; i < 7; i++) {
      r1.relativeLineTo(10, i.isEven ? 16.0 : -16.0);
    }
    r1.relativeLineTo(5, -8);
    c.drawPath(r1, res);

    final r2 = Path()..moveTo(280, 75);
    r2.relativeLineTo(8, 5);
    for (var i = 0; i < 5; i++) {
      r2.relativeLineTo(i.isEven ? -16.0 : 16.0, 10);
    }
    r2.relativeLineTo(8, 5);
    c.drawPath(r2, res);

    final cell = _stroke(AppColors.text, 3)..strokeCap = StrokeCap.butt;
    c.drawLine(const Offset(44, 98), const Offset(76, 98), cell);
    c.drawLine(const Offset(52, 108), const Offset(68, 108), cell);

    _text(c, '+', 80, 94, size: 12, color: AppColors.text);
    _text(c, '5 V', 12, 108, size: 13, weight: FontWeight.w700, color: AppColors.text);
    _text(c, 'R1 · 100 Ω', 170, 22, size: 12, weight: FontWeight.w700, color: _maroon, anchor: _Anchor.middle);
    _text(c, '+  V1  −', 170, 66, size: 12, color: AppColors.text, anchor: _Anchor.middle);
    _text(c, 'R2', 298, 102, size: 12, weight: FontWeight.w700, color: _maroon);
    _text(c, '220 Ω', 298, 117, size: 12, weight: FontWeight.w700, color: _maroon);
    _text(c, 'V2', 262, 110, size: 12, color: AppColors.text, anchor: _Anchor.end);

    void tag(double x, double y, String label) {
      _rrect(c, x, y, 46, 16, 8, _fill(AppColors.divider));
      _text(c, label, x + 23, y + 11, size: 9, weight: FontWeight.w600, color: AppColors.text2, anchor: _Anchor.middle);
    }

    tag(70, 26, 'row 10');
    tag(222, 26, 'row 15');
    tag(147, 176, 'row 22');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Small resistor icon for the parts list.
// ---------------------------------------------------------------------------

class ResistorIcon extends StatelessWidget {
  const ResistorIcon(this.kind, {super.key});
  final PartKind kind;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 54, height: 20, child: CustomPaint(painter: _ResistorIconPainter(kind)));
}

class _ResistorIconPainter extends CustomPainter {
  _ResistorIconPainter(this.k);
  final PartKind k;

  @override
  void paint(Canvas c, Size size) {
    c.drawLine(const Offset(0, 10), const Offset(54, 10), _stroke(const Color(0xFF9A9AA5), 2)..strokeCap = StrokeCap.butt);
    _rrect(c, 13, 3, 28, 14, 5, _fill(_bodyTan));
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(17.0 + i * 6, 3, 3, 14), _fill(k.bands[i]));
    }
    c.drawRect(const Rect.fromLTWH(36, 3, 2, 14), _fill(BandColors.gold));
  }

  @override
  bool shouldRepaint(covariant _ResistorIconPainter old) => old.k != k;
}

// ---------------------------------------------------------------------------
// Simulated scope traces.
// ---------------------------------------------------------------------------

class ScopeTrace extends StatelessWidget {
  const ScopeTrace({super.key});

  @override
  Widget build(BuildContext context) => const _Scaled(
        w: 320,
        h: 200,
        painter: _ScopePainter(),
        label: 'Simulated scope: square wave on channel 2, RC charging curve on channel 1',
      );
}

class _ScopePainter extends CustomPainter {
  const _ScopePainter();

  @override
  void paint(Canvas c, Size size) {
    _scale(c, size, 320);
    c.drawRect(const Rect.fromLTWH(0, 0, 320, 200), _fill(const Color(0xFFFAFAFB)));
    final grid = _stroke(AppColors.border, 1)..strokeCap = StrokeCap.butt;
    for (final y in [50.0, 100.0, 150.0]) {
      c.drawLine(Offset(0, y), Offset(320, y), grid);
    }
    for (final x in [64.0, 128.0, 192.0, 256.0]) {
      c.drawLine(Offset(x, 0), Offset(x, 200), grid);
    }
    var y = 160.0;
    final sq = Path()..moveTo(0, y);
    for (var i = 1; i <= 8; i++) {
      final x = 40.0 * i;
      sq.lineTo(x, y);
      if (i < 8) {
        y = y == 160 ? 40.0 : 160.0;
        sq.lineTo(x, y);
      }
    }
    c.drawPath(sq, _stroke(const Color(0xFF2563EB), 1.8)..strokeJoin = StrokeJoin.miter);

    final rc = Path()..moveTo(0, 150);
    for (var i = 0; i < 4; i++) {
      final x0 = 80.0 * i;
      rc.cubicTo(x0 + 10, 90, x0 + 25, 64, x0 + 40, 58);
      rc.cubicTo(x0 + 50, 110, x0 + 65, 140, x0 + 80, 146);
    }
    c.drawPath(rc, _stroke(_maroon, 2.2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Little wave-shape icon for the wave gen buttons.
class WaveIcon extends StatelessWidget {
  const WaveIcon(this.shape, {super.key, required this.color});
  final WaveShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 44, height: 24, child: CustomPaint(painter: _WaveIconPainter(shape, color)));
}

class _WaveIconPainter extends CustomPainter {
  _WaveIconPainter(this.shape, this.color);
  final WaveShape shape;
  final Color color;

  @override
  void paint(Canvas c, Size size) {
    final sx = size.width / 24, sy = size.height / 24;
    Offset o(double x, double y) => Offset(x * sx, y * sy);
    final p = Path();
    switch (shape) {
      case WaveShape.sine:
        p
          ..moveTo(o(2, 12).dx, o(2, 12).dy)
          ..cubicTo(o(5, 2).dx, o(5, 2).dy, o(9, 2).dx, o(9, 2).dy, o(12, 12).dx, o(12, 12).dy)
          ..cubicTo(o(15, 22).dx, o(15, 22).dy, o(19, 22).dx, o(19, 22).dy, o(22, 12).dx, o(22, 12).dy);
      case WaveShape.square:
        final pts = [o(2, 17), o(2, 7), o(7, 7), o(7, 17), o(12, 17), o(12, 7), o(17, 7), o(17, 17), o(22, 17)];
        p.moveTo(pts.first.dx, pts.first.dy);
        for (final q in pts.skip(1)) {
          p.lineTo(q.dx, q.dy);
        }
      case WaveShape.triangle:
        final pts = [o(2, 17), o(7, 7), o(12, 17), o(17, 7), o(22, 17)];
        p.moveTo(pts.first.dx, pts.first.dy);
        for (final q in pts.skip(1)) {
          p.lineTo(q.dx, q.dy);
        }
    }
    c.drawPath(p, _stroke(color, 2));
  }

  @override
  bool shouldRepaint(covariant _WaveIconPainter old) => old.shape != shape || old.color != color;
}
