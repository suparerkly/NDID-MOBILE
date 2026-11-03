// E2E บนเบราว์เซอร์จริง (Chromium) ของแอปเวอร์ชันเว็บ คุยกับเซิร์ฟเวอร์จำลอง + SQLite จริง
// ถ่ายภาพทุกขั้นไว้ใน test-results/artifacts/<เทสต์>/ สำหรับทำรายงาน
import { test, expect } from '@playwright/test';
import { API, button, camera, navTile, openApp, policyCount, press, randomCitizenId, tap, text, typeInto } from './helpers.mjs';

/** ยินยอม กรอกข้อมูล (ใช้ข้อมูลตัวอย่างแล้วเปลี่ยนชื่อ/เลขบัตร) เลือกธนาคาร จำลองผล ไปเมนูหลัก */
async function verify(page, { firstName, citizenId, idp = 'ธนาคารสมมติ บี' }, snap) {
  await openApp(page);
  await snap?.('welcome', 'หน้าแรก ปุ่มเริ่มยังกดไม่ได้');
  await press(page, page.getByRole('checkbox'));
  await expect(button(page, 'เริ่มยืนยันตัวตน')).toBeEnabled();
  await snap?.('welcome-consented', 'ติ๊กยินยอมแล้ว');
  await tap(page, 'เริ่มยืนยันตัวตน');

  await tap(page, 'กรอกข้อมูลตัวอย่าง');
  await typeInto(page, 'ชื่อ', firstName);
  await typeInto(page, 'เลขบัตรประชาชน 13 หลัก', citizenId);
  await snap?.('form-filled', 'กรอกข้อมูลส่วนตัว');
  await tap(page, 'ถัดไป');

  await press(page, page.getByRole('radio', { name: idp }));
  await snap?.('idp', `เลือก${idp}`);
  await tap(page, 'ถัดไป: ตรวจสอบใบหน้า');

  await expect(text(page, 'เวอร์ชันเว็บไม่มีการตรวจใบหน้า')).toBeVisible();
  await snap?.('face-web', 'เวอร์ชันเว็บไม่มีกล้อง ใช้ปุ่มจำลองผล');
  const saved = page.waitForResponse((r) => r.url().endsWith('/api/verifications'));
  await tap(page, 'จำลองผลการยืนยันตัวตน');
  const response = await saved;
  expect(response.status()).toBe(201);
  const { userId } = await response.json();

  await expect(text(page, 'ยืนยันตัวตนสำเร็จ')).toBeVisible({ timeout: 20_000 });
  await expect(text(page, `นาย${firstName} ทดสอบ`)).toBeVisible();
  await expect(text(page, idp)).toBeVisible();
  await expect(text(page, /^SIM-\d{6}$/)).toBeVisible();
  await snap?.('verified-popup', 'popup ยืนยันตัวตนสำเร็จ');
  await tap(page, 'ไปที่เมนูประกัน');
  await expect(text(page, `สวัสดี ${firstName}`)).toBeVisible();
  return { userId, body: JSON.parse(response.request().postData()) };
}

async function buy(page, { plan, premium, beneficiary, relation, payment }, snap) {
  await press(page, navTile(page, 'ซื้อประกันออนไลน์'));
  await expect(text(page, 'เลือกแบบประกัน')).toBeVisible();
  await snap?.('plans', 'รายการแบบประกันจากเซิร์ฟเวอร์');
  if (plan !== 'ประกันอุบัติเหตุ พร้อมคุ้ม') await press(page, navTile(page, plan));
  await tap(page, 'ซื้อแบบนี้');

  await expect(text(page, plan)).toBeVisible();
  await typeInto(page, 'ชื่อ-นามสกุล', beneficiary);
  if (relation) {
    await press(page, page.getByRole('button', { name: /ความสัมพันธ์/ }));
    await press(page, text(page, relation).last());
  }
  if (payment) await press(page, page.getByRole('radio', { name: payment }));
  await press(page, page.getByRole('checkbox'));
  await snap?.('purchase-filled', 'กรอกผู้รับผลประโยชน์และวิธีชำระเงิน');
  await tap(page, `ชำระเงิน ${premium} บาท`);
  await expect(text(page, 'ยืนยันการชำระเงิน')).toBeVisible();
  await snap?.('confirm', 'หน้ายืนยันการชำระเงิน');
  const created = page.waitForResponse((r) => r.url().endsWith('/policies') && r.request().method() === 'POST');
  await tap(page, 'ยืนยัน');
  expect((await created).status()).toBe(201);
  await expect(text(page, 'ซื้อประกันสำเร็จ')).toBeVisible();
  await snap?.('purchased', 'ซื้อประกันสำเร็จ');
}

