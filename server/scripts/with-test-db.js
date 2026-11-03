// รันคำสั่งกับฐานข้อมูลเทสต์ใหม่ทุกครั้ง: สร้าง SQLite ในโฟลเดอร์ชั่วคราวที่เพิ่งสร้าง
// ใส่โครงสร้างตารางและแบบประกันตัวอย่าง รันคำสั่ง แล้วลบโฟลเดอร์นั้นทิ้ง
// ไม่แตะ prisma/dev.db และไม่ต้องล้างฐานข้อมูลเดิม
//
// ใช้: node scripts/with-test-db.js <คำสั่ง> [อาร์กิวเมนต์...]
// ถ้าสคริปต์นี้ถูกสั่งหยุด (SIGTERM/SIGINT) จะส่งต่อไปให้คำสั่งลูก แล้วลบฐานข้อมูลชั่วคราวก่อนจบ
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error('usage: node scripts/with-test-db.js <command> [args...]');
  process.exit(2);
}

const dir = mkdtempSync(join(tmpdir(), 'ndid-test-db-'));
const env = { ...process.env, DATABASE_URL: `file:${join(dir, 'test.db')}` };
const cleanup = () => rmSync(dir, { recursive: true, force: true });

function runSync(cmd, cmdArgs) {
  return spawnSync(cmd, cmdArgs, { stdio: 'inherit', env }).status ?? 1;
}

let status = runSync('npx', ['prisma', 'db', 'push', '--skip-generate']);
if (status === 0) status = runSync('node', ['prisma/seed.js']);
if (status !== 0) {
  cleanup();
  process.exit(status);
}

const child = spawn(command, args, { stdio: 'inherit', env });
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => child.kill(signal));
}
child.on('exit', (code, signal) => {
  cleanup();
  process.exit(code ?? (signal ? 0 : 1));
});
