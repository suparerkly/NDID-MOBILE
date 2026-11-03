import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'personal_info_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _consented = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const FadeSlideIn(
                        child: IconBadge(Icons.verified_user_outlined),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        index: 1,
                        child: Text(
                          'ยืนยันตัวตนแบบ NDID',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeSlideIn(
                        index: 2,
                        child: Text(
                          'แล้วซื้อประกันออนไลน์ได้ในไม่กี่ขั้นตอน',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 36),
                      const FadeSlideIn(
                        index: 3,
                        child: _StepRow(
                          number: 1,
                          title: 'กรอกข้อมูลส่วนตัว',
                          subtitle: 'ใช้ข้อมูลทดสอบได้ ไม่ต้องใช้ข้อมูลจริง',
                        ),
                      ),
                      const FadeSlideIn(
                        index: 4,
                        child: _StepRow(
                          number: 2,
                          title: 'เลือกผู้ให้บริการยืนยันตัวตน',
                          subtitle: 'เลือกธนาคารสมมติที่จะยืนยันตัวตนให้',
                        ),
                      ),
                      const FadeSlideIn(
                        index: 5,
                        child: _StepRow(
                          number: 3,
                          title: 'ตรวจสอบใบหน้าผ่านกล้อง',
                          subtitle:
                              'ประมวลผลบนเครื่อง ไม่บันทึกและไม่ส่งภาพออกไป',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const FadeSlideIn(
                        index: 6,
                        child: SimulationBanner(
                          text: 'แอปนี้เป็นการจำลองเพื่อสาธิตเท่านั้น '
                              'ไม่ได้เชื่อมต่อกับระบบ NDID จริง ไม่มีการตัดเงินและไม่ออกกรมธรรม์จริง',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                index: 7,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consented,
                  onChanged: (value) =>
                      setState(() => _consented = value ?? false),
                  title: Text(
                    'ฉันเข้าใจว่านี่เป็นการจำลอง และยินยอมให้ใช้กล้องเพื่อตรวจสอบใบหน้า',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                index: 8,
                child: FilledButton(
                  onPressed: _consented
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PersonalInfoScreen(),
                            ),
                          )
                      : null,
                  child: const Text('เริ่มยืนยันตัวตน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