test('W1 flow เต็ม: ยืนยันตัวตน → ซื้อประกันเดินทาง → ดูกรมธรรม์ → ออกจากระบบ', async ({ page }, testInfo) => {
  const snap = camera(page, testInfo);
  const citizenId = randomCitizenId();
  const { userId, body } = await verify(page, { firstName: 'เว็บหนึ่ง', citizenId }, snap);
  expect(body.idp).toEqual({ id: 'idp-b', name: 'ธนาคารสมมติ บี' });
  expect(body.profile.citizenId).toBe(citizenId);
  await expect(policyCount(page)).toHaveText(/0 ฉบับ$/);
  await snap('home', 'เมนูหลัก ยังไม่มีกรมธรรม์');

  await buy(page, {
    plan: 'ประกันเดินทาง สบายใจ',
    premium: '690',
    beneficiary: 'สมศรี ทดสอบ',
    relation: 'บุตร',
    payment: 'Mobile Banking (จำลอง)',
  }, snap);
  const year = new Date().getFullYear();
  await expect(text(page, new RegExp(`เลขที่กรมธรรม์\\s*TR-${year}-\\d{6}`))).toBeVisible();
  await expect(text(page, /ผู้รับผลประโยชน์\s*สมศรี ทดสอบ \(บุตร\)/)).toBeVisible();

  await tap(page, 'กลับเมนูหลัก');
  await expect(policyCount(page)).toHaveText(/1 ฉบับ$/);
  await press(page, navTile(page, 'กรมธรรม์ของฉัน'));
  await expect(navTile(page, 'ประกันเดินทาง สบายใจ')).toBeVisible();
  await snap('policies', 'รายการกรมธรรม์');
  await press(page, navTile(page, 'ประกันเดินทาง สบายใจ'));
  await expect(text(page, 'รายละเอียดกรมธรรม์')).toBeVisible();
  await snap('policy-detail', 'รายละเอียดกรมธรรม์');

  // ข้อมูลถูกบันทึกในฐานข้อมูลจริง
  const policies = await (await fetch(`${API}/api/users/${userId}/policies`)).json();
  expect(policies).toHaveLength(1);
  expect(policies[0]).toMatchObject({
    beneficiaryName: 'สมศรี ทดสอบ',
    beneficiaryRelation: 'บุตร',
    paymentMethod: 'Mobile Banking (จำลอง)',
    holderName: 'นายเว็บหนึ่ง ทดสอบ',
    plan: { id: 'TR' },
  });

  await tap(page, 'Back');
  await expect(text(page, 'รายละเอียดกรมธรรม์')).toHaveCount(0);
  await tap(page, 'Back');
  await expect(policyCount(page)).toHaveText(/1 ฉบับ$/);
  await tap(page, 'ออกจากระบบ');
  await expect(button(page, 'เริ่มยืนยันตัวตน')).toBeDisabled();
  await snap('signed-out', 'ออกจากระบบ กลับหน้าแรก');
});

