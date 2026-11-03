import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/models/insurance.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/widgets/common.dart';

Map<String, dynamic> planJson({String icon = 'accident'}) => {
      'id': 'PA',
      'name': 'ประกันอุบัติเหตุ พร้อมคุ้ม',
      'summary': 'คุ้มครองอุบัติเหตุทั่วไป 24 ชั่วโมง',
      'icon': icon,
      'yearlyPremium': 1200,
      'sumInsured': 500000,
      'minAge': 18,
      'maxAge': 70,
      'benefits': ['ข้อ 1', 'ข้อ 2'],
    };

UserProfile profile({DateTime? birthDate, String citizenId = '1101700230678'}) =>
    UserProfile(
      title: 'นางสาว',
      firstName: 'สมหญิง',
      lastName: 'ทดสอบ',
      citizenId: citizenId,
      birthDate: birthDate ?? DateTime(1990, 3, 7),
      phone: '0812345678',
      email: 'a@example.com',
    );

void main() {
  group('InsurancePlan', () {
    test('fromJson อ่านทุกฟิลด์และแปลงชื่อไอคอน', () {
      final plan = InsurancePlan.fromJson(planJson());
      expect(plan.id, 'PA');
      expect(plan.yearlyPremium, 1200);
      expect(plan.sumInsured, 500000);
      expect(plan.benefits, ['ข้อ 1', 'ข้อ 2']);
      expect(plan.icon, Icons.personal_injury_outlined);
      expect(InsurancePlan.fromJson(planJson(icon: 'health')).icon,
          Icons.favorite_border);
      expect(InsurancePlan.fromJson(planJson(icon: 'travel')).icon,
          Icons.luggage_outlined);
    });

    test('ไอคอนที่ไม่รู้จักใช้ไอคอนโล่แทน', () {
      expect(InsurancePlan.fromJson(planJson(icon: 'unknown')).icon,
          Icons.shield_outlined);
    });

    test('acceptsAge รวมอายุขอบล่างและขอบบน', () {
      final plan = InsurancePlan.fromJson(planJson());
      expect(plan.acceptsAge(17), isFalse);
      expect(plan.acceptsAge(18), isTrue);
      expect(plan.acceptsAge(70), isTrue);
      expect(plan.acceptsAge(71), isFalse);
    });
  });

  group('Policy', () {
    test('fromJson แปลงวันที่ UTC เป็นเวลาเครื่อง', () {
      final policy = Policy.fromJson({
        'number': 'PA-2026-000123',
        'holderName': 'นางสาวสมหญิง ทดสอบ',
        'beneficiaryName': 'สมชาย ทดสอบ',
        'beneficiaryRelation': 'พี่น้อง',
        'paymentMethod': paymentMethods.first,
        'startDate': '2026-11-03T00:00:00.000Z',
        'endDate': '2027-11-03T00:00:00.000Z',
        'plan': planJson(),
      });
      expect(policy.number, 'PA-2026-000123');
      expect(policy.plan.id, 'PA');
      expect(policy.startDate.isUtc, isFalse);
      expect(policy.startDate.toUtc(), DateTime.utc(2026, 11, 3));
      expect(policy.endDate.toUtc(), DateTime.utc(2027, 11, 3));
    });
  });

  group('UserProfile', () {
    test('fullName ต่อคำนำหน้ากับชื่อโดยไม่มีช่องว่าง', () {
      expect(profile().fullName, 'นางสาวสมหญิง ทดสอบ');
    });

    test('maskedCitizenId แสดงเฉพาะหลักแรกและ 3 หลักท้าย', () {
      expect(profile().maskedCitizenId, '1-XXXX-XXXXX-67-8');
    });

    test('toJson ส่งวันเกิดเป็น yyyy-MM-dd โดยไม่มีเวลา', () {
      final json = profile(birthDate: DateTime(1990, 3, 7)).toJson();
      expect(json['birthDate'], '1990-03-07');
      expect(json.keys, containsAll(['title', 'citizenId', 'phone', 'email']));
    });

    test('ageOn นับอายุเพิ่มในวันเกิดพอดี', () {
      final p = profile(birthDate: DateTime(2000, 6, 15));
      expect(p.ageOn(DateTime(2026, 6, 14)), 25);
      expect(p.ageOn(DateTime(2026, 6, 15)), 26);
      expect(p.ageOn(DateTime(2026, 12, 31)), 26);
    });
  });

  group('รูปแบบการแสดงผล', () {
    test('formatBaht ใส่จุลภาคและหน่วยบาท', () {
      expect(formatBaht(1200), '1,200 บาท');
      expect(formatBaht(1000000), '1,000,000 บาท');
      expect(formatBaht(690), '690 บาท');
    });

    test('formatThaiDate ใช้ปี พ.ศ.', () {
      expect(formatThaiDate(DateTime(2026, 11, 3)), '3/11/2569');
    });
  });
}
