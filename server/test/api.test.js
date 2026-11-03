// เทสต์ API ของเซิร์ฟเวอร์จำลองกับฐานข้อมูลจริง (SQLite ชั่วคราว)
// รันด้วย npm --prefix server test ซึ่งสร้างฐานข้อมูลใหม่พร้อมแบบประกันตัวอย่างทุกครั้ง
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { PrismaClient } from '@prisma/client';

import { createApp } from '../src/app.js';

const prisma = new PrismaClient();
let server;
let baseUrl;

before(async () => {
  server = createApp(prisma).listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  await prisma.$disconnect();
});

async function call(method, path, body) {
  const res = await fetch(baseUrl + path, {
    method,
    headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, headers: res.headers, json: text ? JSON.parse(text) : null };
}

let refCounter = 0;
/** คำขอยืนยันตัวตนที่ถูกต้อง แก้บางช่องได้ผ่าน overrides */
function verificationBody({ profile = {}, ...overrides } = {}) {
  refCounter += 1;
  return {
    profile: {
      title: 'นาย',
      firstName: 'ทดสอบ',
      lastName: 'ระบบ',
      citizenId: '1101700230678',
      birthDate: '1990-01-01',
      phone: '0812345678',
      email: 'test@example.com',
      ...profile,
    },
    idp: { id: 'idp-a', name: 'ธนาคารสมมติ เอ' },
    referenceId: `SIM-TEST-${Date.now()}-${refCounter}`,
    verifiedAt: new Date().toISOString(),
    ...overrides,
  };
}

function birthDateForAge(age) {
  const d = new Date();
  return `${d.getUTCFullYear() - age}-01-01`;
}

const purchaseBody = {
  planId: 'PA',
  beneficiaryName: 'สมหญิง ทดสอบ',
  beneficiaryRelation: 'คู่สมรส',
  paymentMethod: 'QR พร้อมเพย์ (จำลอง)',
};

describe('health และ CORS', () => {
  test('GET /api/health ตอบ ok', async () => {
    const res = await call('GET', '/api/health');
    assert.equal(res.status, 200);
    assert.deepEqual(res.json, { ok: true });
  });

  test('preflight OPTIONS ตอบ 204 พร้อม header CORS', async () => {
    const res = await call('OPTIONS', '/api/plans');
    assert.equal(res.status, 204);
    assert.equal(res.headers.get('access-control-allow-origin'), '*');
    assert.match(res.headers.get('access-control-allow-methods'), /POST/);
  });
});

describe('GET /api/plans', () => {
  test('คืนแบบประกันตัวอย่าง 3 แบบตามลำดับ พร้อมสิทธิประโยชน์', async () => {
    const res = await call('GET', '/api/plans');
    assert.equal(res.status, 200);
    assert.deepEqual(res.json.map((p) => p.id), ['PA', 'HL', 'TR']);
    const pa = res.json[0];
    assert.equal(pa.yearlyPremium, 1200);
    assert.equal(pa.minAge, 18);
    assert.equal(pa.maxAge, 70);
    assert.equal(pa.benefits.length, 3);
    assert.equal(typeof pa.benefits[0], 'string');
    assert.equal(pa.sortOrder, undefined, 'ไม่ควรส่งฟิลด์ภายใน sortOrder');
  });
});

describe('POST /api/verifications', () => {
  test('สร้างผู้ใช้ใหม่และคืน userId (201)', async () => {
    const res = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId: '1000000000001' } }));
    assert.equal(res.status, 201);
    assert.equal(typeof res.json.userId, 'number');
    const verifications = await prisma.verification.count({ where: { userId: res.json.userId } });
    assert.equal(verifications, 1);
  });

  test('เลขบัตรเดิมได้ userId เดิมและอัปเดตข้อมูลล่าสุด', async () => {
    const citizenId = '1000000000002';
    const first = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId } }));
    const second = await call(
      'POST',
      '/api/verifications',
      verificationBody({ profile: { citizenId, firstName: 'ชื่อใหม่' } }),
    );
    assert.equal(second.status, 201);
    assert.equal(second.json.userId, first.json.userId);
    const user = await prisma.user.findUnique({ where: { citizenId } });
    assert.equal(user.firstName, 'ชื่อใหม่');
    assert.equal(await prisma.verification.count({ where: { userId: user.id } }), 2);
  });

  const invalidCases = [
    ['เลขบัตรไม่ครบ 13 หลัก', verificationBody({ profile: { citizenId: '12345' } })],
    ['ไม่มีชื่อ', verificationBody({ profile: { firstName: '  ' } })],
    ['วันเกิดไม่ใช่วันที่', verificationBody({ profile: { birthDate: 'not-a-date' } })],
    ['ไม่มี idp', { ...verificationBody(), idp: undefined }],
    ['ไม่มี referenceId', { ...verificationBody(), referenceId: '' }],
    ['ไม่มี profile', { idp: { id: 'x', name: 'y' } }],
  ];
  for (const [name, body] of invalidCases) {
    test(`ข้อมูลไม่ถูกต้อง: ${name} → 400`, async () => {
      const res = await call('POST', '/api/verifications', body);
      assert.equal(res.status, 400);
      assert.equal(typeof res.json.error, 'string');
    });
  }

  test('JSON เสีย → 400', async () => {
    const res = await call('POST', '/api/verifications', '{bad json');
    assert.equal(res.status, 400);
  });

  test('referenceId ซ้ำ → 500 และไม่สร้างผู้ใช้ค้าง (transaction)', async () => {
    const body = verificationBody({ profile: { citizenId: '1000000000003' } });
    assert.equal((await call('POST', '/api/verifications', body)).status, 201);
    const dup = verificationBody({ profile: { citizenId: '1000000000004' } });
    dup.referenceId = body.referenceId;
    const res = await call('POST', '/api/verifications', dup);
    assert.equal(res.status, 500);
    assert.equal(await prisma.user.findUnique({ where: { citizenId: '1000000000004' } }), null);
  });
});

