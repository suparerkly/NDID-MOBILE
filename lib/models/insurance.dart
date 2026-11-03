import 'package:flutter/material.dart';

/// ไอคอนตามชื่อที่เก็บในฐานข้อมูล (InsurancePlan.icon)
const _planIcons = <String, IconData>{
  'accident': Icons.personal_injury_outlined,
  'health': Icons.favorite_border,
  'travel': Icons.luggage_outlined,
};

/// แบบประกันตัวอย่าง ไม่ใช่ผลิตภัณฑ์จริง ข้อมูลมาจาก server/prisma/seed.js
class InsurancePlan {
  const InsurancePlan({
    required this.id,
    required this.name,
    required this.summary,
    required this.icon,
    required this.yearlyPremium,
    required this.sumInsured,
    required this.benefits,
    required this.minAge,
    required this.maxAge,
  });

  factory InsurancePlan.fromJson(Map<String, dynamic> json) => InsurancePlan(
        id: json['id'] as String,
        name: json['name'] as String,
        summary: json['summary'] as String,
        icon: _planIcons[json['icon']] ?? Icons.shield_outlined,
        yearlyPremium: json['yearlyPremium'] as int,
        sumInsured: json['sumInsured'] as int,
        benefits: List<String>.from(json['benefits'] as List<dynamic>),
        minAge: json['minAge'] as int,
        maxAge: json['maxAge'] as int,
      );

  final String id;
  final String name;
  final String summary;
  final IconData icon;
  final int yearlyPremium;
  final int sumInsured;
  final List<String> benefits;
  final int minAge;
  final int maxAge;

  bool acceptsAge(int age) => age >= minAge && age <= maxAge;
}

class Policy {
  const Policy({
    required this.number,
    required this.plan,
    required this.holderName,
    required this.beneficiaryName,
    required this.beneficiaryRelation,
    required this.paymentMethod,
    required this.startDate,
    required this.endDate,
  });

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
        number: json['number'] as String,
        plan: InsurancePlan.fromJson(json['plan'] as Map<String, dynamic>),
        holderName: json['holderName'] as String,
        beneficiaryName: json['beneficiaryName'] as String,
        beneficiaryRelation: json['beneficiaryRelation'] as String,
        paymentMethod: json['paymentMethod'] as String,
        startDate: DateTime.parse(json['startDate'] as String).toLocal(),
        endDate: DateTime.parse(json['endDate'] as String).toLocal(),
      );

  final String number;
  final InsurancePlan plan;
  final String holderName;
  final String beneficiaryName;
  final String beneficiaryRelation;
  final String paymentMethod;
  final DateTime startDate;
  final DateTime endDate;
}

const paymentMethods = <String>[
  'QR พร้อมเพย์ (จำลอง)',
  'Mobile Banking (จำลอง)',
  'หักบัญชีธนาคาร (จำลอง)',
];