test('W2 ฟอร์มข้อมูลผิด แสดงข้อผิดพลาดและไม่ไปต่อ', async ({ page }, testInfo) => {
  const snap = camera(page, testInfo);
  await openApp(page);
  await press(page, page.getByRole('checkbox'));
  await tap(page, 'เริ่มยืนยันตัวตน');
  await typeInto(page, 'เลขบัตรประชาชน 13 หลัก', '1234567890123');
  await typeInto(page, 'เบอร์มือถือ', '0212345678');
  await typeInto(page, 'อีเมล', 'no-domain@');
  await tap(page, 'ถัดไป');

  for (const error of [
    'กรุณากรอกชื่อ',
    'กรุณากรอกนามสกุล',
    'เลขบัตรประชาชนไม่ถูกต้อง',
    'กรุณาเลือกวันเกิด',
    'เบอร์มือถือต้องขึ้นต้นด้วย 06, 08 หรือ 09 และมี 10 หลัก',
    'รูปแบบอีเมลไม่ถูกต้อง',
  ]) {
    await expect(text(page, error)).toBeVisible();
  }
  await expect(button(page, 'ถัดไป: ตรวจสอบใบหน้า')).toHaveCount(0);
  await snap('form-errors', 'ข้อผิดพลาดครบ 6 ช่อง');
});

test('W3 ซื้อโดยไม่ยอมรับเงื่อนไขไม่ได้ และกดยกเลิกแล้วไม่มีกรมธรรม์', async ({ page }, testInfo) => {
  const snap = camera(page, testInfo);
  const { userId } = await verify(page, { firstName: 'เว็บสาม', citizenId: randomCitizenId() });
  await press(page, navTile(page, 'ซื้อประกันออนไลน์'));
  await tap(page, 'ซื้อแบบนี้');

  await tap(page, 'ชำระเงิน 1,200 บาท');
  await expect(text(page, 'กรุณากรอกชื่อผู้รับผลประโยชน์')).toBeVisible();
  await expect(page.getByRole('checkbox', { name: /กรุณายอมรับเงื่อนไขก่อนชำระเงิน/ })).toBeVisible();
  await typeInto(page, 'ชื่อ-นามสกุล', 'คนรับ');
  await tap(page, 'ชำระเงิน 1,200 บาท');
  await expect(text(page, 'ยืนยันการชำระเงิน')).toHaveCount(0);
  await snap('terms-required', 'ยังไม่ยอมรับเงื่อนไข ไม่เปิดหน้ายืนยัน');

  await press(page, page.getByRole('checkbox'));
  await tap(page, 'ชำระเงิน 1,200 บาท');
  await tap(page, 'ยกเลิก');
  await expect(text(page, 'ยืนยันการชำระเงิน')).toHaveCount(0);
  const policies = await (await fetch(`${API}/api/users/${userId}/policies`)).json();
  expect(policies).toEqual([]);
});

test('W4 ผู้ใช้เดิมกลับมาได้กรมธรรม์จากฐานข้อมูล คนใหม่ไม่เห็น', async ({ page }, testInfo) => {
  const snap = camera(page, testInfo);
  const citizenId = randomCitizenId();
  await verify(page, { firstName: 'เว็บสี่', citizenId });
  await buy(page, { plan: 'ประกันอุบัติเหตุ พร้อมคุ้ม', premium: '1,200', beneficiary: 'คนรับ' });
  await tap(page, 'กลับเมนูหลัก');
  await tap(page, 'ออกจากระบบ');

  // โหลดหน้าใหม่ทั้งหมด สถานะในแอปหายไป ข้อมูลต้องมาจากเซิร์ฟเวอร์เท่านั้น
  await page.reload();
  await verify(page, { firstName: 'เว็บสี่', citizenId, idp: 'ธนาคารสมมติ ซี' });
  await expect(policyCount(page)).toHaveText(/1 ฉบับ$/);
  await snap('returning-user', 'ผู้ใช้เดิมกลับมา เห็นกรมธรรม์ 1 ฉบับ');

  await tap(page, 'ออกจากระบบ');
  await verify(page, { firstName: 'คนใหม่', citizenId: randomCitizenId() });
  await expect(policyCount(page)).toHaveText(/0 ฉบับ$/);
  await snap('new-user', 'คนใหม่ไม่เห็นกรมธรรม์ของคนก่อน');
});
