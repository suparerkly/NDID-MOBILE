import 'package:flutter/material.dart';

import '../models/insurance.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class PolicyListScreen extends StatelessWidget {
  const PolicyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final policies = AppStateScope.of(context).policies;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('กรมธรรม์ของฉัน', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              Expanded(
                child: policies.isEmpty
                    ? const FadeSlideIn(child: _EmptyPolicies())
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: policies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final policy = policies[index];
                          return FadeSlideIn(
                            index: index,
                            child: NavTile(
                              icon: policy.plan.icon,
                              title: policy.plan.name,
                              subtitle: 'เลขที่ ${policy.number}',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PolicyDetailScreen(policy: policy),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPolicies extends StatelessWidget {
  const _EmptyPolicies();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 40,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'ยังไม่มีกรมธรรม์',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class PolicyDetailScreen extends StatelessWidget {
  const PolicyDetailScreen({
    super.key,
    required this.policy,
    this.justPurchased = false,
  });

  final Policy policy;
  final bool justPurchased;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: !justPurchased),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (justPurchased) ...[
                const Center(child: AnimatedCheck()),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 4,
                  child: Text(
                    'ซื้อประกันสำเร็จ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ] else
                Text('รายละเอียดกรมธรรม์',
                    style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: justPurchased ? 6 : 1,
                child: OutlinedPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Column(
                    children: [
                      InfoRow('เลขที่กรมธรรม์', policy.number),
                      InfoRow('แบบประกัน', policy.plan.name),
                      InfoRow('ผู้เอาประกัน', policy.holderName),
                      InfoRow('ทุนประกัน', formatBaht(policy.plan.sumInsured)),
                      InfoRow(
                        'เบี้ยที่ชำระ',
                        formatBaht(policy.plan.yearlyPremium),
                      ),
                      InfoRow('วิธีชำระเงิน', policy.paymentMethod),
                      InfoRow(
                        'ผู้รับผลประโยชน์',
                        '${policy.beneficiaryName} (${policy.beneficiaryRelation})',
                      ),
                      InfoRow(
                        'ระยะเวลาคุ้มครอง',
                        '${formatThaiDate(policy.startDate)} - ${formatThaiDate(policy.endDate)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: justPurchased ? 7 : 2,
                child: const SimulationBanner(
                  text: 'เอกสารนี้เป็นการจำลอง ไม่ใช่กรมธรรม์ที่มีผลทางกฎหมาย',
                ),
              ),
              if (justPurchased) ...[
                const SizedBox(height: 24),
                FadeSlideIn(
                  index: 8,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('กลับเมนูหลัก'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
