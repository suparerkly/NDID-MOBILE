import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ndid_mobile/main.dart';

/// พิมพ์ SHOT ชื่อหน้า ให้สคริปต์ฝั่งเครื่องถ่ายภาพหน้าจอระหว่างที่หน้านิ่ง
Future<void> shot(WidgetTester tester, String name) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  debugPrint('SHOT $name');
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(
      find.byType(SingleChildScrollView).first, const Offset(0, 2000));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture every screen of the app', (tester) async {
    await tester.pumpWidget(const NdidSimApp());
    await shot(tester, 'a1_welcome');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.tap(find.byType(CheckboxListTile));
    await shot(tester, 'a2_welcome_consented');
    await tapText(tester, 'เริ่มยืนยันตัวตน');

    await waitFor(tester, find.byKey(const Key('firstName')));
    await shot(tester, 'a3_form_empty');
    await tapText(tester, 'ถัดไป');
    await tester.pump(const Duration(seconds: 1));
    await scrollToTop(tester);
    await shot(tester, 'a4_form_errors');
    await tapText(tester, 'กรอกข้อมูลตัวอย่าง');
    await scrollToTop(tester);
    await shot(tester, 'a5_form_filled');
    await tapText(tester, 'ถัดไป');

    await waitFor(tester, find.text('ถัดไป: ตรวจสอบใบหน้า'));
    await shot(tester, 'a6_provider');
    await tapText(tester, 'ธนาคารสมมติ บี');
    await shot(tester, 'a7_provider_selected');
    await tapText(tester, 'ถัดไป: ตรวจสอบใบหน้า');

    await waitFor(tester, find.textContaining('ไม่พบใบหน้า'));
    await shot(tester, 'a8_face_scan');
    await tapText(tester, 'ข้ามการสแกน (เฉพาะ debug build)');
    await tester.pump(const Duration(milliseconds: 600));
    debugPrint('SHOT a9_face_submitting');

    await waitFor(tester, find.text('ยืนยันตัวตนสำเร็จ'));
    await shot(tester, 'a10_success_popup');
    await tapText(tester, 'ไปที่เมนูประกัน');

    await waitFor(tester, find.text('ซื้อประกันออนไลน์'));
    await shot(tester, 'b1_home');
    await tapText(tester, 'กรมธรรม์ของฉัน');
    await waitFor(tester, find.text('ยังไม่มีกรมธรรม์'));
    await shot(tester, 'c0_policies_empty');
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    await tapText(tester, 'ซื้อประกันออนไลน์');
    await waitFor(tester, find.text('เลือกแบบประกัน'));
    await shot(tester, 'b2_plans');
    await tapText(tester, 'ประกันสุขภาพ อุ่นใจ');
    await shot(tester, 'b3_plan_expanded');
    await tapText(tester, 'ประกันอุบัติเหตุ พร้อมคุ้ม');
    await tester.pump(const Duration(seconds: 1));
    await tapText(tester, 'ซื้อแบบนี้');

    await waitFor(tester, find.byKey(const Key('beneficiary')));
    await shot(tester, 'b4_purchase_top');
    await tapText(tester, 'ชำระเงิน 1,200 บาท');
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, 'b5_purchase_errors');
    await tester.enterText(
        find.byKey(const Key('beneficiary')), 'สมหญิง ทดสอบ');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('terms')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('terms')));
    await shot(tester, 'b6_purchase_filled');
    await tapText(tester, 'ชำระเงิน 1,200 บาท');
    await waitFor(tester, find.text('ยืนยันการชำระเงิน'));
    await shot(tester, 'b7_confirm');
    await tapText(tester, 'ยืนยัน');

    await waitFor(tester, find.text('ซื้อประกันสำเร็จ'));
    await shot(tester, 'b8_purchased');
    await tapText(tester, 'กลับเมนูหลัก');

    await waitFor(tester, find.text('1 ฉบับ'));
    await shot(tester, 'c1_home_with_policy');
    await tapText(tester, 'กรมธรรม์ของฉัน');
    await waitFor(tester, find.textContaining('เลขที่'));
    await shot(tester, 'c2_policies');
    await tapText(tester, 'ประกันอุบัติเหตุ พร้อมคุ้ม');
    await waitFor(tester, find.text('รายละเอียดกรมธรรม์'));
    await shot(tester, 'c3_policy_detail');
    debugPrint('TOUR COMPLETE');
  });
}
