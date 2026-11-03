import 'package:flutter/material.dart';
import 'package:ndid_mobile/models/insurance.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/services/api_client.dart';
import 'package:ndid_mobile/services/mock_ndid_service.dart';

/// แบบประกันชุดเดียวกับ server/prisma/seed.js
const testPlans = <InsurancePlan>[
  InsurancePlan(
    id: 'PA',
    name: 'ประกันอุบัติเหตุ พร้อมคุ้ม',
    summary: 'คุ้มครองอุบัติเหตุทั่วไป 24 ชั่วโมง',
    icon: Icons.personal_injury_outlined,
    yearlyPremium: 1200,
    sumInsured: 500000,
    benefits: [
      'เสียชีวิตหรือทุพพลภาพจากอุบัติเหตุ 500,000 บาท',
      'ค่ารักษาพยาบาลต่ออุบัติเหตุ 30,000 บาท',
      'ค่าชดเชยรายวันเมื่อนอนโรงพยาบาล 500 บาท',
    ],
    minAge: 18,
    maxAge: 70,
  ),
  InsurancePlan(
    id: 'HL',
    name: 'ประกันสุขภาพ อุ่นใจ',
    summary: 'ค่ารักษาผู้ป่วยในสำหรับโรคทั่วไป',
    icon: Icons.favorite_border,
    yearlyPremium: 8900,
    sumInsured: 1000000,
    benefits: [
      'ค่ารักษาผู้ป่วยใน สูงสุด 1,000,000 บาทต่อปี',
      'ค่าห้องผู้ป่วย 3,000 บาทต่อวัน',
      'ตรวจสุขภาพประจำปี 1 ครั้ง',
    ],
    minAge: 20,
    maxAge: 60,
  ),
  InsurancePlan(
    id: 'TR',
    name: 'ประกันเดินทาง สบายใจ',
    summary: 'คุ้มครองการเดินทางในประเทศตลอดปี',
    icon: Icons.luggage_outlined,
    yearlyPremium: 690,
    sumInsured: 300000,
    benefits: [
      'อุบัติเหตุระหว่างเดินทาง 300,000 บาท',
      'ค่ารักษาพยาบาลจากการเดินทาง 20,000 บาท',
      'กระเป๋าเดินทางสูญหาย 5,000 บาท',
    ],
    minAge: 18,
    maxAge: 75,
  ),
];

/// แทนเซิร์ฟเวอร์จำลองในการทดสอบ เก็บข้อมูลในหน่วยความจำ
class FakeAppApi implements AppApi {
  final _users = <String, int>{};
  final _profiles = <int, UserProfile>{};
  final _policies = <int, List<Policy>>{};

  @override
  Future<List<InsurancePlan>> fetchPlans() async => testPlans;

  @override
  Future<int> saveVerification(
    UserProfile profile,
    IdentityProvider idp,
    NdidResult result,
  ) async {
    final id = _users.putIfAbsent(profile.citizenId, () => _users.length + 1);
    _profiles[id] = profile;
    return id;
  }

  @override
  Future<List<Policy>> fetchPolicies(int userId) async =>
      List.of(_policies[userId] ?? const []);

  @override
  Future<Policy> createPolicy(
    int userId, {
    required String planId,
    required String beneficiaryName,
    required String beneficiaryRelation,
    required String paymentMethod,
  }) async {
    final now = DateTime.now();
    final policy = Policy(
      number: '$planId-${now.year}-000001',
      plan: testPlans.firstWhere((p) => p.id == planId),
      holderName: _profiles[userId]!.fullName,
      beneficiaryName: beneficiaryName,
      beneficiaryRelation: beneficiaryRelation,
      paymentMethod: paymentMethod,
      startDate: now,
      endDate: DateTime(now.year + 1, now.month, now.day),
    );
    _policies.putIfAbsent(userId, () => []).insert(0, policy);
    return policy;
  }
}
