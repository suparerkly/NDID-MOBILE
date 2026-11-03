// Playwright E2E ของแอปเวอร์ชันเว็บ (Flutter web) กับเซิร์ฟเวอร์จำลองจริง
//
// ก่อนรันต้อง build เว็บให้ชี้ไปที่พอร์ตเซิร์ฟเวอร์เทสต์ (ดู README หัวข้อการทดสอบ):
//   flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:3998
// Playwright เปิดเซิร์ฟเวอร์จำลองกับฐานข้อมูลชั่วคราว (ไม่แตะ dev.db) และเสิร์ฟ build/web ให้เอง
import { defineConfig } from '@playwright/test';

const API_PORT = 3998;
const WEB_PORT = 8090;

export default defineConfig({
  testDir: './tests',
  // ทุกเทสต์ใช้เซิร์ฟเวอร์ตัวเดียวกัน แต่ใช้เลขบัตรไม่ซ้ำกัน จึงรันต่อกันทีละไฟล์ให้ log อ่านง่าย
  workers: 1,
  timeout: 90_000,
  expect: { timeout: 15_000 },
  reporter: [['list'], ['json', { outputFile: 'test-results/results.json' }]],
  outputDir: 'test-results/artifacts',
  use: {
    // ขนาดจอมือถือ แต่เป็นโหมด desktop (ไม่มี touch) เพราะ Flutter web บนโหมดมือถือ
    // เปิด accessibility tree ด้วยการแตะจากสคริปต์ไม่ได้ และเทสต์ต้องใช้ tree นั้นหาปุ่มและช่องกรอก
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2,
    baseURL: `http://127.0.0.1:${WEB_PORT}`,
    locale: 'th-TH',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: [
    {
      command: `node scripts/with-test-db.js node src/server.js`,
      cwd: '../server',
      env: { PORT: String(API_PORT) },
      url: `http://127.0.0.1:${API_PORT}/api/health`,
      reuseExistingServer: false,
      timeout: 60_000,
      // ส่ง SIGTERM ให้ with-test-db.js ปิดเซิร์ฟเวอร์และลบฐานข้อมูลชั่วคราว (ค่าเริ่มต้นคือ SIGKILL ซึ่งทิ้งไฟล์ไว้)
      gracefulShutdown: { signal: 'SIGTERM', timeout: 5_000 },
    },
    {
      command: `node serve-web.mjs`,
      env: { WEB_PORT: String(WEB_PORT) },
      url: `http://127.0.0.1:${WEB_PORT}/`,
      reuseExistingServer: false,
    },
  ],
});
