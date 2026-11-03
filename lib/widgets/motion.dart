import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// ค่อย ๆ ปรากฏพร้อมเลื่อนขึ้น [index] ใช้ไล่จังหวะของรายการในหน้าเดียวกัน
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, this.index = 0, required this.child});

  static const _step = 60;
  static const _duration = 420;

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final delay = widget.index * FadeSlideIn._step;
    final total = delay + FadeSlideIn._duration;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// ย่อลงเล็กน้อยขณะกด โดยไม่แย่ง gesture จาก widget ข้างใน
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// วงกลมเด้งขึ้น แล้วขีดเครื่องหมายถูก
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({super.key, this.size = 72});

  final double size;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _CheckPainter(_controller)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.animation) : super(repaint: animation);

  static const _circle = Interval(0, 0.55, curve: Curves.easeOutBack);
  static const _stroke = Interval(0.4, 1, curve: Curves.easeInOutCubic);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = max(0.0, _circle.transform(animation.value));
    canvas.drawCircle(
      center,
      size.width / 2 * scale,
      Paint()..color = AppColors.success,
    );

    final progress = _stroke.transform(animation.value);
    if (progress == 0) return;

    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metrics = path.computeMetrics().toList();
    final drawn = Path();
    var remaining =
        metrics.fold<double>(0, (sum, m) => sum + m.length) * progress;
    for (final PathMetric metric in metrics) {
      drawn.addPath(
          metric.extractPath(0, min(remaining, metric.length)), Offset.zero);
      remaining -= metric.length;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

/// dialog ที่ปรากฏด้วยการจางเข้าและขยายเล็กน้อย
Future<T?> showSoftDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000),
    transitionDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
    pageBuilder: (context, _, __) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: curved.drive(Tween(begin: 0.94, end: 1)),
          child: child,
        ),
      );
    },
  );
}
