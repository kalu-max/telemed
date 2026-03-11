// Tests for Chat, ChatMessage, Prescription, Notification Sequelize models
process.env.DB_DIALECT = 'sqlite';
process.env.DB_STORAGE = ':memory:';
process.env.FIREBASE_CONFIG = '{}';

delete require.cache[require.resolve('../server/config/database')];
delete require.cache[require.resolve('../server/models')];

require('dotenv').config();
const { sequelize } = require('../server/config/database');
const {
  User,
  Patient,
  Doctor,
  Consultation,
  Chat,
  ChatMessage,
  Prescription,
  Notification: NotificationModel,
} = require('../server/models');

describe('New Sequelize models', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });

    await User.create({
      userId: 'u_p1',
      email: 'p1@test.com',
      password: 'hashed',
      name: 'Patient One',
      role: 'patient',
    });
    await User.create({
      userId: 'u_d1',
      email: 'd1@test.com',
      password: 'hashed',
      name: 'Doctor One',
      role: 'doctor',
    });
  });

  afterAll(async () => {
    await sequelize.close();
  });

  test('create Chat and ChatMessage', async () => {
    const chat = await Chat.create({
      chatId: 'chat_1',
      participants: JSON.stringify(['u_p1', 'u_d1']),
    });
    expect(chat.chatId).toBe('chat_1');

    const msg = await ChatMessage.create({
      messageId: 'msg_1',
      chatId: 'chat_1',
      senderId: 'u_p1',
      text: 'Hello doctor',
    });
    expect(msg.messageId).toBe('msg_1');
    expect(msg.chatId).toBe('chat_1');
  });

  test('Chat hasMany ChatMessage association', async () => {
    const chat = await Chat.findByPk('chat_1', { include: [ChatMessage] });
    expect(chat).toBeDefined();
    expect(chat.ChatMessages.length).toBe(1);
  });

  test('create Prescription', async () => {
    const rx = await Prescription.create({
      prescriptionId: 'rx_1',
      patientId: 'u_p1',
      patientName: 'Patient One',
      doctorId: 'u_d1',
      doctorName: 'Doctor One',
      diagnosis: 'Flu',
      medications: JSON.stringify([{ name: 'Aspirin', dosage: '500mg' }]),
    });
    expect(rx.prescriptionId).toBe('rx_1');
    expect(rx.diagnosis).toBe('Flu');

    // medications stored as JSON text
    const meds = JSON.parse(rx.medications);
    expect(meds).toHaveLength(1);
    expect(meds[0].name).toBe('Aspirin');
  });

  test('create Notification', async () => {
    const notif = await NotificationModel.create({
      notificationId: 'n_1',
      userId: 'u_p1',
      message: 'Your appointment is confirmed',
    });
    expect(notif.notificationId).toBe('n_1');
    expect(notif.userId).toBe('u_p1');
  });

  test('Consultation with STRING status supports all values', async () => {
    // Disable FK enforcement for SQLite compatibility (works on PostgreSQL)
    await sequelize.query('PRAGMA foreign_keys = OFF;');
    const statuses = ['scheduled', 'connected', 'in-progress', 'completed', 'cancelled', 'missed'];
    for (let i = 0; i < statuses.length; i++) {
      const c = await Consultation.create({
        consultationId: `c_status_${i}`,
        patientId: 'u_p1',
        doctorId: 'u_d1',
        status: statuses[i],
      });
      expect(c.status).toBe(statuses[i]);
    }
    await sequelize.query('PRAGMA foreign_keys = ON;');
  });
});
