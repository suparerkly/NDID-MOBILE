// E2E ระหว่างแอปกับเซิร์ฟเวอร์จริง: เรียก HttpAppApi (โค้ดเดียวกับที่แอปใช้)
// ไปยังเซิร์ฟเวอร์จำลอง + Prisma + SQLite ที่เปิดอยู่
//
// รันผ่าน tool/test_contract.sh ซึ่งเปิดเซิร์ฟเวอร์กับฐานข้อมูลเทสต์ชั่วคราวให้
// ถ้ารัน flutter test ตรง ๆ โดยไม่ส่ง --dart-define=API_BASE_URL จะข้ามเทสต์ชุดนี้
@Tags(['contract'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/services/api_client.dart';
import 'package:ndid_mobile/services/app_state.dart';
import 'package:ndid_mobile/services/mock_ndid_service.dart';
import 'package:ndid_mobile/services/validators.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL');

/// เลขบัตรสุ่มที่ผ่านเลขตรวจสอบ เพื่อไม่ชนกับข้อมูลของรอบอื่น
String randomCitizenId() {
  final random = Random();
  while (true) {
    final head = List.generate(12, (_) => random.nextInt(10)).join();
    for (var check = 0; check < 10; check++) {
      if (isValidThaiCitizenId('$head$check')) return '$head$check';
    }
  }
}

UserProfile person({required int age, String? citizenId}) {
  final now = DateTime.now();
  return UserProfile(
    title: 'นาย',
    firstName: 'สัญญา',
    lastName: 'ทดสอบ',
    citizenId: citizenId ?? randomCitizenId(),
    birthDate: DateTime(now.year - age, 1, 1),
    phone: '0812345678',
    email: 'contract@example.com',
  );
}

void main() {
  final skip = _baseUrl.isEmpty
      ? 'ต้องรันผ่าน tool/test_contract.sh (ไม่ได้ส่ง API_BASE_URL)'
      : null;
  final api = HttpAppApi(baseUrl: _baseUrl.isEmpty ? 'http://x' : _baseUrl);
  const ndid = MockNdidService(delay: Duration.zero);

  test('อ่านแบบประกันจาก seed ครบ 3 แบบ ภาษาไทยไม่เพี้ยน', () async {
    final plans = await api.fetchPlans();
    expect(plans.map((p) => p.id), ['PA', 'HL', 'TR']);
    expect(plans.first.name, 'ประกันอุบัติเหตุ พร้อมคุ้ม');
    expect(plans.every((p) => p.benefits.length == 3), isTrue);
  }, skip: skip);

  test('flow เต็ม: ยืนยันตัวตน → ซื้อ PA และ TR → โหลดกรมธรรม์', () async {
    final state = AppState(api: api);
    final user = person(age: 30);
    final idp = identityProviders[1];
    await state.completeVerification(user, idp, await ndid.verify(idp));
    expect(state.policies, isEmpty);

    final plans = await state.loadPlans();
    final pa = await state.purchase(
      plan: plans[0],
      beneficiaryName: 'ผู้รับ หนึ่ง',
      beneficiaryRelation: 'คู่สมรส',
      paymentMethod: 'QR พร้อมเพย์ (จำลอง)',
    );
    expect(pa.number, matches(RegExp('^PA-${DateTime.now().year}-\\d{6}\$')));
    expect(pa.holderName, user.fullName);
    expect(pa.endDate.year - pa.startDate.year, 1);

    await state.purchase(
      plan: plans[2],
      beneficiaryName: 'ผู้รับ สอง',
      beneficiaryRelation: 'บุตร',
      paymentMethod: 'Mobile Banking (จำลอง)',
    );
    expect(state.policies.map((p) => p.plan.id), ['TR', 'PA']);

    // ผู้ใช้เดิมกลับมาใหม่ ได้กรมธรรม์จากฐานข้อมูล เรียงล่าสุดก่อน
    state.signOut();
    final again = AppState(api: api);
    await again.completeVerification(
        user, identityProviders[2], await ndid.verify(identityProviders[2]));
    expect(again.policies.map((p) => p.plan.id), ['TR', 'PA']);
    expect(again.policies.last.beneficiaryName, 'ผู้รับ หนึ่ง');
  }, skip: skip);

  test('อายุ 19 ปีซื้อ HL (20-60) ไม่ได้ ได้ข้อความภาษาไทยจาก 422', () async {
    final state = AppState(api: api);
    await state.completeVerification(person(age: 19), identityProviders[0],
        await ndid.verify(identityProviders[0]));
    final plans = await state.loadPlans();

    await expectLater(
      state.purchase(
        plan: plans[1],
        beneficiaryName: 'ผู้รับ',
        beneficiaryRelation: 'บุตร',
        paymentMethod: 'QR พร้อมเพย์ (จำลอง)',
      ),
      throwsA(isA<ApiException>().having((e) => e.message, 'message',
          'อายุไม่อยู่ในเกณฑ์รับประกันของแบบนี้')),
    );
    expect(state.policies, isEmpty);
  }, skip: skip);

  test('ผู้ใช้ที่ไม่มีในฐานข้อมูล ได้ข้อความ 404 ภาษาไทย', () async {
    await expectLater(
      api.createPolicy(999999,
          planId: 'PA',
          beneficiaryName: 'x',
          beneficiaryRelation: 'x',
          paymentMethod: 'x'),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'message', contains('เริ่มยืนยันตัวตนใหม่'))),
    );
  }, skip: skip);
}
