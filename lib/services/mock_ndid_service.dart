import 'dart:math';

/// ผู้ให้บริการยืนยันตัวตน (IdP) สมมติ ไม่ใช่สถาบันจริง
class IdentityProvider {
  const IdentityProvider(this.id, this.name);

  final String id;
  final String name;
}

const identityProviders = <IdentityProvider>[
  IdentityProvider('idp-a', 'ธนาคารสมมติ เอ'),
  IdentityProvider('idp-b', 'ธนาคารสมมติ บี'),
  IdentityProvider('idp-c', 'ธนาคารสมมติ ซี'),
];

class NdidResult {
  const NdidResult({
    required this.referenceId,
    required this.idpName,
    required this.verifiedAt,
  });

  final String referenceId;
  final String idpName;
  final DateTime verifiedAt;
}

/// จำลองการรับ-ส่งคำขอ ไม่มีการเชื่อมต่อเครือข่าย NDID หรือส่งข้อมูลออกจากเครื่อง
class MockNdidService {
  const MockNdidService({this.delay = const Duration(seconds: 2)});

  final Duration delay;

  Future<NdidResult> verify(IdentityProvider idp) async {
    await Future<void>.delayed(delay);
    final now = DateTime.now();
    final suffix = Random().nextInt(1000000).toString().padLeft(6, '0');
    return NdidResult(
      referenceId: 'SIM-$suffix',
      idpName: idp.name,
      verifiedAt: now,
    );
  }
}
