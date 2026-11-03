import { PrismaClient } from '@prisma/client';

import { createApp } from './app.js';

// เซิร์ฟเวอร์จำลองสำหรับพัฒนาเท่านั้น ไม่มีการยืนยันสิทธิ์ผู้เรียก
// จึงฟังเฉพาะ 127.0.0.1 เว้นแต่ตั้ง HOST เอง
const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? '127.0.0.1';

const prisma = new PrismaClient();
const app = createApp(prisma);

app.listen(PORT, HOST, () => {
  console.log(`Mock server listening on http://${HOST}:${PORT}`);
});
