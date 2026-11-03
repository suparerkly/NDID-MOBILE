import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// แบบประกันตัวอย่าง ไม่ใช่ผลิตภัณฑ์จริง
const plans = [
  {
    id: 'PA',
    name: 'ประกันอุบัติเหตุ พร้อมคุ้ม',
    summary: 'คุ้มครองอุบัติเหตุทั่วไป 24 ชั่วโมง',
    icon: 'accident',
    yearlyPremium: 1200,
    sumInsured: 500000,
    minAge: 18,
    maxAge: 70,
    benefits: [
      'เสียชีวิตหรือทุพพลภาพจากอุบัติเหตุ 500,000 บาท',
      'ค่ารักษาพยาบาลต่ออุบัติเหตุ 30,000 บาท',
      'ค่าชดเชยรายวันเมื่อนอนโรงพยาบาล 500 บาท',
    ],
  },
  {
    id: 'HL',
    name: 'ประกันสุขภาพ อุ่นใจ',
    summary: 'ค่ารักษาผู้ป่วยในสำหรับโรคทั่วไป',
    icon: 'health',
    yearlyPremium: 8900,
    sumInsured: 1000000,
    minAge: 20,
    maxAge: 60,
    benefits: [
      'ค่ารักษาผู้ป่วยใน สูงสุด 1,000,000 บาทต่อปี',
      'ค่าห้องผู้ป่วย 3,000 บาทต่อวัน',
      'ตรวจสุขภาพประจำปี 1 ครั้ง',
    ],
  },
  {
    id: 'TR',
    name: 'ประกันเดินทาง สบายใจ',
    summary: 'คุ้มครองการเดินทางในประเทศตลอดปี',
    icon: 'travel',
    yearlyPremium: 690,
    sumInsured: 300000,
    minAge: 18,
    maxAge: 75,
    benefits: [
      'อุบัติเหตุระหว่างเดินทาง 300,000 บาท',
      'ค่ารักษาพยาบาลจากการเดินทาง 20,000 บาท',
      'กระเป๋าเดินทางสูญหาย 5,000 บาท',
    ],
  },
];

for (const [sortOrder, { benefits, ...plan }] of plans.entries()) {
  const data = { ...plan, sortOrder };
  await prisma.insurancePlan.upsert({
    where: { id: plan.id },
    create: data,
    update: data,
  });
  await prisma.planBenefit.deleteMany({ where: { planId: plan.id } });
  await prisma.planBenefit.createMany({
    data: benefits.map((text, position) => ({ planId: plan.id, position, text })),
  });
}

console.log(`Seeded ${plans.length} insurance plans`);
await prisma.$disconnect();
