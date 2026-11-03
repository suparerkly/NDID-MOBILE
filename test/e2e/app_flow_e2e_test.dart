// E2E ทุก flow ของแอปผ่าน UI จริง ตั้งแต่หน้ายินยอมจนซื้อประกันและดูกรมธรรม์
//
// ใช้ FakeAppApi แทนเซิร์ฟเวอร์ (เทสต์กับเซิร์ฟเวอร์จริงอยู่ที่ test/contract)
// กล้องและ ML Kit จำลองด้วย mock platform channel: เครื่องเทสต์ "ไม่มีกล้อง"
// จึงใช้ปุ่มข้ามการสแกนที่มีเฉพาะ debug build เหมือน integration_test บนอีมูเลเตอร์
// ส่วนตรรกะตรวจใบหน้าทดสอบแยกที่ test/unit/liveness_checker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/main.dart';
import 'package:ndid_mobile/models/insurance.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/screens/face_scan.dart';
import 'package:ndid_mobile/screens/home_screen.dart';
import 'package:ndid_mobile/screens/idp_select_screen.dart';
import 'package:ndid_mobile/screens/personal_info_screen.dart';
import 'package:ndid_mobile/screens/plan_list_screen.dart';
import 'package:ndid_mobile/screens/policy_screen.dart';
import 'package:ndid_mobile/screens/purchase_screen.dart';
import 'package:ndid_mobile/screens/welcome_screen.dart';
import 'package:ndid_mobile/services/api_client.dart';
import 'package:ndid_mobile/services/mock_ndid_service.dart';

import '../fake_api.dart';

const _cameraChannel = MethodChannel('plugins.flutter.io/camera');
const _faceDetectorChannel = MethodChannel('google_mlkit_face_detector');

/// เซิร์ฟเวอร์จำลองในหน่วยความจำที่สั่งให้ล้มเหลวได้
class ScriptedApi extends FakeAppApi {
  int failVerifications = 0;
  ApiException? purchaseError;
  final savedIdps = <String>[];
  final savedReferenceIds = <String>[];

  @override
  Future<int> saveVerification(
    UserProfile profile,
    IdentityProvider idp,
    NdidResult result,
  ) async {
    if (failVerifications > 0) {
      failVerifications--;
      throw const ApiException('เชื่อมต่อเซิร์ฟเวอร์จำลองไม่ได้ (เทสต์)');
    }
    savedIdps.add(idp.id);
    savedReferenceIds.add(result.referenceId);
    return super.saveVerification(profile, idp, result);
  }

  @override
  Future<Policy> createPolicy(
    int userId, {
    required String planId,
    required String beneficiaryName,
    required String beneficiaryRelation,
    required String paymentMethod,
  }) async {
    final error = purchaseError;
    if (error != null) throw error;
    return super.createPolicy(
      userId,
      planId: planId,
      beneficiaryName: beneficiaryName,
      beneficiaryRelation: beneficiaryRelation,
      paymentMethod: paymentMethod,
    );
  }
}

/// ข้อมูลที่ผู้ใช้กรอกในฟอร์ม
class Person {
  const Person({
    this.title = 'นาย',
    this.firstName = 'สมชาย',
    this.lastName = 'ทดสอบระบบ',
    this.citizenId = '1101700230678',
    this.birthDate,
    this.phone = '0812345678',
    this.email = 'somchai@example.com',
  });

  final String title;
  final String firstName;
  final String lastName;
  final String citizenId;

  /// null = ใช้วันเกิดจากปุ่มกรอกข้อมูลตัวอย่าง (1/1/1990)
  final DateTime? birthDate;
  final String phone;
  final String email;

