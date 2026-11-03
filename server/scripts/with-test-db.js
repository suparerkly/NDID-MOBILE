// รันคำสั่งกับฐานข้อมูลเทสต์ใหม่ทุกครั้ง: สร้าง SQLite ในโฟลเดอร์ชั่วคราวที่เพิ่งสร้าง
// ใส่โครงสร้างตารางและแบบประกันตัวอย่าง รันคำสั่ง แล้วลบโฟลเดอร์นั้นทิ้ง
// ไม่แตะ prisma/dev.db และไม่ต้องล้างฐานข้อมูลเดิม
//
// ใช้: node scripts/with-test-db.js <คำสั่ง> [อาร์กิวเมนต์...]
import { spawnSync } from 'node:child_process';
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

function run(cmd, cmdArgs) {
  const result = spawnSync(cmd, cmdArgs, { stdio: 'inherit', env });
  return result.status ?? 1;
}

let status = run('npx', ['prisma', 'db', 'push', '--skip-generate']);
if (status === 0) status = run('node', ['prisma/seed.js']);
if (status === 0) status = run(command, args);

rmSync(dir, { recursive: true, force: true });
process.exit(status);
