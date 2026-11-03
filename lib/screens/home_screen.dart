import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'plan_list_screen.dart';
import 'policy_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _signOut(BuildContext context) {
    AppStateScope.of(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final profile = state.profile;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout, size: 22, color: AppColors.muted),
            onPressed: () => _signOut(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile != null) ...[
                FadeSlideIn(
                  child: Text(
                    'สวัสดี ${profile.firstName}',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                const FadeSlideIn(index: 1, child: _VerifiedLabel()),
                const SizedBox(height: 36),
              ],
              FadeSlideIn(
                index: 2,
                child: Text('ทำธุรกรรม', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 3,
                child: NavTile(
                  icon: Icons.shield_outlined,
                  title: 'ซื้อประกันออนไลน์',
                  subtitle: 'เลือกแบบประกันและชำระเบี้ยแบบจำลอง',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlanListScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                index: 4,
                child: NavTile(
                  icon: Icons.description_outlined,
                  title: 'กรมธรรม์ของฉัน',
                  subtitle: '${state.policies.length} ฉบับ',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PolicyListScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedLabel extends StatelessWidget {
  const _VerifiedLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified, size: 18, color: AppColors.success),
        const SizedBox(width: 6),
        Text(
          'ยืนยันตัวตนแล้ว (จำลอง)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
