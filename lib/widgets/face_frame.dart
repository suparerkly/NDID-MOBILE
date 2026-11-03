import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// กรอบใบหน้ารูปวงรี มีเส้นบอกความคืบหน้ารอบกรอบและแถบสแกนเคลื่อนขึ้นลง
class FaceFrame extends StatefulWidget {
  const FaceFrame({
    super.key,
    required this.progress,
    required this.scanning,
    required this.child,
  });

  final double progress;
  final bool scanning;
  final Widget child;

  @override
  State<FaceFrame> createState() => _FaceFrameState();
}

class _FaceFrameState extends State<FaceFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  void _syncScan() {
    final shouldRun =
        widget.scanning && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun && !_scan.isAnimating) {
      _scan.repeat(reverse: true);
    } else if (!shouldRun && _scan.isAnimating) {
      _scan.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncScan();
  }

  @override
  void didUpdateWidget(FaceFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncScan();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.progress),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => CustomPaint(
        foregroundPainter: _RingPainter(value),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: AppColors.field, child: widget.child),
              if (widget.scanning && !MediaQuery.disableAnimationsOf(context))
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scan,
                    builder: (context, child) => Align(
                      alignment: Alignment(
                        0,
                        -1 + 2 * Curves.easeInOut.transform(_scan.value),
                      ),
                      child: child,
                    ),
                    child: const _ScanBand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanBand extends StatelessWidget {
  const _ScanBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0x73FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(rect, paint..color = AppColors.line);
    if (progress <= 0) return;

    final doneness = ((progress - 0.9) / 0.1).clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint..color = Color.lerp(AppColors.accent, AppColors.success, doneness)!,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// บอกว่าตอนนี้อยู่ขั้นไหนของการตรวจใบหน้า
class LivenessSteps extends StatelessWidget {
  const LivenessSteps({super.key, required this.current});

  static const _labels = ['จัดใบหน้า', 'กะพริบตา', 'หันหน้า'];

  /// จำนวนขั้นที่ผ่านแล้ว
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: _StepDot(
              label: _labels[i],
              done: i < current,
              active: i == current,
            ),
          ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 250);
    return Column(
      children: [
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.accent : AppColors.surface,
            border: Border.all(
              color: done || active ? AppColors.accent : AppColors.line,
              width: active ? 2 : 1.5,
            ),
          ),
          child: AnimatedScale(
            scale: done ? 1 : 0,
            duration: duration,
            curve: Curves.easeOutBack,
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: duration,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: done || active ? AppColors.ink : AppColors.muted,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
          child: Text(label),
        ),
      ],
    );
  }
}
