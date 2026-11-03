import 'package:flutter/material.dart';

import '../models/insurance.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'mock_ndid_service.dart';

/// สถานะของแอป ข้อมูลผู้ใช้ ผลยืนยันตัวตน และกรมธรรม์บันทึกในฐานข้อมูลของเซิร์ฟเวอร์จำลอง
class AppState extends ChangeNotifier {
  AppState({required this.api});

  final AppApi api;

  UserProfile? profile;
  NdidResult? ndidResult;
  int? _userId;
  List<InsurancePlan>? _plans;
  final List<Policy> policies = [];

  Future<List<InsurancePlan>> loadPlans() async =>
      _plans ??= await api.fetchPlans();

  /// บันทึกผลยืนยันตัวตน แล้วโหลดกรมธรรม์ที่ผู้ใช้เลขบัตรนี้เคยซื้อไว้
  Future<void> completeVerification(
    UserProfile user,
    IdentityProvider idp,
    NdidResult result,
  ) async {
    final userId = await api.saveVerification(user, idp, result);
    final saved = await api.fetchPolicies(userId);
    profile = user;
    ndidResult = result;
    _userId = userId;
    policies
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  Future<Policy> purchase({
    required InsurancePlan plan,
    required String beneficiaryName,
    required String beneficiaryRelation,
    required String paymentMethod,
  }) async {
    final policy = await api.createPolicy(
      _userId!,
      planId: plan.id,
      beneficiaryName: beneficiaryName,
      beneficiaryRelation: beneficiaryRelation,
      paymentMethod: paymentMethod,
    );
    policies.insert(0, policy);
    notifyListeners();
    return policy;
  }

  /// ล้างข้อมูลในแอป ข้อมูลในฐานข้อมูลจำลองยังอยู่ ล้างได้ด้วย npm run db:reset
  void signOut() {
    profile = null;
    ndidResult = null;
    _userId = null;
    policies.clear();
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;

  /// อ่านโดยไม่ rebuild ตาม ใช้ได้ใน initState และ callback
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}
