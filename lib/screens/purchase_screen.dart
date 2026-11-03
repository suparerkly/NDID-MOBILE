import 'package:flutter/material.dart';

import '../models/insurance.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../services/validators.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'policy_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key, required this.plan});

  final InsurancePlan plan;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  static const _relations = [
    'คู่สมรส',
    'บิดา/มารดา',
    'บุตร',
    'พี่น้อง',
    'อื่น ๆ'
  ];

  final _formKey = GlobalKey<FormState>();
  final _beneficiary = TextEditingController();

  String _relation = _relations.first;
  String _paymentMethod = paymentMethods.first;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _paying = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _beneficiary.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final formValid = _formKey.currentState!.validate();
    setState(() {
      _showTermsError = !_acceptedTerms;
      if (!formValid) _autovalidate = AutovalidateMode.onUserInteraction;
    });
    if (!formValid || !_acceptedTerms) return;

    final confirmed = await showSoftDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการชำระเงิน'),
        titleTextStyle: Theme.of(context).textTheme.headlineSmall,
        content: Text(
          'ชำระเบี้ย ${formatBaht(widget.plan.yearlyPremium)} '
          'ผ่าน $_paymentMethod\n\nนี่เป็นการจำลอง ไม่มีการตัดเงินจริง',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('ยืนยัน'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _paying = true);
    final Policy policy;
    try {
      policy = await AppStateScope.read(context).purchase(
        plan: widget.plan,
        beneficiaryName: _beneficiary.text.trim(),
        beneficiaryRelation: _relation,
        paymentMethod: _paymentMethod,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PolicyDetailScreen(policy: policy, justPurchased: true),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = AppStateScope.of(context).profile;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.plan.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: OutlinedPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Column(
                      children: [
                        InfoRow('ผู้เอาประกัน', profile?.fullName ?? '-'),
                        InfoRow(
                          'ทุนประกัน',
                          formatBaht(widget.plan.sumInsured),
                        ),
                        InfoRow(
                          'เบี้ยประกันต่อปี',
                          formatBaht(widget.plan.yearlyPremium),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  index: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ผู้รับผลประโยชน์',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('beneficiary'),
                        controller: _beneficiary,
                        decoration:
                            const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
                        validator: (value) =>
                            validateRequired(value, 'ชื่อผู้รับผลประโยชน์'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _relation,
                        borderRadius: BorderRadius.circular(appRadius),
                        dropdownColor: AppColors.surface,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        decoration:
                            const InputDecoration(labelText: 'ความสัมพันธ์'),
                        items: [
                          for (final relation in _relations)
                            DropdownMenuItem(
                              value: relation,
                              child: Text(relation),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _relation = value!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('วิธีชำระเงิน', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      for (final method in paymentMethods)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SelectTile(
                            title: method,
                            selected: method == _paymentMethod,
                            onTap: () =>
                                setState(() => _paymentMethod = method),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 4,
                  child: CheckboxListTile(
                    key: const Key('terms'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _acceptedTerms,
                    onChanged: (value) => setState(() {
                      _acceptedTerms = value ?? false;
                      if (_acceptedTerms) _showTermsError = false;
                    }),
                    title: Text(
                      'ฉันได้อ่านเงื่อนไขของแบบประกันตัวอย่างและยืนยันว่าข้อมูลถูกต้อง',
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: _showTermsError
                        ? Text(
                            'กรุณายอมรับเงื่อนไขก่อนชำระเงิน',
                            style: TextStyle(color: theme.colorScheme.error),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 5,
                  child: FilledButton(
                    onPressed: _paying ? null : _confirm,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _paying
                          ? const SizedBox.square(
                              key: ValueKey('paying'),
                              dimension: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(
                              'ชำระเงิน ${formatBaht(widget.plan.yearlyPremium)}',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
