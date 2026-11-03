// ตัวช่วยสำหรับขับแอป Flutter web ผ่าน accessibility tree
import { writeFileSync } from 'node:fs';

import { expect } from '@playwright/test';

export const API = 'http://127.0.0.1:3998';

/** เลขบัตรประชาชนสุ่มที่ผ่านเลขตรวจสอบ ใช้แยกผู้ใช้ของแต่ละเทสต์ในฐานข้อมูลเดียวกัน */
export function randomCitizenId() {
  const head = Array.from({ length: 12 }, () => Math.floor(Math.random() * 10)).join('');
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(head[i]) * (13 - i);
  return head + String((11 - (sum % 11)) % 10);
}

/** เปิดแอปและเปิด accessibility tree ของ Flutter (ปกติปิดไว้จนกว่าจะมี screen reader) */
export async function openApp(page) {
  await page.goto('/');
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 30_000 });
  await placeholder.dispatchEvent('click');
  await expect(page.getByText('ยืนยันตัวตนแบบ NDID')).toBeVisible();
}

/** ถ่ายภาพหน้าจอเก็บไว้ทำรายงาน ชื่อไฟล์ = <ไฟล์เทสต์>/<ลำดับ>-<ชื่อ>.png */
export function camera(page, testInfo) {
  let n = 0;
  const shots = [];
  const snap = async (name, caption) => {
    // รอให้ animation ของหน้าใหม่จบก่อนถ่าย
    await page.waitForTimeout(700);
    n += 1;
    const file = testInfo.outputPath(`${String(n).padStart(2, '0')}-${name}.png`);
    await page.screenshot({ path: file });
    shots.push({ file: file.split(/[\\/]/).pop(), name, caption });
    // รายการภาพพร้อมคำอธิบาย ใช้สร้างรายงาน (.claude/skills/ndid-testing/scripts/build_web_report.py)
    writeFileSync(testInfo.outputPath('captions.json'), JSON.stringify({ title: testInfo.title, shots }, null, 2));
    await testInfo.attach(`${String(n).padStart(2, '0')}-${name}`, { path: file, contentType: 'image/png' });
  };
  snap.shots = shots;
  return snap;
}

export const button = (page, name) => page.getByRole('button', { name, exact: true });

/**
 * กด element ของ Flutter semantics: รอให้เห็นก่อน แล้วส่ง DOM click ไปที่ node นั้นตรง ๆ
 * (Flutter web รับ click บน <flt-semantics flt-tappable> เป็น tap) การคลิกด้วยเมาส์จริง
 * ระหว่าง animation เปลี่ยนหน้าจะโดน canvas ของ Flutter บังจนหมดเวลา
 */
export async function press(page, locator) {
  for (let attempt = 1; ; attempt++) {
    try {
      await expect(locator).toBeVisible();
      await locator.scrollIntoViewIfNeeded();
      await page.waitForTimeout(150);
      await locator.dispatchEvent('click');
      return;
    } catch (e) {
      if (attempt >= 4 || !/not attached|detached/i.test(String(e))) throw e;
      await page.waitForTimeout(300);
    }
  }
}

/** กดปุ่มตามชื่อ */
export const tap = (page, name) => press(page, button(page, name));

/** พิมพ์ลงช่องกรอกตามป้ายชื่อ แทนค่าเดิมทั้งหมด แล้วตรวจว่าค่าเข้าไปจริง */
export async function typeInto(page, label, value) {
  const field = page.getByRole('textbox', { name: label });
  await field.scrollIntoViewIfNeeded();
  await field.focus();
  await field.fill(value);
  await expect(field).toHaveValue(value);
}

/** ข้อความบนหน้าจอ (ค้นเฉพาะใน accessibility tree ของ Flutter ไม่รวมข้อความประกาศของ screen reader) */
export function text(page, value) {
  const host = page.locator('flt-semantics-host');
  return typeof value === 'string' ? host.getByText(value, { exact: true }) : host.getByText(value);
}

/** การ์ดที่กดได้ (เมนู แบบประกัน กรมธรรม์) ใช้ InkWell ซึ่งไม่ได้ประกาศ role="button"
 * ใน DOM จึงเป็น <flt-semantics flt-tappable> ที่ข้อความขึ้นต้นด้วยหัวการ์ด */
export function navTile(page, title) {
  const escaped = title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return page.locator('flt-semantics[flt-tappable]').filter({ hasText: new RegExp(`^\\s*${escaped}`) }).first();
}

/** การ์ด "กรมธรรม์ของฉัน" ในเมนูหลัก ข้อความรวมจำนวนฉบับ เช่น "กรมธรรม์ของฉัน 0 ฉบับ" */
export const policyCount = (page) => navTile(page, 'กรมธรรม์ของฉัน');
