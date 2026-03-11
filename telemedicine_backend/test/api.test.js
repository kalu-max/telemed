// configuration for tests - must happen before loading server or database modules
process.env.NODE_ENV = 'test';
process.env.DB_DIALECT = 'sqlite';
process.env.DB_STORAGE = ':memory:';
process.env.FIREBASE_CONFIG = '{}';

// clear cached modules if already loaded by another test file
delete require.cache[require.resolve('../server/config/database')];
delete require.cache[require.resolve('../server/models')];
delete require.cache[require.resolve('../server')];

require('dotenv').config();
const request = require('supertest');
const { sequelize } = require('../server/config/database');
const { app, server } = require('../server');

describe('API endpoints', () => {
  beforeAll(async () => {
    // ensure database is fresh
    await sequelize.sync({ force: true });
  });

  afterAll(async () => {
    await sequelize.close();
    if (server && server.close) server.close();
    // if socket.io instance exported, close it as well
    const { io } = require('../server');
    if (io && io.close) io.close();
  });

  test('registration and login work', async () => {
    const registerResp = await request(app)
      .post('/api/auth/register')
      .send({ email: 'foo@bar.com', password: 'pass', name: 'Foo', role: 'patient' });
    expect([200,201]).toContain(registerResp.statusCode); // endpoint may return 201 on creation
    expect(registerResp.body.token).toBeDefined();

    const loginResp = await request(app)
      .post('/api/auth/login')
      .send({ email: 'foo@bar.com', password: 'pass' });
    expect(loginResp.statusCode).toBe(200);
    expect(loginResp.body.token).toBeDefined();
  });

  test('doctors available endpoint open to public', async () => {
    await request(app)
      .get('/api/users/doctors/available')
      .expect(200);
  });

  test('doctor list endpoint returns 0 when none exist', async () => {
    // create an admin to allow further actions if needed
    const loginResp = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@telemedicine.com', password: 'admin123' });
    const token = loginResp.body.token;

    const resp = await request(app)
      .get('/api/users/doctors/available')
      .set('Authorization', `Bearer ${token}`);
    expect(resp.statusCode).toBe(200);
    expect(resp.body.count).toBe(0);
  });
});