describe('กรมธรรม์', () => {
  test('ซื้อแล้วได้กรมธรรม์ (201) เลขที่ตามรูปแบบ และคุ้มครอง 1 ปี', async () => {
    const { json } = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId: '1000000000005' } }));
    const res = await call('POST', `/api/users/${json.userId}/policies`, purchaseBody);
    assert.equal(res.status, 201);
    const year = new Date().getFullYear();
    assert.match(res.json.number, new RegExp(`^PA-${year}-\\d{6}$`));
    assert.equal(res.json.holderName, 'นายทดสอบ ระบบ');
    assert.equal(res.json.beneficiaryName, purchaseBody.beneficiaryName);
    assert.equal(res.json.plan.id, 'PA');
    assert.ok(Array.isArray(res.json.plan.benefits));
    const start = new Date(res.json.startDate);
    const end = new Date(res.json.endDate);
    assert.equal(end.getFullYear() - start.getFullYear(), 1);
    assert.equal(res.json.userId, undefined, 'ไม่ควรส่ง userId ภายใน');
  });

  test('รายการกรมธรรม์เรียงล่าสุดก่อน', async () => {
    const { json } = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId: '1000000000006' } }));
    await call('POST', `/api/users/${json.userId}/policies`, { ...purchaseBody, planId: 'PA' });
    await call('POST', `/api/users/${json.userId}/policies`, { ...purchaseBody, planId: 'TR' });
    const res = await call('GET', `/api/users/${json.userId}/policies`);
    assert.equal(res.status, 200);
    assert.deepEqual(res.json.map((p) => p.plan.id), ['TR', 'PA']);
  });

  test('ผู้ใช้ที่ยังไม่มีกรมธรรม์ได้รายการว่าง', async () => {
    const { json } = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId: '1000000000007' } }));
    const res = await call('GET', `/api/users/${json.userId}/policies`);
    assert.deepEqual(res.json, []);
  });

  test('อายุต่ำกว่าเกณฑ์ → 422 (ยังไม่ถึง 20 ปีซื้อ HL ไม่ได้)', async () => {
    const { json } = await call(
      'POST',
      '/api/verifications',
      verificationBody({ profile: { citizenId: '1000000000008', birthDate: birthDateForAge(19) } }),
    );
    const res = await call('POST', `/api/users/${json.userId}/policies`, { ...purchaseBody, planId: 'HL' });
    assert.equal(res.status, 422);
  });

  test('อายุเกินเกณฑ์ → 422 (อายุ 72 ปีซื้อ PA ไม่ได้ แต่ซื้อ TR ได้)', async () => {
    const { json } = await call(
      'POST',
      '/api/verifications',
      verificationBody({ profile: { citizenId: '1000000000009', birthDate: birthDateForAge(72) } }),
    );
    assert.equal((await call('POST', `/api/users/${json.userId}/policies`, purchaseBody)).status, 422);
    assert.equal((await call('POST', `/api/users/${json.userId}/policies`, { ...purchaseBody, planId: 'TR' })).status, 201);
  });

  test('ไม่พบผู้ใช้ → 404', async () => {
    const res = await call('POST', '/api/users/999999/policies', purchaseBody);
    assert.equal(res.status, 404);
    assert.equal(res.json.error, 'user not found');
  });

  test('ไม่พบแบบประกัน → 404', async () => {
    const { json } = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId: '1000000000010' } }));
    const res = await call('POST', `/api/users/${json.userId}/policies`, { ...purchaseBody, planId: 'XX' });
    assert.equal(res.status, 404);
    assert.equal(res.json.error, 'plan not found');
  });

  test('ไม่มีชื่อผู้รับผลประโยชน์ → 400', async () => {
    const { json } = await call('POST', '/api/verifications', verificationBody({ profile: { citizenId: '1000000000011' } }));
    const res = await call('POST', `/api/users/${json.userId}/policies`, { ...purchaseBody, beneficiaryName: '' });
    assert.equal(res.status, 400);
  });

  for (const badId of ['abc', '0', '-1', '1.5']) {
    test(`userId ไม่ถูกต้อง (${badId}) → 400`, async () => {
      assert.equal((await call('GET', `/api/users/${badId}/policies`)).status, 400);
    });
  }
});
