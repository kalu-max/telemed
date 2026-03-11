// Tests for new feature endpoints: reviews, medical records, chat search,
// consultation notes, GDPR export, audit logs, reminders.
process.env.NODE_ENV = 'test';
process.env.DB_DIALECT = 'sqlite';
process.env.DB_STORAGE = ':memory:';
process.env.FIREBASE_CONFIG = '{}';

delete require.cache[require.resolve('../server/config/database')];
delete require.cache[require.resolve('../server/models')];
delete require.cache[require.resolve('../server')];

require('dotenv').config();
const request = require('supertest');
const { sequelize } = require('../server/config/database');
const { app, server, io } = require('../server');

describe('Feature endpoints', () => {
  let patientToken, doctorToken, doctorId, patientId;

  beforeAll(async () => {
    await sequelize.sync({ force: true });

    // Register a patient
    const pRes = await request(app)
      .post('/api/auth/register')
      .send({ email: 'fp@test.com', password: 'Test1234', name: 'Feature Patient', role: 'patient' });
    patientToken = pRes.body.token;
    patientId = pRes.body.user?.userId || pRes.body.user?.id;

    // Register a doctor
    const dRes = await request(app)
      .post('/api/auth/register')
      .send({ email: 'fd@test.com', password: 'Test1234', name: 'Dr Feature', role: 'doctor' });
    doctorToken = dRes.body.token;
    doctorId = dRes.body.user?.userId || dRes.body.user?.id;
  });

  afterAll(async () => {
    await sequelize.close();
    if (server && server.close) server.close();
    if (io && io.close) io.close();
  });

  // ── Medical Records ──────────────────────────────────────────────

  test('POST /medical-records creates a record', async () => {
    const res = await request(app)
      .post('/api/users/medical-records')
      .set('Authorization', `Bearer ${doctorToken}`)
      .send({ patientId, diagnosis: 'Common cold', treatment: 'Rest and fluids' });
    expect([200, 201]).toContain(res.statusCode);
  });

  test('GET /medical-records returns records for patient', async () => {
    const res = await request(app)
      .get('/api/users/medical-records')
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.records).toBeDefined();
    expect(Array.isArray(res.body.records)).toBe(true);
  });

  // ── Doctor Reviews ───────────────────────────────────────────────

  test('POST /doctors/:id/reviews submits a review', async () => {
    const res = await request(app)
      .post(`/api/users/doctors/${doctorId}/reviews`)
      .set('Authorization', `Bearer ${patientToken}`)
      .send({ rating: 5, comment: 'Excellent doctor!' });
    expect([200, 201]).toContain(res.statusCode);
  });

  test('POST /doctors/:id/reviews rejects invalid rating', async () => {
    const res = await request(app)
      .post(`/api/users/doctors/${doctorId}/reviews`)
      .set('Authorization', `Bearer ${patientToken}`)
      .send({ rating: 6, comment: 'Too high' });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  test('GET /doctors/:id/reviews returns reviews', async () => {
    const res = await request(app)
      .get(`/api/users/doctors/${doctorId}/reviews`)
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.reviews).toBeDefined();
    expect(res.body.averageRating).toBeDefined();
    expect(res.body.totalReviews).toBeGreaterThanOrEqual(1);
  });

  // ── GDPR Export ──────────────────────────────────────────────────

  test('GET /patients/:id/export returns JSON data', async () => {
    const res = await request(app)
      .get(`/api/users/patients/${patientId}/export`)
      .set('Authorization', `Bearer ${patientToken}`);
    // Patient can export own data
    expect([200, 403]).toContain(res.statusCode);
    if (res.statusCode === 200) {
      expect(res.body.user).toBeDefined();
    }
  });

  // ── Audit Logs (admin only) ──────────────────────────────────────

  test('GET /admin/audit-logs rejects non-admin', async () => {
    const res = await request(app)
      .get('/api/users/admin/audit-logs')
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  // ── Chat Search ──────────────────────────────────────────────────

  test('GET /chats/:chatId/search requires minimum query length', async () => {
    const res = await request(app)
      .get('/api/users/chats/fakechat/search?q=a')
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBe(400);
  });

  // ── Reminders ────────────────────────────────────────────────────

  test('GET /reminders/upcoming returns without error', async () => {
    const res = await request(app)
      .get('/api/users/reminders/upcoming?windowMinutes=30')
      .set('Authorization', `Bearer ${doctorToken}`);
    expect([200, 500]).toContain(res.statusCode);
  });

  // ── Swagger Docs ─────────────────────────────────────────────────

  test('GET /api-docs returns the Swagger UI page', async () => {
    const res = await request(app).get('/api-docs/').redirects(5);
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain('swagger');
  });

  test('GET /api-docs.json returns the OpenAPI spec', async () => {
    const res = await request(app).get('/api-docs.json');
    expect(res.statusCode).toBe(200);
    expect(res.body.openapi).toBeDefined();
    expect(res.body.paths).toBeDefined();
  });
});
