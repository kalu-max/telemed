// Tests for auth endpoints: OTP password reset, registration, login token format
process.env.NODE_ENV = 'test';
process.env.DB_DIALECT = 'sqlite';
process.env.DB_STORAGE = ':memory:';
process.env.FIREBASE_CONFIG = '{}';

// clear cached modules
delete require.cache[require.resolve('../server/config/database')];
delete require.cache[require.resolve('../server/models')];
delete require.cache[require.resolve('../server')];

require('dotenv').config();
const request = require('supertest');
const { sequelize } = require('../server/config/database');
const { app, server, io } = require('../server');

describe('Auth endpoints', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  afterAll(async () => {
    await sequelize.close();
    if (server && server.close) server.close();
    if (io && io.close) io.close();
  });

  let patientToken;

  test('register a patient', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'patient1@test.com', password: 'Test1234', name: 'Test Patient', role: 'patient' });
    expect([200, 201]).toContain(res.statusCode);
    expect(res.body.token).toBeDefined();
    patientToken = res.body.token;
  });

  test('register a doctor', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'doc1@test.com', password: 'Test1234', name: 'Dr Test', role: 'doctor' });
    expect([200, 201]).toContain(res.statusCode);
    expect(res.body.token).toBeDefined();
  });

  test('login with correct credentials', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'patient1@test.com', password: 'Test1234' });
    expect(res.statusCode).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.email).toBe('patient1@test.com');
  });

  test('login with wrong password fails', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'patient1@test.com', password: 'WrongPass' });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  test('request OTP for password reset', async () => {
    const res = await request(app)
      .post('/api/auth/request-otp')
      .send({ email: 'patient1@test.com' });
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBeDefined();
  });

  test('request OTP for non-existent email returns 200 (no info leak)', async () => {
    const res = await request(app)
      .post('/api/auth/request-otp')
      .send({ email: 'nobody@test.com' });
    // API correctly returns 200 to avoid revealing whether an email exists
    expect(res.statusCode).toBe(200);
  });

  test('reset password with wrong OTP fails', async () => {
    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: 'patient1@test.com', otp: '000000', newPassword: 'NewPass123' });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  test('duplicate registration fails', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'patient1@test.com', password: 'Test1234', name: 'Duplicate', role: 'patient' });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });
});
