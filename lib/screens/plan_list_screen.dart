import 'package:flutter/material.dart';

import '../models/insurance.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'purchase_screen.dart';

class PlanListScreen extends StatefulWidget {
  const PlanListScreen({super.key});

  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  late Future<List<InsurancePlan>> _plans = _load();
  String? _expandedId;
  bool _expandedSet = false;

  Future<List<InsurancePlan>> _load() =>
      AppStateScope.read(context).loadPlans();

  void _retry() {
    setState(() {
      _plans = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final age = AppStateScope.of(context).profile?.ageOn(DateTime.now());
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เลือกแบบประกัน',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              FutureBuilder(
                future: _plans,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _LoadError(error: snapshot.error!, onRetry: _retry);
                  }
                  final plans = snapshot.data;
                  if (plans == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    );
                  }
                  // กางแบบแรกไว้ตั้งแต่เปิดหน้า
                  if (!_expandedSet) {
                    _expandedSet = true;
                    _expandedId = plans.firstOrNull?.id;
                  }
                  return _PlanList(
                    plans: plans,
                    age: age,
                    expandedId: _expandedId,
                    onToggle: (id) => setState(
                      () => _expandedId = _expandedId == id ? null : id,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({
    required this.plans,
    required this.age,
    required this.expandedId,
    required this.onToggle,
  });

  final List<InsurancePlan> plans;
  final int? age;
  final String? expandedId;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < plans.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              index: i + 1,
              child: _PlanCard(
                plan: plans[i],
                age: age,
                expanded: plans[i].id == expandedId,
                onToggle: () => onToggle(plans[i].id),
              ),
            ),
          ),
        const SizedBox(height: 6),
        FadeSlideIn(
          index: plans.length + 1,
          child: const SimulationBanner(
            text: 'แบบประกันทั้งหมดเป็นตัวอย่าง ไม่ใช่ผลิตภัณฑ์ที่เสนอขายจริง',
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'โหลดแบบประกันไม่สำเร็จ';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.age,
    required this.expanded,
    required this.onToggle,
  });

  final InsurancePlan plan;
  final int? age;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligible = age != null && plan.acceptsAge(age!);
    return OutlinedPanel(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(plan.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: theme.textTheme.titleMedium),
                    Text(
                      '${formatBaht(plan.yearlyPremium)} ต่อปี',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.accent),
                    ),
                    if (!eligible)
                      Text(
                        'อายุไม่อยู่ในเกณฑ์รับประกัน',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _PlanDetails(plan: plan, eligible: eligible)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.plan, required this.eligible});

  final InsurancePlan plan;
  final bool eligible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          for (final benefit in plan.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.check, size: 16, color: AppColors.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(benefit, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'รับประกันอายุ ${plan.minAge}-${plan.maxAge} ปี',
            style: theme.textTheme.bodySmall,
          ),
          if (eligible) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PurchaseScreen(plan: plan),
                ),
              ),
              child: const Text('ซื้อแบบนี้'),
            ),
          ],
        ],
      ),
    );
  }
}
