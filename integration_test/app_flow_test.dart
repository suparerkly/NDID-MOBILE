import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ndid_mobile/main.dart';

/// รันบนอีมูเลเตอร์ที่ไม่มีใบหน้าให้ตรวจ จึงตรวจว่า ML Kit รับภาพจากกล้องได้
/// (ขึ้นข้อความ "ไม่พบใบหน้า") แล้วใช้ปุ่มข้ามใน debug build เพื่อไปต่อ
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> hold(WidgetTester tester, String name, int seconds) async {
  debugPrint('HOLD $name');
  for (var i = 0; i < seconds * 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await pumpUntilFound(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full flow from consent to buying a policy', (tester) async {
    await tester.pumpWidget(const NdidSimApp());
    await hold(tester, 'welcome', 6);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tapText(tester, 'เริ่มยืนยันตัวตน');

    await pumpUntilFound(tester, find.byKey(const Key('firstName')));
    await tapText(tester, 'กรอกข้อมูลตัวอย่าง');
    await hold(tester, 'form', 6);
    await tapText(tester, 'ถัดไป');

    await pumpUntilFound(tester, find.text('ถัดไป: ตรวจสอบใบหน้า'));
    await hold(tester, 'idp', 6);
    await tapText(tester, 'ถัดไป: ตรวจสอบใบหน้า');

    // ข้อความนี้ขึ้นเมื่อ ML Kit ประมวลผลเฟรมจากกล้องจริงแล้วเท่านั้น
    await pumpUntilFound(tester, find.textContaining('ไม่พบใบหน้า'));
    await hold(tester, 'face', 10);
    await tapText(tester, 'ข้ามการสแกน (เฉพาะ debug build)');

    await pumpUntilFound(tester, find.text('ยืนยันตัวตนสำเร็จ'));
    await hold(tester, 'dialog', 8);
    await tapText(tester, 'ไปที่เมนูประกัน');

    await pumpUntilFound(tester, find.text('ซื้อประกันออนไลน์'));
    await hold(tester, 'home', 6);
    await tapText(tester, 'ซื้อประกันออนไลน์');
    await pumpUntilFound(tester, find.text('เลือกแบบประกัน'));
    await hold(tester, 'plans', 6);
    await tapText(tester, 'ซื้อแบบนี้');

    await pumpUntilFound(tester, find.byKey(const Key('beneficiary')));
    await tester.enterText(
        find.byKey(const Key('beneficiary')), 'สมหญิง ทดสอบ');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('terms')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('terms')));
    await hold(tester, 'purchase', 6);
    await tapText(tester, 'ชำระเงิน 1,200 บาท');
    await tapText(tester, 'ยืนยัน');

    await pumpUntilFound(tester, find.text('ซื้อประกันสำเร็จ'));
    await hold(tester, 'policy', 8);
    await tapText(tester, 'กลับเมนูหลัก');
    await pumpUntilFound(tester, find.text('1 ฉบับ'));
    debugPrint('FLOW COMPLETE');
  });
}
