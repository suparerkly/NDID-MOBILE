import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/mock_ndid_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/face_frame.dart';
import 'verification_result.dart';

/// หน้าตรวจใบหน้าสำหรับเว็บ ML Kit ไม่รองรับเบราว์เซอร์ จึงไม่มีการตรวจใบหน้าจริง
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({
    super.key,
    required this.profile,
    required this.idp,
    this.ndidService = const MockNdidService(),
  });

  final UserProfile profile;
  final IdentityProvider idp;
  final MockNdidService ndidService;

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final saved = await completeVerification(
      context,
      profile: widget.profile,
      idp: widget.idp,
      ndidService: widget.ndidService,
    );
    if (!saved && mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _submitting
        ? 'กำลังส่งคำขอยืนยันตัวตนไปยัง ${widget.idp.name}...'
        : 'เวอร์ชันเว็บไม่มีการตรวจใบหน้า';
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepHeader(current: 3, title: 'ตรวจสอบใบหน้า'),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: FaceFrame(
                      progress: _submitting ? 1 : 0,
                      scanning: false,
                      child: _submitting
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 32,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            )
                          : const Icon(
                              Icons.face_outlined,
                              size: 56,
                              color: AppColors.muted,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      message,
                      key: ValueKey(message),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SimulationBanner(
                text:
                    'ตรวจใบหน้าได้เฉพาะในแอปบนมือถือ บนเว็บจะข้ามขั้นนี้และจำลองผลให้',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: const Text('จำลองผลการยืนยันตัวตน'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
