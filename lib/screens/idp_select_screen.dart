import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/mock_ndid_service.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'face_scan.dart';

class IdpSelectScreen extends StatefulWidget {
  const IdpSelectScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<IdpSelectScreen> createState() => _IdpSelectScreenState();
}

class _IdpSelectScreenState extends State<IdpSelectScreen> {
  IdentityProvider _selected = identityProviders.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepHeader(current: 2, title: 'เลือกผู้ยืนยันตัวตน'),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < identityProviders.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FadeSlideIn(
                            index: i + 1,
                            child: SelectTile(
                              icon: Icons.account_balance_outlined,
                              title: identityProviders[i].name,
                              selected: identityProviders[i] == _selected,
                              onTap: () => setState(
                                () => _selected = identityProviders[i],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      const FadeSlideIn(
                        index: 4,
                        child: SimulationBanner(
                          text:
                              'รายชื่อด้านบนเป็นธนาคารสมมติ ไม่ใช่สถาบันการเงินจริง',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FaceScanScreen(
                      profile: widget.profile,
                      idp: _selected,
                    ),
                  ),
                ),
                child: const Text('ถัดไป: ตรวจสอบใบหน้า'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
