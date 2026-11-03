import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import 'motion.dart';

final _baht = NumberFormat('#,##0');

String formatBaht(int amount) => '${_baht.format(amount)} บาท';

/// วันที่แบบไทย ปี พ.ศ. เช่น 1/11/2569
String formatThaiDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year + 543}';

/// แถบเตือนให้รู้ว่าเป็นแอปจำลอง แสดงบนหน้าที่เกี่ยวกับการยืนยันตัวตนและการชำระเงิน
class SimulationBanner extends StatelessWidget {
  const SimulationBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(appRadius - 4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 16, color: AppColors.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// ลำดับขั้นตอนการยืนยันตัวตน แถบของขั้นปัจจุบันจะค่อย ๆ เติมเต็ม
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.current, required this.title});

  static const total = 3;

  final int current;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(child: _StepSegment(state: i - current)),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text('ขั้นตอนที่ $current จาก $total',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(title, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

class _StepSegment extends StatelessWidget {
  const _StepSegment({required this.state});

  /// น้อยกว่า 0 คือผ่านแล้ว, 0 คือขั้นปัจจุบัน, มากกว่า 0 คือยังไม่ถึง
  final int state;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: ColoredBox(
          color: AppColors.line,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: state == 0 && !reduceMotion ? 0 : 1,
              end: state <= 0 ? 1 : 0,
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: const ColoredBox(color: AppColors.accent),
            ),
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// ไอคอนบนพื้นสีอ่อน
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(appRadius - 4),
      ),
      child: Icon(icon, size: 22, color: AppColors.accent),
    );
  }
}

/// พื้นผิวที่มีเส้นขอบบาง ๆ และกดได้
class OutlinedPanel extends StatelessWidget {
  const OutlinedPanel({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(appRadius);
    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSoft : AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? panel : PressScale(child: panel);
  }
}

/// แถวสำหรับเปิดหน้าถัดไป
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedPanel(
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// ตัวเลือกแบบเลือกได้หนึ่งอย่าง
class SelectTile extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: OutlinedPanel(
        selected: selected,
        onTap: onTap,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: selected ? AppColors.accent : AppColors.muted),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.line,
                  width: selected ? 7 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
