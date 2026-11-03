import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/insurance.dart';
import '../models/user_profile.dart';
import 'mock_ndid_service.dart';

/// ที่อยู่ของเซิร์ฟเวอร์จำลองในโฟลเดอร์ server/
/// เปลี่ยนได้ด้วย --dart-define=API_BASE_URL=http://192.168.1.10:3000
String get defaultApiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  // อีมูเลเตอร์ Android เข้าถึงเครื่องที่รันอยู่ผ่าน 10.0.2.2
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://127.0.0.1:3000';
}

class ApiException implements Exception {
  const ApiException(this.message);

  /// ข้อความภาษาไทยสำหรับแสดงผู้ใช้
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// ช่องทางอ่านและบันทึกข้อมูลของแอป
abstract interface class AppApi {
  Future<List<InsurancePlan>> fetchPlans();

  /// บันทึกผู้ใช้และผลยืนยันตัวตน แล้วคืนรหัสผู้ใช้ในฐานข้อมูล
  Future<int> saveVerification(
    UserProfile profile,
    IdentityProvider idp,
    NdidResult result,
  );

  Future<List<Policy>> fetchPolicies(int userId);

  Future<Policy> createPolicy(
    int userId, {
    required String planId,
    required String beneficiaryName,
    required String beneficiaryRelation,
    required String paymentMethod,
  });
}

/// เรียก API ของเซิร์ฟเวอร์จำลอง (Prisma + SQLite)
class HttpAppApi implements AppApi {
  HttpAppApi({required String baseUrl, http.Client? client})
      : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 10);

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<List<InsurancePlan>> fetchPlans() async {
    final json = await _send('GET', '/api/plans') as List<dynamic>;
    return [
      for (final plan in json)
        InsurancePlan.fromJson(plan as Map<String, dynamic>),
    ];
  }

  @override
  Future<int> saveVerification(
    UserProfile profile,
    IdentityProvider idp,
    NdidResult result,
  ) async {
    final json = await _send('POST', '/api/verifications', {
      'profile': profile.toJson(),
      'idp': {'id': idp.id, 'name': idp.name},
      'referenceId': result.referenceId,
      'verifiedAt': result.verifiedAt.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return json['userId'] as int;
  }

  @override
  Future<List<Policy>> fetchPolicies(int userId) async {
    final json =
        await _send('GET', '/api/users/$userId/policies') as List<dynamic>;
    return [
      for (final policy in json)
        Policy.fromJson(policy as Map<String, dynamic>),
    ];
  }

  @override
  Future<Policy> createPolicy(
    int userId, {
    required String planId,
    required String beneficiaryName,
    required String beneficiaryRelation,
    required String paymentMethod,
  }) async {
    final json = await _send('POST', '/api/users/$userId/policies', {
      'planId': planId,
      'beneficiaryName': beneficiaryName,
      'beneficiaryRelation': beneficiaryRelation,
      'paymentMethod': paymentMethod,
    }) as Map<String, dynamic>;
    return Policy.fromJson(json);
  }

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, _baseUri.resolve(path));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException('เซิร์ฟเวอร์จำลองไม่ตอบสนอง กรุณาลองอีกครั้ง');
    } on http.ClientException {
      throw const ApiException(
        'เชื่อมต่อเซิร์ฟเวอร์จำลองไม่ได้ ตรวจว่าเปิดเซิร์ฟเวอร์ในโฟลเดอร์ server แล้ว',
      );
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      debugPrint('API $method $path failed: ${response.statusCode} $text');
      throw ApiException(switch (response.statusCode) {
        422 => 'อายุไม่อยู่ในเกณฑ์รับประกันของแบบนี้',
        404 => 'ไม่พบข้อมูลในเซิร์ฟเวอร์จำลอง กรุณาเริ่มยืนยันตัวตนใหม่',
        _ => 'บันทึกข้อมูลไม่สำเร็จ (${response.statusCode}) กรุณาลองอีกครั้ง',
      });
    }
    return jsonDecode(text);
  }
}
