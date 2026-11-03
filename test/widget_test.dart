import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/main.dart';
import 'package:ndid_mobile/models/insurance.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/screens/home_screen.dart';
import 'package:ndid_mobile/screens/idp_select_screen.dart';
import 'package:ndid_mobile/screens/personal_info_screen.dart';
import 'package:ndid_mobile/screens/plan_list_screen.dart';
import 'package:ndid_mobile/services/api_client.dart';
import 'package:ndid_mobile/services/app_state.dart';
import 'package:ndid_mobile/services/mock_ndid_service.dart';
import 'package:ndid_mobile/theme.dart';

import 'fake_api.dart';

Widget _wrap(AppState state, Widget home) => AppStateScope(
      state: state,
      child: MaterialApp(theme: buildAppTheme(), home: home),
    );

Future<void> _useTallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('welcome button stays disabled until consent is given',
      (tester) async {
    await tester.pumpWidget(const NdidSimApp());

    FilledButton button() => tester.widget(find.byType(FilledButton));
    expect(button().onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalInfoScreen), findsOneWidget);
  });

  testWidgets('personal info form shows errors for invalid input',
      (tester) async {
    await _useTallScreen(tester);
    await tester.pumpWidget(
        _wrap(AppState(api: FakeAppApi()), const PersonalInfoScreen()));

    await tester.enterText(find.byKey(const Key('citizenId')), '1101700230674');
    await tester.tap(find.text('ถัดไป'));
    await tester.pump();

    expect(find.text('กรุณากรอกชื่อ'), findsOneWidget);
    expect(find.text('เลขบัตรประชาชนไม่ถูกต้อง'), findsOneWidget);
    expect(find.text('กรุณาเลือกวันเกิด'), findsOneWidget);
  });

  testWidgets('sample data passes the form and clears earlier errors',
      (tester) async {
    await _useTallScreen(tester);
    await tester.pumpWidget(
        _wrap(AppState(api: FakeAppApi()), const PersonalInfoScreen()));

    await tester.tap(find.text('ถัดไป'));
    await tester.pump();
    expect(find.text('กรุณากรอกชื่อ'), findsOneWidget);

    await tester.tap(find.text('กรอกข้อมูลตัวอย่าง'));
    await tester.pump();
    expect(find.text('กรุณากรอกชื่อ'), findsNothing);

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    expect(find.byType(IdpSelectScreen), findsOneWidget);
  });

  testWidgets('an error clears as soon as the field is fixed', (tester) async {
    await _useTallScreen(tester);
    await tester.pumpWidget(
        _wrap(AppState(api: FakeAppApi()), const PersonalInfoScreen()));

    await tester.tap(find.text('ถัดไป'));
    await tester.pump();
    expect(find.text('กรุณากรอกชื่อ'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('firstName')), 'ทดสอบ');
    await tester.pump();
    expect(find.text('กรุณากรอกชื่อ'), findsNothing);
    expect(find.text('กรุณากรอกนามสกุล'), findsOneWidget);
  });

  testWidgets('form validates fields scrolled off a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        _wrap(AppState(api: FakeAppApi()), const PersonalInfoScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ถัดไป'));
    await tester.pump();

    expect(
      find.text('กรุณากรอกชื่อ', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('กรุณากรอกอีเมล', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('plan cards expand one at a time', (tester) async {
    await _useTallScreen(tester);
    final state = AppState(api: FakeAppApi());
    await state.completeVerification(
      UserProfile(
        title: 'นาย',
        firstName: 'ทดสอบ',
        lastName: 'ระบบ',
        citizenId: '1101700230678',
        birthDate: DateTime(1990, 1, 1),
        phone: '0812345678',
        email: 'test@example.com',
      ),
      identityProviders.first,
      NdidResult(
        referenceId: 'SIM-3',
        idpName: 'ธนาคารสมมติ เอ',
        verifiedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(_wrap(state, const PlanListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ซื้อแบบนี้'), findsOneWidget);
    expect(find.text('ตรวจสุขภาพประจำปี 1 ครั้ง'), findsNothing);

    await tester.tap(find.text('ประกันสุขภาพ อุ่นใจ'));
    await tester.pumpAndSettle();

    expect(find.text('ซื้อแบบนี้'), findsOneWidget);
    expect(find.text('ตรวจสุขภาพประจำปี 1 ครั้ง'), findsOneWidget);
  });

  testWidgets('verified user can buy a plan and see the policy',
      (tester) async {
    await _useTallScreen(tester);
    final state = AppState(api: FakeAppApi());
    await state.completeVerification(
      UserProfile(
        title: 'นาย',
        firstName: 'ทดสอบ',
        lastName: 'ระบบ',
        citizenId: '1101700230678',
        birthDate: DateTime(1990, 1, 1),
        phone: '0812345678',
        email: 'test@example.com',
      ),
      identityProviders.first,
      NdidResult(
        referenceId: 'SIM-1',
        idpName: 'ธนาคารสมมติ เอ',
        verifiedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(_wrap(state, const HomeScreen()));

    await tester.tap(find.text('ซื้อประกันออนไลน์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ซื้อแบบนี้').first);
    await tester.pumpAndSettle();

    // ยังไม่กรอกข้อมูล ต้องไม่ผ่าน
    await tester.tap(find.text('ชำระเงิน 1,200 บาท'));
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกชื่อผู้รับผลประโยชน์'), findsOneWidget);
    expect(find.text('กรุณายอมรับเงื่อนไขก่อนชำระเงิน'), findsOneWidget);
    expect(state.policies, isEmpty);

    await tester.enterText(find.byKey(const Key('beneficiary')), 'คนรับ ทดสอบ');
    await tester.tap(find.byKey(const Key('terms')));
    await tester.pump();
    await tester.tap(find.text('ชำระเงิน 1,200 บาท'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('ซื้อประกันสำเร็จ'), findsOneWidget);
    expect(state.policies, hasLength(1));
    expect(state.policies.single.beneficiaryName, 'คนรับ ทดสอบ');

    await tester.tap(find.text('กลับเมนูหลัก'));
    await tester.pumpAndSettle();
    expect(find.text('1 ฉบับ'), findsOneWidget);
  });

  testWidgets('a person outside the age range cannot buy', (tester) async {
    await _useTallScreen(tester);
    final now = DateTime.now();
    final state = AppState(api: FakeAppApi());
    await state.completeVerification(
      UserProfile(
        title: 'นาย',
        firstName: 'เด็ก',
        lastName: 'ทดสอบ',
        citizenId: '1101700230678',
        birthDate: DateTime(now.year - 10),
        phone: '0812345678',
        email: 'test@example.com',
      ),
      identityProviders.first,
      NdidResult(
        referenceId: 'SIM-2',
        idpName: 'ธนาคารสมมติ เอ',
        verifiedAt: now,
      ),
    );
    await tester.pumpWidget(_wrap(state, const HomeScreen()));

    await tester.tap(find.text('ซื้อประกันออนไลน์'));
    await tester.pumpAndSettle();

    expect(find.text('ซื้อแบบนี้'), findsNothing);
    expect(find.text('อายุไม่อยู่ในเกณฑ์รับประกัน'), findsNWidgets(3));
  });

  testWidgets('plan list offers a retry when the server is down',
      (tester) async {
    await _useTallScreen(tester);
    final api = _FlakyApi();
    await tester.pumpWidget(_wrap(AppState(api: api), const PlanListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('เซิร์ฟเวอร์ปิดอยู่'), findsOneWidget);

    api.down = false;
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(find.text('ประกันสุขภาพ อุ่นใจ'), findsOneWidget);
  });
}

class _FlakyApi extends FakeAppApi {
  bool down = true;

  @override
  Future<List<InsurancePlan>> fetchPlans() async {
    if (down) throw const ApiException('เซิร์ฟเวอร์ปิดอยู่');
    return super.fetchPlans();
  }
}
