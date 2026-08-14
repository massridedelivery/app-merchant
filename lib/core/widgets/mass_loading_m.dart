import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Brand loading indicator: the MassRide **M** filling left-to-right.
///
/// A faint outline of the M is always visible; red "liquid" with a rippling
/// edge sweeps across it on a seamless loop. Plain M (no wing). Pure vector —
/// crisp at any [size], no asset. Swap [color]/[emptyColor]/[duration] freely.
class MassLoadingM extends StatefulWidget {
  const MassLoadingM({
    super.key,
    this.size = 96,
    this.color = const Color(0xFFB4312E),
    this.emptyColor,
    this.duration = const Duration(milliseconds: 2000),
  });

  final double size;
  final Color color;

  /// The unfilled M. Defaults to [color] at 22% opacity.
  final Color? emptyColor;
  final Duration duration;

  @override
  State<MassLoadingM> createState() => _MassLoadingMState();
}

class _MassLoadingMState extends State<MassLoadingM>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.emptyColor ?? widget.color.withValues(alpha: 0.22);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _MPainter(t: _c.value, color: widget.color, empty: empty),
          ),
        ),
      ),
    );
  }
}

class _MPainter extends CustomPainter {
  _MPainter({required this.t, required this.color, required this.empty});

  final double t; // 0..1 loop position
  final Color color;
  final Color empty;

  static const double _vb = 1024; // design viewBox
  static const double _stroke = 104;
  static const double _leftX = 280;
  static const double _rightX = 744;

  // Plain M (no wing): bottom-left → top-left → middle dip → top-right → bottom-right.
  Path get _m => Path()
    ..moveTo(280, 770)
    ..lineTo(298, 198)
    ..lineTo(512, 528)
    ..lineTo(738, 192)
    ..lineTo(744, 770);

  Paint _strokePaint(Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..color = c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _vb, size.height / _vb);

    // 1) The empty M, always visible.
    canvas.drawPath(_m, _strokePaint(empty));

    // 2) The filled M, but clipped to the wavy "liquid" region that sweeps
    //    left→right — so only the submerged part of the M shows the full colour.
    final progress = (1 - math.cos(2 * math.pi * t)) / 2; // seamless breathing
    final level = _leftX - 70 + (_rightX - _leftX + 140) * progress;
    final phase = t * 2 * math.pi;
    final region = Path()..moveTo(-40, -40);
    for (double y = -40; y <= _vb + 40; y += 8) {
      region.lineTo(level + 16 * math.sin(y / 55 + phase), y);
    }
    region
      ..lineTo(-40, _vb + 40)
      ..close();

    canvas.save();
    canvas.clipPath(region);
    canvas.drawPath(_m, _strokePaint(color));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MPainter old) =>
      old.t != t || old.color != color || old.empty != empty;
}
