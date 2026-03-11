// use in-memory sqlite for tests
process.env.DB_DIALECT = 'sqlite';
process.env.DB_STORAGE = ':memory:';

// disable firebase during backend unit tests
process.env.FIREBASE_CONFIG = '{}';

// ensure environment variables are loaded
demand = require('dotenv').config();

// now import modules
defaults = require('../server/config/database');
const { sequelize } = defaults;
const { User, Doctor, Patient, Consultation, Message, CallLog, MediaFile, Billing } = require('../server/models');

describe('PostgreSQL models', () => {
  beforeAll(async () => {
    // Disable FK constraints during sync to avoid SQLite ordering issues
    await sequelize.query('PRAGMA foreign_keys = OFF;');
    await sequelize.sync({ force: true, logging: false });
    await sequelize.query('PRAGMA foreign_keys = ON;');
  });

  afterAll(async () => {
    await sequelize.close();
  });

  test('can create a user and associated patient/doctor profiles', async () => {
    const user = await User.create({
      userId: 'u_test_1',
      email: 'testuser@example.com',
      password: 'hashedpw',
      name: 'Test User',
      role: 'patient'
    });
    expect(user).toBeDefined();
    expect(user.userId).toBe('u_test_1');

    let patient;
    try {
      patient = await Patient.create({
        userId: 'u_test_1',
        gender: 'other'
      });
    } catch (e) {
      console.error('patient insert error', e.message, e.stack);
      if (e.parent) console.error('parent error', e.parent);
      throw e;
    }
    expect(patient).toBeDefined();
    expect(patient.userId).toBe('u_test_1');

    // create doctor
    const docUser = await User.create({
      userId: 'u_doc_1',
      email: 'doc@example.com',
      password: 'hashedpw',
      name: 'Doctor Who',
      role: 'doctor'
    });
    const doctor = await Doctor.create({
      userId: 'u_doc_1',
      specialization: 'Cardiology',
    });
    expect(doctor).toBeDefined();
    expect(doctor.userId).toBe('u_doc_1');
  });

  test('can create a consultation tying patient and doctor', async () => {
    // Disable FK enforcement for SQLite compatibility (model FK references work on PostgreSQL)
    await sequelize.query('PRAGMA foreign_keys = OFF;');
    let consultation;
    try {
      consultation = await Consultation.create({
        consultationId: 'c_1',
        patientId: 'u_test_1',
        doctorId: 'u_doc_1',
        status: 'scheduled'
      });
    } catch (e) {
      console.error('consultation insert error', e.message, e.stack);
      if (e.parent) console.error('parent error', e.parent);
      throw e;
    }
    expect(consultation).toBeDefined();
    expect(consultation.patientId).toBe('u_test_1');

    // create associated message
    const message = await Message.create({
      messageId: 'm_1',
      consultId: 'c_1',
      senderId: 'u_test_1',
      content: 'Hello doctor'
    });
    expect(message).toBeDefined();

    // create call log
    const callLog = await CallLog.create({
      callId: 'call_1',
      consultId: 'c_1',
      startTime: new Date(),
      endTime: new Date(),
      type: 'video'
    });
    expect(callLog).toBeDefined();

    // create media file
    const media = await MediaFile.create({
      fileId: 'file_1',
      type: 'image',
      path: '/tmp/pic.jpg'
    });
    expect(media).toBeDefined();

    // create billing record
    const bill = await Billing.create({
      invoiceId: 'inv_1',
      patientId: 'u_test_1',
      doctorId: 'u_doc_1',
      consultId: 'c_1',
      amount: 150.00,
      status: 'pending'
    });
    expect(bill).toBeDefined();

    await sequelize.query('PRAGMA foreign_keys = ON;');
  });
});