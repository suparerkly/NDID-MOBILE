import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ndid_mobile/models/user_profile.dart';
import 'package:ndid_mobile/services/api_client.dart';
import 'package:ndid_mobile/services/mock_ndid_service.dart';

const _plan = {
  'id': 'PA',
  'name': 'ประกันอุบัติเหตุ พร้อมคุ้ม',
  'summary': 's',
  'icon': 'accident',
  'yearlyPremium': 1200,
  'sumInsured': 500000,
  'minAge': 18,
  'maxAge': 70,
  'benefits': ['b'],
};

const _policy = {
  'number': 'PA-2026-000001',
  'holderName': 'นายทดสอบ ระบบ',
  'beneficiaryName': 'คนรับ',
  'beneficiaryRelation': 'บุตร',
  'paymentMethod': 'QR พร้อมเพย์ (จำลอง)',
  'startDate': '2026-11-03T00:00:00.000Z',
  'endDate': '2027-11-03T00:00:00.000Z',
  'plan': _plan,
};

final _profile = UserProfile(
  title: 'นาย',
  firstName: 'ทดสอบ',
  lastName: 'ระบบ',
  citizenId: '1101700230678',
  birthDate: DateTime(1990, 1, 1),
  phone: '0812345678',
  email: 'test@example.com',
);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<http.Request> requests;
  HttpAppApi apiReturning(http.Response Function(http.Request) handler) {
    requests = [];
    return HttpAppApi(
      baseUrl: 'http://server.test:3000',
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  test('fetchPlans เรียก GET /api/plans และอ่านภาษาไทยเป็น UTF-8', () async {
    final api = apiReturning((_) => _json([_plan]));
    final plans = await api.fetchPlans();
    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(), 'http://server.test:3000/api/plans');
    expect(plans.single.name, 'ประกันอุบัติเหตุ พร้อมคุ้ม');
  });

  test('saveVerification ส่ง profile, idp, referenceId และเวลาแบบ UTC',
      () async {
    final api = apiReturning((_) => _json({'userId': 42}, 201));
    final userId = await api.saveVerification(
      _profile,
      identityProviders[1],
      NdidResult(
        referenceId: 'SIM-000777',
        idpName: identityProviders[1].name,
        verifiedAt: DateTime.utc(2026, 11, 3, 1, 2, 3),
      ),
    );
    expect(userId, 42);
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/verifications');
    expect(request.headers['Content-Type'], startsWith('application/json'));
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['referenceId'], 'SIM-000777');
    expect(body['verifiedAt'], '2026-11-03T01:02:03.000Z');
    expect(body['idp'], {'id': 'idp-b', 'name': 'ธนาคารสมมติ บี'});
    expect(body['profile']['citizenId'], '1101700230678');
    expect(body['profile']['birthDate'], '1990-01-01');
  });

  test('fetchPolicies เรียก path ของผู้ใช้', () async {
    final api = apiReturning((_) => _json([_policy]));
    final policies = await api.fetchPolicies(7);
    expect(requests.single.url.path, '/api/users/7/policies');
    expect(policies.single.number, 'PA-2026-000001');
  });

  test('createPolicy ส่งข้อมูลการซื้อ', () async {
    final api = apiReturning((_) => _json(_policy, 201));
    final policy = await api.createPolicy(
      7,
      planId: 'PA',
      beneficiaryName: 'คนรับ',
      beneficiaryRelation: 'บุตร',
      paymentMethod: 'QR พร้อมเพย์ (จำลอง)',
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/users/7/policies');
    expect(jsonDecode(requests.single.body), {
      'planId': 'PA',
      'beneficiaryName': 'คนรับ',
      'beneficiaryRelation': 'บุตร',
      'paymentMethod': 'QR พร้อมเพย์ (จำลอง)',
    });
    expect(policy.holderName, 'นายทดสอบ ระบบ');
  });

  group('แปลงข้อผิดพลาดเป็นข้อความภาษาไทย', () {
    Future<String> messageFor(int status) async {
      final api = apiReturning((_) => _json({'error': 'x'}, status));
      try {
        await api.fetchPlans();
      } on ApiException catch (e) {
        return e.message;
      }
      fail('ควร throw ApiException');
    }

    test('422 → อายุไม่อยู่ในเกณฑ์', () async {
      expect(await messageFor(422), 'อายุไม่อยู่ในเกณฑ์รับประกันของแบบนี้');
    });

    test('404 → ให้เริ่มยืนยันตัวตนใหม่', () async {
      expect(await messageFor(404), contains('เริ่มยืนยันตัวตนใหม่'));
    });

    test('500 → บอกรหัสสถานะ', () async {
      expect(await messageFor(500), contains('(500)'));
      expect(await messageFor(400), contains('(400)'));
    });

    test('เชื่อมต่อไม่ได้ → แนะนำให้เปิดเซิร์ฟเวอร์', () async {
      final api = HttpAppApi(
        baseUrl: 'http://server.test:3000',
        client: MockClient((_) async => throw http.ClientException('refused')),
      );
      expect(
        api.fetchPlans(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('เชื่อมต่อเซิร์ฟเวอร์จำลองไม่ได้'))),
      );
    });
  });
}
