import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/models/insurance.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/services/app_state.dart';
import 'package:ndid_mobile/services/mock_ndid_service.dart';

import '../fake_api.dart';

final _user = UserProfile(
  title: 'นาย',
  firstName: 'ทดสอบ',
  lastName: 'ระบบ',
  citizenId: '1101700230678',
  birthDate: DateTime(1990, 1, 1),
  phone: '0812345678',
  email: 'test@example.com',
);

NdidResult _result(String ref) => NdidResult(
      referenceId: ref,
      idpName: identityProviders.first.name,
      verifiedAt: DateTime(2026, 11, 3),
    );

class _CountingApi extends FakeAppApi {
  int planCalls = 0;

  @override
  Future<List<InsurancePlan>> fetchPlans() {
    planCalls++;
    return super.fetchPlans();
  }
}

void main() {
  test('completeVerification เก็บผู้ใช้และแจ้งหน้าจอ', () async {
    final state = AppState(api: FakeAppApi());
    var notified = 0;
    state.addListener(() => notified++);

    await state.completeVerification(
        _user, identityProviders.first, _result('SIM-1'));

    expect(state.profile, same(_user));
    expect(state.ndidResult!.referenceId, 'SIM-1');
    expect(state.policies, isEmpty);
    expect(notified, 1);
  });

  test('purchase เพิ่มกรมธรรม์ใหม่ไว้บนสุด', () async {
    final state = AppState(api: FakeAppApi());
    await state.completeVerification(
        _user, identityProviders.first, _result('SIM-1'));

    await state.purchase(
      plan: testPlans[0],
      beneficiaryName: 'ก',
      beneficiaryRelation: 'บุตร',
      paymentMethod: paymentMethods.first,
    );
    await state.purchase(
      plan: testPlans[2],
      beneficiaryName: 'ข',
      beneficiaryRelation: 'บุตร',
      paymentMethod: paymentMethods.last,
    );

    expect(state.policies.map((p) => p.plan.id), ['TR', 'PA']);
    expect(state.policies.first.holderName, 'นายทดสอบ ระบบ');
  });

  test('ยืนยันตัวตนอีกครั้งด้วยเลขบัตรเดิม ได้กรมธรรม์เดิมกลับมา', () async {
    final api = FakeAppApi();
    final first = AppState(api: api);
    await first.completeVerification(
        _user, identityProviders.first, _result('SIM-1'));
    await first.purchase(
      plan: testPlans[0],
      beneficiaryName: 'ก',
      beneficiaryRelation: 'บุตร',
      paymentMethod: paymentMethods.first,
    );

    first.signOut();
    expect(first.profile, isNull);
    expect(first.policies, isEmpty);

    await first.completeVerification(
        _user, identityProviders.last, _result('SIM-2'));
    expect(first.policies, hasLength(1));
    expect(first.ndidResult!.referenceId, 'SIM-2');
  });

  test('loadPlans เรียกเซิร์ฟเวอร์ครั้งเดียวแล้วใช้ค่าที่เก็บไว้', () async {
    final api = _CountingApi();
    final state = AppState(api: api);
    await state.loadPlans();
    await state.loadPlans();
    expect(api.planCalls, 1);
  });

  test('MockNdidService คืนเลขอ้างอิงรูปแบบ SIM-xxxxxx และชื่อผู้ยืนยัน',
      () async {
    const service = MockNdidService(delay: Duration.zero);
    final result = await service.verify(identityProviders[2]);
    expect(result.referenceId, matches(RegExp(r'^SIM-\d{6}$')));
    expect(result.idpName, 'ธนาคารสมมติ ซี');
  });
}
