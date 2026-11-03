import { randomInt } from 'node:crypto';

import { Prisma } from '@prisma/client';
import express from 'express';

/**
 * สร้างแอป Express ของเซิร์ฟเวอร์จำลอง แยกจาก server.js เพื่อให้เทสต์เรียกได้
 * โดยไม่ต้องเปิดพอร์ตจริง
 * @param {import('@prisma/client').PrismaClient} prisma
 */
export function createApp(prisma) {
  const app = express();

  app.use(express.json({ limit: '32kb' }));

  // แอปเวอร์ชันเว็บรันคนละพอร์ต จึงต้องเปิด CORS
  app.use((req, res, next) => {
    res.set({
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  class BadRequest extends Error {}

  function requireString(body, field) {
    const value = body?.[field];
    if (typeof value !== 'string' || value.trim() === '') {
      throw new BadRequest(`${field} is required`);
    }
    return value.trim();
  }

  function requireDate(body, field) {
    const date = new Date(requireString(body, field));
    if (Number.isNaN(date.getTime()))
      throw new BadRequest(`${field} is not a date`);
    return date;
  }

  function parseId(value) {
    const id = Number(value);
    if (!Number.isInteger(id) || id <= 0) throw new BadRequest('invalid id');
    return id;
  }

  function ageOn(birthDate, date) {
    const hadBirthday =
      date.getUTCMonth() > birthDate.getUTCMonth() ||
      (date.getUTCMonth() === birthDate.getUTCMonth() &&
        date.getUTCDate() >= birthDate.getUTCDate());
    return (
      date.getUTCFullYear() - birthDate.getUTCFullYear() - (hadBirthday ? 0 : 1)
    );
  }

  const planInclude = { benefits: { orderBy: { position: 'asc' } } };

  function toPlanJson({ benefits, sortOrder, ...plan }) {
    return { ...plan, benefits: benefits.map((b) => b.text) };
  }

  function toPolicyJson({
    plan,
    user,
    userId,
    planId,
    createdAt,
    id,
    ...policy
  }) {
    return {
      ...policy,
      holderName: `${user.title}${user.firstName} ${user.lastName}`,
      plan: toPlanJson(plan),
    };
  }

  app.get('/api/health', (req, res) => res.json({ ok: true }));

  app.get('/api/plans', async (req, res) => {
    const plans = await prisma.insurancePlan.findMany({
      include: planInclude,
      orderBy: { sortOrder: 'asc' },
    });
    res.json(plans.map(toPlanJson));
  });

  // บันทึกผลยืนยันตัวตนจำลอง ผู้ใช้เดิม (เลขบัตรเดียวกัน) จะได้ข้อมูลล่าสุดแทน
  app.post('/api/verifications', async (req, res) => {
    const { profile, idp } = req.body ?? {};
    const citizenId = requireString(profile, 'citizenId');
    if (!/^\d{13}$/.test(citizenId))
      throw new BadRequest('citizenId must be 13 digits');
    const user = {
      title: requireString(profile, 'title'),
      firstName: requireString(profile, 'firstName'),
      lastName: requireString(profile, 'lastName'),
      birthDate: requireDate(profile, 'birthDate'),
      phone: requireString(profile, 'phone'),
      email: requireString(profile, 'email'),
    };

    const verification = {
      referenceId: requireString(req.body, 'referenceId'),
      idpId: requireString(idp, 'id'),
      idpName: requireString(idp, 'name'),
      verifiedAt: requireDate(req.body, 'verifiedAt'),
    };

    const saved = await prisma.$transaction(async (tx) => {
      const { id: userId } = await tx.user.upsert({
        where: { citizenId },
        create: { citizenId, ...user },
        update: user,
      });
      await tx.verification.create({ data: { ...verification, userId } });
      return userId;
    });
    res.status(201).json({ userId: saved });
  });

  app.get('/api/users/:userId/policies', async (req, res) => {
    const policies = await prisma.policy.findMany({
      where: { userId: parseId(req.params.userId) },
      include: { plan: { include: planInclude }, user: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json(policies.map(toPolicyJson));
  });

  app.post('/api/users/:userId/policies', async (req, res) => {
    const userId = parseId(req.params.userId);
    const planId = requireString(req.body, 'planId');
    const [user, plan] = await Promise.all([
      prisma.user.findUnique({ where: { id: userId } }),
      prisma.insurancePlan.findUnique({ where: { id: planId } }),
    ]);
    if (!user) return res.status(404).json({ error: 'user not found' });
    if (!plan) return res.status(404).json({ error: 'plan not found' });

    const now = new Date();
    const age = ageOn(user.birthDate, now);
    if (age < plan.minAge || age > plan.maxAge) {
      return res.status(422).json({ error: 'age is outside the plan range' });
    }

    const endDate = new Date(now);
    endDate.setFullYear(now.getFullYear() + 1);
    const data = {
      beneficiaryName: requireString(req.body, 'beneficiaryName'),
      beneficiaryRelation: requireString(req.body, 'beneficiaryRelation'),
      paymentMethod: requireString(req.body, 'paymentMethod'),
      startDate: now,
      endDate,
      userId,
      planId,
    };

    // เลขกรมธรรม์สุ่ม ถ้าซ้ำให้สุ่มใหม่
    for (let attempt = 0; attempt < 5; attempt++) {
      const suffix = String(randomInt(1_000_000)).padStart(6, '0');
      try {
        const policy = await prisma.policy.create({
          data: { ...data, number: `${planId}-${now.getFullYear()}-${suffix}` },
          include: { plan: { include: planInclude }, user: true },
        });
        return res.status(201).json(toPolicyJson(policy));
      } catch (e) {
        const duplicate =
          e instanceof Prisma.PrismaClientKnownRequestError &&
          e.code === 'P2002';
        if (!duplicate) throw e;
      }
    }
    throw new Error('could not allocate a policy number');
  });

  app.use((err, req, res, next) => {
    if (err instanceof BadRequest || err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: err.message });
    }
    console.error(err);
    res.status(500).json({ error: 'internal error' });
  });

  return app;
}