  String get fullName => '$title$firstName $lastName';
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < duration; t += step) {
    await tester.pump(step);
  }
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseDropdown(
    WidgetTester tester, String current, String value) async {
  await tapAndSettle(tester, find.text(current).last);
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

/// เลือกวันเกิดผ่าน date picker โดยสลับเป็นโหมดพิมพ์วันที่
Future<void> pickBirthDate(WidgetTester tester, DateTime date) async {
  await tapAndSettle(tester, find.byKey(const Key('birthDate')));
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  await tester.enterText(
      find.descendant(
          of: find.byType(Dialog), matching: find.byType(TextField)),
      '$mm/$dd/${date.year}');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> startApp(WidgetTester tester, ScriptedApi api) async {
  await tester.pumpWidget(NdidSimApp(api: api));
  await tester.pumpAndSettle();
}

/// ขั้นที่ 1: ยินยอม แล้วกรอกฟอร์มข้อมูลส่วนตัว
Future<void> consentAndFillForm(WidgetTester tester, Person person) async {
  expect(find.byType(WelcomeScreen), findsOneWidget);
  await tapAndSettle(tester, find.byType(CheckboxListTile));
  await tapAndSettle(tester, find.text('เริ่มยืนยันตัวตน'));
  expect(find.byType(PersonalInfoScreen), findsOneWidget);

  await tapAndSettle(tester, find.text('กรอกข้อมูลตัวอย่าง'));
  if (person.title != 'นาย') {
    await chooseDropdown(tester, 'นาย', person.title);
  }
  await tester.enterText(find.byKey(const Key('firstName')), person.firstName);
  await tester.enterText(find.byKey(const Key('lastName')), person.lastName);
  await tester.enterText(find.byKey(const Key('citizenId')), person.citizenId);
  await tester.enterText(find.byKey(const Key('phone')), person.phone);
  await tester.enterText(find.byKey(const Key('email')), person.email);
  if (person.birthDate != null) await pickBirthDate(tester, person.birthDate!);
  await tester.pumpAndSettle();
  await tapAndSettle(tester, find.text('ถัดไป'));
}

/// ขั้นที่ 2-3: เลือกผู้ยืนยันตัวตน แล้วไปหน้าตรวจใบหน้า
Future<void> chooseIdpAndOpenFaceScan(WidgetTester tester, String idp) async {
  expect(find.byType(IdpSelectScreen), findsOneWidget);
  await tapAndSettle(tester, find.text(idp));
  await tester.tap(find.text('ถัดไป: ตรวจสอบใบหน้า'));
  await pumpFor(tester, const Duration(seconds: 1));
  expect(find.byType(FaceScanScreen), findsOneWidget);
  // เครื่องเทสต์ไม่มีกล้อง หน้าจอต้องแจ้งและให้ลองใหม่ได้
  expect(find.text('ไม่พบกล้องบนอุปกรณ์นี้'), findsOneWidget);
  expect(find.text('ลองอีกครั้ง'), findsOneWidget);
}

/// ข้ามการสแกน รอผลจาก MockNdidService (2 วินาที)
Future<void> skipScan(WidgetTester tester) async {
  await tester.tap(find.text('ข้ามการสแกน (เฉพาะ debug build)'));
  await tester.pump();
  expect(find.textContaining('กำลังส่งคำขอยืนยันตัวตนไปยัง'), findsOneWidget);
  await pumpFor(tester, const Duration(seconds: 3));
}

/// flow ยืนยันตัวตนครบจนถึงเมนูหลัก
Future<void> verify(
  WidgetTester tester,
  ScriptedApi api, {
  Person person = const Person(),
  String idp = 'ธนาคารสมมติ บี',
}) async {
  await consentAndFillForm(tester, person);
  await chooseIdpAndOpenFaceScan(tester, idp);
  await skipScan(tester);

  expect(find.text('ยืนยันตัวตนสำเร็จ'), findsOneWidget);
  expect(find.text(person.fullName), findsOneWidget);
  expect(
    find.text(
        '${person.citizenId[0]}-XXXX-XXXXX-${person.citizenId.substring(10, 12)}-${person.citizenId[12]}'),
    findsOneWidget,
  );
  expect(find.text(idp), findsOneWidget);
  expect(find.text(api.savedReferenceIds.last), findsOneWidget);

  await tester.tap(find.text('ไปที่เมนูประกัน'));
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.text('สวัสดี ${person.firstName}'), findsOneWidget);
  expect(find.text('ยืนยันตัวตนแล้ว (จำลอง)'), findsOneWidget);
  // หน้าก่อนหน้าถูกล้างออกจาก stack ย้อนกลับไปหน้าตรวจใบหน้าไม่ได้
  expect(find.byType(BackButton), findsNothing);
}

/// เปิดรายการแบบประกัน กางแบบที่ต้องการ แล้วกดซื้อ
Future<void> openPurchase(WidgetTester tester, String planName) async {
  await tapAndSettle(tester, find.text('ซื้อประกันออนไลน์'));
  expect(find.byType(PlanListScreen), findsOneWidget);
  if (planName != testPlans.first.name) {
    await tapAndSettle(tester, find.text(planName));
  }
  await tapAndSettle(tester, find.text('ซื้อแบบนี้'));
  expect(find.byType(PurchaseScreen), findsOneWidget);
  expect(find.text(planName), findsOneWidget);
}

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_cameraChannel, (call) async {
      if (call.method == 'availableCameras') return <Object>[];
      return null;
    });
    messenger.setMockMethodCallHandler(_faceDetectorChannel, (_) async => null);
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 3200);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
  });

  group('Flow A: ยืนยันตัวตน', () {
    testWidgets('A1 ปุ่มเริ่มกดไม่ได้จนกว่าจะยินยอม และยกเลิกการยินยอมได้',
        (tester) async {
      await startApp(tester, ScriptedApi());
      FilledButton start() => tester.widget(find.byType(FilledButton));

      expect(start().onPressed, isNull);
      await tapAndSettle(tester, find.byType(CheckboxListTile));
      expect(start().onPressed, isNotNull);
      await tapAndSettle(tester, find.byType(CheckboxListTile));
      expect(start().onPressed, isNull);
    });

    testWidgets('A2 ฟอร์มตรวจทุกช่องและไม่ไปต่อเมื่อข้อมูลผิด', (tester) async {
      await startApp(tester, ScriptedApi());
      await tapAndSettle(tester, find.byType(CheckboxListTile));
      await tapAndSettle(tester, find.text('เริ่มยืนยันตัวตน'));

      await tester.enterText(find.byKey(const Key('citizenId')), '1234567890123');
      await tester.enterText(find.byKey(const Key('phone')), '0212345678');
      await tester.enterText(find.byKey(const Key('email')), 'no-domain@');
      await tapAndSettle(tester, find.text('ถัดไป'));

      expect(find.byType(PersonalInfoScreen), findsOneWidget);
      expect(find.text('กรุณากรอกชื่อ'), findsOneWidget);
      expect(find.text('กรุณากรอกนามสกุล'), findsOneWidget);
      expect(find.text('เลขบัตรประชาชนไม่ถูกต้อง'), findsOneWidget);
      expect(find.text('กรุณาเลือกวันเกิด'), findsOneWidget);
      expect(
        find.text('เบอร์มือถือต้องขึ้นต้นด้วย 06, 08 หรือ 09 และมี 10 หลัก'),
        findsOneWidget,
      );
      expect(find.text('รูปแบบอีเมลไม่ถูกต้อง'), findsOneWidget);
    });

    testWidgets('A3 ช่องเลขบัตรรับเฉพาะตัวเลขไม่เกิน 13 หลัก', (tester) async {
      await startApp(tester, ScriptedApi());
      await tapAndSettle(tester, find.byType(CheckboxListTile));
      await tapAndSettle(tester, find.text('เริ่มยืนยันตัวตน'));

      await tester.enterText(
          find.byKey(const Key('citizenId')), '1-1017-00230-67-8999');
      await tester.pump();
      final field = tester.widget<TextField>(find.descendant(
          of: find.byKey(const Key('citizenId')),
          matching: find.byType(TextField)));
      expect(field.controller!.text, '1101700230678');
    });

    testWidgets(
        'A4 flow สำเร็จครบ: ฟอร์ม → เลือกธนาคาร บี → ข้ามสแกน → popup → เมนูหลัก',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      await verify(
        tester,
        api,
        person: Person(
          title: 'นางสาว',
          firstName: 'สมหญิง',
          lastName: 'ใจดี',
          birthDate: DateTime(1995, 6, 15),
        ),
      );

      expect(api.savedIdps, ['idp-b']);
      expect(api.savedReferenceIds.single, matches(RegExp(r'^SIM-\d{6}$')));
      expect(find.text('0 ฉบับ'), findsOneWidget);
    });

    testWidgets('A5 บันทึกผลไม่สำเร็จ แจ้งเตือนแล้วลองใหม่ได้', (tester) async {
      final api = ScriptedApi()..failVerifications = 1;
      await startApp(tester, api);
      await consentAndFillForm(tester, const Person());
      await chooseIdpAndOpenFaceScan(tester, 'ธนาคารสมมติ เอ');

      await skipScan(tester);
      expect(find.text('เชื่อมต่อเซิร์ฟเวอร์จำลองไม่ได้ (เทสต์)'), findsOneWidget);
      expect(find.text('ยืนยันตัวตนสำเร็จ'), findsNothing);
      expect(find.byType(FaceScanScreen), findsOneWidget);

      await pumpFor(tester, const Duration(seconds: 5)); // รอ snackbar หาย
      await skipScan(tester);
      expect(find.text('ยืนยันตัวตนสำเร็จ'), findsOneWidget);
      expect(api.savedIdps, ['idp-a']);
    });

    testWidgets('A6 ย้อนกลับจากหน้าเลือกธนาคาร ข้อมูลในฟอร์มยังอยู่',
        (tester) async {
      await startApp(tester, ScriptedApi());
      await consentAndFillForm(tester, const Person(firstName: 'ย้อนกลับ'));
      expect(find.byType(IdpSelectScreen), findsOneWidget);

      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.byType(PersonalInfoScreen), findsOneWidget);
      expect(find.text('ย้อนกลับ'), findsOneWidget);
    });
  });

  group('Flow B: ซื้อประกัน', () {
    testWidgets(
        'B1 ซื้อประกันเดินทาง: เลือกผู้รับผลประโยชน์ วิธีชำระเงิน ยกเลิกครั้งแรก แล้วยืนยัน',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      await verify(tester, api);

      await openPurchase(tester, 'ประกันเดินทาง สบายใจ');
      expect(find.text('นายสมชาย ทดสอบระบบ'), findsOneWidget);
      expect(find.text('300,000 บาท'), findsOneWidget);

      // กดชำระโดยยังไม่กรอก ต้องไม่ผ่าน
      await tapAndSettle(tester, find.text('ชำระเงิน 690 บาท'));
      expect(find.text('กรุณากรอกชื่อผู้รับผลประโยชน์'), findsOneWidget);
      expect(find.text('กรุณายอมรับเงื่อนไขก่อนชำระเงิน'), findsOneWidget);
      expect(find.text('ยืนยันการชำระเงิน'), findsNothing);

      await tester.enterText(
          find.byKey(const Key('beneficiary')), 'สมศรี ทดสอบระบบ');
      await chooseDropdown(tester, 'คู่สมรส', 'บุตร');
      await tapAndSettle(tester, find.text('Mobile Banking (จำลอง)'));

      // กรอกครบแต่ยังไม่ยอมรับเงื่อนไข ต้องไม่เปิดหน้ายืนยัน
      await tapAndSettle(tester, find.text('ชำระเงิน 690 บาท'));
      expect(find.text('กรุณากรอกชื่อผู้รับผลประโยชน์'), findsNothing);
      expect(find.text('กรุณายอมรับเงื่อนไขก่อนชำระเงิน'), findsOneWidget);
      expect(find.text('ยืนยันการชำระเงิน'), findsNothing);

      await tapAndSettle(tester, find.byKey(const Key('terms')));
      expect(find.text('กรุณายอมรับเงื่อนไขก่อนชำระเงิน'), findsNothing);

      // ยกเลิกในหน้ายืนยัน ต้องยังไม่มีกรมธรรม์
      await tapAndSettle(tester, find.text('ชำระเงิน 690 บาท'));
      expect(find.textContaining('ผ่าน Mobile Banking (จำลอง)'), findsOneWidget);
      await tapAndSettle(tester, find.text('ยกเลิก'));
      expect(find.byType(PurchaseScreen), findsOneWidget);

      await tapAndSettle(tester, find.text('ชำระเงิน 690 บาท'));
      await tester.tap(find.text('ยืนยัน'));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(find.text('ซื้อประกันสำเร็จ'), findsOneWidget);
      expect(find.text('TR-${DateTime.now().year}-000001'), findsOneWidget);
      expect(find.text('สมศรี ทดสอบระบบ (บุตร)'), findsOneWidget);
      expect(find.text('Mobile Banking (จำลอง)'), findsOneWidget);
      expect(find.text('690 บาท'), findsOneWidget);

      await tapAndSettle(tester, find.text('กลับเมนูหลัก'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('1 ฉบับ'), findsOneWidget);
    });

    testWidgets('B2 เซิร์ฟเวอร์ปฏิเสธการซื้อ (422) แจ้งเตือนและกดซื้อใหม่ได้',
        (tester) async {
      final api = ScriptedApi()
        ..purchaseError =
            const ApiException('อายุไม่อยู่ในเกณฑ์รับประกันของแบบนี้');
      await startApp(tester, api);
      await verify(tester, api);
      await openPurchase(tester, testPlans.first.name);

      await tester.enterText(find.byKey(const Key('beneficiary')), 'คนรับ');
      await tapAndSettle(tester, find.byKey(const Key('terms')));
      await tapAndSettle(tester, find.text('ชำระเงิน 1,200 บาท'));
      await tester.tap(find.text('ยืนยัน'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(find.text('อายุไม่อยู่ในเกณฑ์รับประกันของแบบนี้'), findsOneWidget);
      expect(find.byType(PurchaseScreen), findsOneWidget);

      api.purchaseError = null;
      await pumpFor(tester, const Duration(seconds: 5));
      await tapAndSettle(tester, find.text('ชำระเงิน 1,200 บาท'));
      await tester.tap(find.text('ยืนยัน'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('ซื้อประกันสำเร็จ'), findsOneWidget);
    });

    testWidgets('B3 ผู้ใช้อายุ 11 ปี (เลือกวันเกิดจากปฏิทิน) ซื้อไม่ได้ทุกแบบ',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      final now = DateTime.now();
      await verify(tester, api,
          person: Person(birthDate: DateTime(now.year - 11, 1, 1)));

      await tapAndSettle(tester, find.text('ซื้อประกันออนไลน์'));
      expect(find.text('อายุไม่อยู่ในเกณฑ์รับประกัน'), findsNWidgets(3));
      expect(find.text('ซื้อแบบนี้'), findsNothing);
    });

    testWidgets('B4 อายุ 19 ปี ซื้อประกันอุบัติเหตุได้ แต่ประกันสุขภาพ (20-60) ไม่ได้',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      final now = DateTime.now();
      await verify(tester, api,
          person: Person(birthDate: DateTime(now.year - 19, 1, 1)));

      await tapAndSettle(tester, find.text('ซื้อประกันออนไลน์'));
      expect(find.text('อายุไม่อยู่ในเกณฑ์รับประกัน'), findsOneWidget);
      expect(find.text('ซื้อแบบนี้'), findsOneWidget); // PA กางอยู่และซื้อได้

      await tapAndSettle(tester, find.text('ประกันสุขภาพ อุ่นใจ'));
      expect(find.text('รับประกันอายุ 20-60 ปี'), findsOneWidget);
      expect(find.text('ซื้อแบบนี้'), findsNothing);
    });
  });

  group('Flow C: กรมธรรม์และออกจากระบบ', () {
    testWidgets(
        'C1 ดูรายการว่าง → ซื้อ 2 ฉบับ → รายการเรียงล่าสุดก่อน → ดูรายละเอียด',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      await verify(tester, api);

      await tapAndSettle(tester, find.text('กรมธรรม์ของฉัน'));
      expect(find.text('ยังไม่มีกรมธรรม์'), findsOneWidget);
      await tapAndSettle(tester, find.byType(BackButton));

      for (final plan in [testPlans[0], testPlans[2]]) {
        await openPurchase(tester, plan.name);
        await tester.enterText(find.byKey(const Key('beneficiary')), 'คนรับ');
        await tapAndSettle(tester, find.byKey(const Key('terms')));
        await tapAndSettle(
            tester, find.text('ชำระเงิน ${plan.yearlyPremium == 1200 ? '1,200' : plan.yearlyPremium} บาท'));
        await tester.tap(find.text('ยืนยัน'));
        await pumpFor(tester, const Duration(seconds: 2));
        await tapAndSettle(tester, find.text('กลับเมนูหลัก'));
      }
      expect(find.text('2 ฉบับ'), findsOneWidget);

      await tapAndSettle(tester, find.text('กรมธรรม์ของฉัน'));
      expect(find.byType(PolicyListScreen), findsOneWidget);
      final titles = tester
          .widgetList<Text>(find.textContaining('ประกัน'))
          .map((t) => t.data)
          .where((t) => t != 'กรมธรรม์ของฉัน')
          .toList();
      expect(titles, ['ประกันเดินทาง สบายใจ', 'ประกันอุบัติเหตุ พร้อมคุ้ม']);

      await tapAndSettle(tester, find.text('ประกันอุบัติเหตุ พร้อมคุ้ม'));
      expect(find.byType(PolicyDetailScreen), findsOneWidget);
      expect(find.text('รายละเอียดกรมธรรม์'), findsOneWidget);
      expect(find.text('PA-${DateTime.now().year}-000001'), findsOneWidget);
      expect(find.text('500,000 บาท'), findsOneWidget);
      expect(find.text('คนรับ (คู่สมรส)'), findsOneWidget);
      expect(find.text('กลับเมนูหลัก'), findsNothing);
    });

    testWidgets('C2 ออกจากระบบแล้วกลับหน้าแรก และยืนยันตัวตนใหม่ได้กรมธรรม์เดิม',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      await verify(tester, api);

      await openPurchase(tester, testPlans.first.name);
      await tester.enterText(find.byKey(const Key('beneficiary')), 'คนรับ');
      await tapAndSettle(tester, find.byKey(const Key('terms')));
      await tapAndSettle(tester, find.text('ชำระเงิน 1,200 บาท'));
      await tester.tap(find.text('ยืนยัน'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tapAndSettle(tester, find.text('กลับเมนูหลัก'));
      expect(find.text('1 ฉบับ'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('ออกจากระบบ'));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      final checkbox =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, isFalse);

      // คนเดิม (เลขบัตรเดิม) ยืนยันผ่านธนาคารอื่น
      await verify(tester, api, idp: 'ธนาคารสมมติ ซี');
      expect(find.text('1 ฉบับ'), findsOneWidget);
      expect(api.savedIdps, ['idp-b', 'idp-c']);
    });

    testWidgets('C3 คนอื่น (เลขบัตรใหม่) ยืนยันตัวตนต่อ ไม่เห็นกรมธรรม์ของคนก่อน',
        (tester) async {
      final api = ScriptedApi();
      await startApp(tester, api);
      await verify(tester, api);
      await openPurchase(tester, testPlans.first.name);
      await tester.enterText(find.byKey(const Key('beneficiary')), 'คนรับ');
      await tapAndSettle(tester, find.byKey(const Key('terms')));
      await tapAndSettle(tester, find.text('ชำระเงิน 1,200 บาท'));
      await tester.tap(find.text('ยืนยัน'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tapAndSettle(tester, find.text('กลับเมนูหลัก'));
      await tapAndSettle(tester, find.byTooltip('ออกจากระบบ'));

      await verify(tester, api,
          person: const Person(
              firstName: 'คนใหม่', citizenId: '9000000000004'));
      expect(find.text('0 ฉบับ'), findsOneWidget);
    });
  });
}
