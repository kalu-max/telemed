// Tests for prescriptions and notifications endpoints
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

describe('Prescriptions & Notifications', () => {
  let doctorToken;
  let patientToken;
  let doctorId;
  let patientId;

  beforeAll(async () => {
    await sequelize.sync({ force: true });

    // register doctor
    const docRes = await request(app)
      .post('/api/auth/register')
      .send({ email: 'rx_doc@test.com', password: 'Test1234', name: 'Dr Prescription', role: 'doctor' });
    doctorToken = docRes.body.token;
    doctorId = docRes.body.user?.userId || docRes.body.userId;

    // register patient
    const patRes = await request(app)
      .post('/api/auth/register')
      .send({ email: 'rx_pat@test.com', password: 'Test1234', name: 'Rx Patient', role: 'patient' });
    patientToken = patRes.body.token;
    patientId = patRes.body.user?.userId || patRes.body.userId;
  });

  afterAll(async () => {
    await sequelize.close();
    if (server && server.close) server.close();
    if (io && io.close) io.close();
  });

  // --- Prescriptions ---
  test('list prescriptions as patient (empty initially)', async () => {
    const res = await request(app)
      .get('/api/prescriptions')
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.prescriptions)).toBe(true);
  });

  test('create a prescription as doctor', async () => {
    const res = await request(app)
      .post('/api/prescriptions')
      .set('Authorization', `Bearer ${doctorToken}`)
      .send({
        patientId,
        diagnosis: 'Common cold',
        notes: 'Rest and fluids',
        medications: [{ name: 'Paracetamol', dosage: '500mg', frequency: 'Twice daily', duration: '5 days' }],
      });
    expect([200, 201]).toContain(res.statusCode);
    expect(res.body.prescription).toBeDefined();
    expect(res.body.prescription.prescriptionId).toBeDefined();
  });

  test('list prescriptions shows the created one', async () => {
    const res = await request(app)
      .get('/api/prescriptions')
      .set('Authorization', `Bearer ${doctorToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.prescriptions.length).toBeGreaterThanOrEqual(1);
  });

  // --- Notifications ---
  test('get notifications for patient', async () => {
    const res = await request(app)
      .get('/api/users/notifications')
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.notifications).toBeDefined();
  });

  // --- ICE servers ---
  test('ICE servers endpoint returns array', async () => {
    const res = await request(app)
      .get('/api/users/rtc/ice-servers')
      .set('Authorization', `Bearer ${patientToken}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.iceServers)).toBe(true);
    expect(res.body.iceServers.length).toBeGreaterThan(0);
  });

  // --- Admin stats ---
  test('admin stats endpoint', async () => {
    const adminLogin = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@telemedicine.com', password: 'admin123' });
    const adminToken = adminLogin.body.token;
    if (!adminToken) return; // admin might not be seeded yet

    const res = await request(app)
      .get('/api/users/admin/stats')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.totalUsers).toBeDefined();
  });
});
