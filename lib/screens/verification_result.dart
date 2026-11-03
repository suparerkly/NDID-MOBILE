import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../services/mock_ndid_service.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'home_screen.dart';

/// ส่งคำขอยืนยันตัวตนจำลอง บันทึกผลลงฐานข้อมูล แสดง popup สำเร็จ แล้วไปที่เมนูหลัก
///
/// คืนค่า false เมื่อบันทึกไม่สำเร็จ หน้าที่เรียกจึงให้ผู้ใช้ลองใหม่ได้
Future<bool> completeVerification(
  BuildContext context, {
  required UserProfile profile,
  required IdentityProvider idp,
  required MockNdidService ndidService,
}) async {
  final state = AppStateScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final NdidResult result;
  try {
    result = await ndidService.verify(idp);
    await state.completeVerification(profile, idp, result);
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
  if (!context.mounted) return true;
  await _showSuccessDialog(context, profile, result);
  if (!context.mounted) return true;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    (_) => false,
  );
  return true;
}

Future<void> _showSuccessDialog(
  BuildContext context,
  UserProfile profile,
  NdidResult result,
) {
  return showSoftDialog<void>(
    context: context,
    dismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      return PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AnimatedCheck()),
                const SizedBox(height: 16),
                Text(
                  'ยืนยันตัวตนสำเร็จ',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  'ผลลัพธ์นี้เป็นการจำลอง',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                InfoRow('ชื่อ', profile.fullName),
                InfoRow('เลขบัตร', profile.maskedCitizenId),
                InfoRow('ผู้ยืนยัน', result.idpName),
                InfoRow('เลขอ้างอิง', result.referenceId),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ไปที่เมนูประกัน'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
