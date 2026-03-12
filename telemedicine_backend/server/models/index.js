const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { addEncryptionHooks } = require('../utils/encryption');

const isPostgresDialect = sequelize.getDialect() === 'postgres';
const consultationRefKey = isPostgresDialect ? 'consultation_id' : 'consultationId';
const chatRefKey = isPostgresDialect ? 'chat_id' : 'chatId';
const mediaFileRefKey = isPostgresDialect ? 'file_id' : 'fileId';

// User model
const User = sequelize.define('User', {
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    field: 'user_id'
  },
  email: {
    type: DataTypes.STRING,
    unique: true,
    allowNull: false,
    validate: {
      isEmail: true
    }
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  role: {
    type: DataTypes.ENUM('patient', 'doctor', 'admin'),
    defaultValue: 'patient'
  },
  isOnline: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  phone: DataTypes.STRING,
  avatar: DataTypes.STRING,
  fcmToken: DataTypes.STRING,
  lastLogin: DataTypes.DATE
}, {
  tableName: 'users'
});

// Doctor profile model
const Doctor = sequelize.define('Doctor', {
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    field: 'user_id',
    references: {
      model: User,
      key: 'user_id'
    }
  },
  specialization: DataTypes.STRING,
  bio: DataTypes.TEXT,
  licenseNumber: DataTypes.STRING,
  yearsOfExperience: DataTypes.INTEGER,
  rating: {
    type: DataTypes.DECIMAL(3, 2),
    defaultValue: 0
  },
  consultationFee: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  },
  isAvailable: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  totalConsultations: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  officeLocation: DataTypes.STRING
}, {
  tableName: 'doctors'
});

// Patient profile model
const Patient = sequelize.define('Patient', {
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    field: 'user_id',
    references: {
      model: User,
      key: 'user_id'
    }
  },
  dateOfBirth: DataTypes.DATE,
  gender: DataTypes.ENUM('male', 'female', 'other'),
  medicalHistory: DataTypes.TEXT,
  emergencyContact: DataTypes.STRING,
  allergies: DataTypes.TEXT,
  currentMedications: DataTypes.TEXT,
  insuranceProvider: DataTypes.STRING,
  insurancePolicyNumber: DataTypes.STRING
}, {
  tableName: 'patients'
});

// Consultation model
const Consultation = sequelize.define('Consultation', {
  consultationId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  patientId: {
    type: DataTypes.STRING,
    field: 'patient_id',
    references: {
      model: User,
      key: 'user_id'
    }
  },
  doctorId: {
    type: DataTypes.STRING,
    field: 'doctor_id',
    references: {
      // Use users.user_id for FK integrity across legacy doctor schemas
      // where doctors.user_id may not be constrained as UNIQUE.
      model: User,
      key: 'user_id'
    }
  },
  patientName: DataTypes.STRING,
  doctorName: DataTypes.STRING,
  scheduledTime: DataTypes.DATE,
  startTime: DataTypes.DATE,
  endTime: DataTypes.DATE,
  status: {
    type: DataTypes.STRING,
    defaultValue: 'scheduled'
  },
  reason: DataTypes.TEXT,
  notes: DataTypes.TEXT,
  prescription: DataTypes.TEXT,
  recordingUrl: DataTypes.STRING,
  completedAt: DataTypes.DATE,
  cancelledAt: DataTypes.DATE,
  reports: {
    type: DataTypes.TEXT,
    defaultValue: '[]',
    get() {
      const raw = this.getDataValue('reports');
      try { return JSON.parse(raw || '[]'); } catch { return []; }
    },
    set(val) {
      this.setDataValue('reports', JSON.stringify(val || []));
    }
  }
}, {
  tableName: 'consultations'
});

// Medical record model
const MedicalRecord = sequelize.define('MedicalRecord', {
  recordId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  patientId: {
    type: DataTypes.STRING,
    field: 'patient_id',
    references: {
      model: User,
      key: 'user_id'
    }
  },
  consultationId: {
    type: DataTypes.STRING,
    field: 'consultation_id'
  },
  diagnosis: DataTypes.TEXT,
  treatment: DataTypes.TEXT,
  fileUrl: DataTypes.STRING,
  fileType: DataTypes.STRING
}, {
  tableName: 'medical_records'
});

// Notification model
const Notification = sequelize.define('Notification', {
  notificationId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  userId: {
    type: DataTypes.STRING,
    field: 'user_id',
    references: {
      model: User,
      key: 'user_id'
    }
  },
  title: DataTypes.STRING,
  message: DataTypes.TEXT,
  type: DataTypes.ENUM('appointment', 'message', 'system', 'reminder'),
  isRead: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  relatedId: DataTypes.STRING
}, {
  tableName: 'notifications'
});

// Message model (chat messages linked to consultations)
const Message = sequelize.define('Message', {
  messageId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  consultId: {
    type: DataTypes.STRING,
    references: {
      model: Consultation,
      key: consultationRefKey
    }
  },
  senderId: {
    type: DataTypes.STRING,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  content: DataTypes.TEXT,
  mediaId: {
    type: DataTypes.STRING,
    references: {
      model: 'media_files',
      key: mediaFileRefKey
    }
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'messages'
});

// Call log model
const CallLog = sequelize.define('CallLog', {
  callId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  consultId: {
    type: DataTypes.STRING,
    references: {
      model: Consultation,
      key: consultationRefKey
    }
  },
  startTime: DataTypes.DATE,
  endTime: DataTypes.DATE,
  type: DataTypes.ENUM('audio','video','screen')
}, {
  tableName: 'call_logs'
});

// Media file model
const MediaFile = sequelize.define('MediaFile', {
  fileId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  type: DataTypes.ENUM('image','video','audio','document'),
  path: DataTypes.STRING,
  encryptionKey: DataTypes.STRING,
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'media_files'
});

// Billing model
const Billing = sequelize.define('Billing', {
  invoiceId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  patientId: {
    type: DataTypes.STRING,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  doctorId: {
    type: DataTypes.STRING,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  consultId: {
    type: DataTypes.STRING,
    references: {
      model: Consultation,
      key: consultationRefKey
    }
  },
  amount: DataTypes.DECIMAL(10, 2),
  status: DataTypes.ENUM('pending', 'paid', 'cancelled')
}, {
  tableName: 'billing'
});

// Chat model
const Chat = sequelize.define('Chat', {
  chatId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  participants: {
    type: DataTypes.TEXT,
    defaultValue: '[]',
    get() {
      const raw = this.getDataValue('participants');
      try { return JSON.parse(raw || '[]'); } catch { return []; }
    },
    set(val) {
      this.setDataValue('participants', JSON.stringify(val || []));
    }
  }
}, {
  tableName: 'chats'
});

// ChatMessage model
const ChatMessage = sequelize.define('ChatMessage', {
  messageId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  chatId: {
    type: DataTypes.STRING,
    references: { model: Chat, key: chatRefKey }
  },
  senderId: DataTypes.STRING,
  text: DataTypes.TEXT,
  messageType: {
    type: DataTypes.STRING,
    defaultValue: 'text'
  },
  imageUrl: DataTypes.STRING,
  fileUrl: DataTypes.STRING,
  fileName: DataTypes.STRING,
  mimeType: DataTypes.STRING,
  size: DataTypes.INTEGER
}, {
  tableName: 'chat_messages'
});

// Prescription model
const Prescription = sequelize.define('Prescription', {
  prescriptionId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  patientId: DataTypes.STRING,
  patientName: DataTypes.STRING,
  doctorId: DataTypes.STRING,
  doctorName: DataTypes.STRING,
  diagnosis: DataTypes.TEXT,
  notes: DataTypes.TEXT,
  medications: {
    type: DataTypes.TEXT,
    defaultValue: '[]',
    get() {
      const raw = this.getDataValue('medications');
      try { return JSON.parse(raw || '[]'); } catch { return []; }
    },
    set(val) {
      this.setDataValue('medications', JSON.stringify(val || []));
    }
  },
  consultationId: DataTypes.STRING,
  consultationDate: DataTypes.STRING,
  status: {
    type: DataTypes.STRING,
    defaultValue: 'active'
  },
  patientViewed: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'prescriptions'
});

// OTP Token model (persistent OTP storage)
const OtpToken = sequelize.define('OtpToken', {
  email: {
    type: DataTypes.STRING,
    primaryKey: true,
    allowNull: false
  },
  otp: {
    type: DataTypes.STRING,
    allowNull: false
  },
  expiresAt: {
    type: DataTypes.DATE,
    allowNull: false
  }
}, {
  tableName: 'otp_tokens'
});

// Doctor availability slot model
const DoctorAvailabilitySlot = sequelize.define('DoctorAvailabilitySlot', {
  slotId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  doctorId: {
    type: DataTypes.STRING,
    field: 'doctor_id',
    references: {
      model: User,
      key: 'user_id'
    }
  },
  dayOfWeek: {
    type: DataTypes.INTEGER, // 0=Sunday, 1=Monday, ..., 6=Saturday
    allowNull: false,
    validate: { min: 0, max: 6 }
  },
  startTime: {
    type: DataTypes.STRING, // HH:MM format
    allowNull: false
  },
  endTime: {
    type: DataTypes.STRING, // HH:MM format
    allowNull: false
  },
  slotDurationMinutes: {
    type: DataTypes.INTEGER,
    defaultValue: 30
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'doctor_availability_slots'
});

// Doctor Review model
const DoctorReview = sequelize.define('DoctorReview', {
  reviewId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  doctorId: {
    type: DataTypes.STRING,
    field: 'doctor_id'
  },
  patientId: {
    type: DataTypes.STRING,
    field: 'patient_id'
  },
  consultationId: {
    type: DataTypes.STRING,
    field: 'consultation_id'
  },
  rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  comment: DataTypes.TEXT,
  isAnonymous: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'doctor_reviews'
});

// HIPAA Audit Log model
const AuditLog = sequelize.define('AuditLog', {
  logId: {
    type: DataTypes.STRING,
    primaryKey: true
  },
  userId: {
    type: DataTypes.STRING,
    field: 'user_id'
  },
  action: {
    type: DataTypes.STRING,
    allowNull: false
  },
  resourceType: {
    type: DataTypes.STRING, // 'medical_record', 'prescription', 'patient_data', 'consultation'
    allowNull: false
  },
  resourceId: DataTypes.STRING,
  details: DataTypes.TEXT,
  ipAddress: DataTypes.STRING,
  userAgent: DataTypes.STRING
}, {
  tableName: 'audit_logs',
  indexes: [
    { fields: ['user_id'] },
    { fields: [isPostgresDialect ? 'resource_type' : 'resourceType'] },
    { fields: [isPostgresDialect ? 'created_at' : 'createdAt'] }
  ]
});

// Associations
User.hasOne(Doctor, { foreignKey: 'userId', sourceKey: 'userId' });
User.hasOne(Patient, { foreignKey: 'userId', sourceKey: 'userId' });
Doctor.belongsTo(User, { foreignKey: 'userId', targetKey: 'userId' });
Patient.belongsTo(User, { foreignKey: 'userId', targetKey: 'userId' });

Consultation.belongsTo(User, { foreignKey: 'patientId', targetKey: 'userId', as: 'patient' });
Consultation.belongsTo(User, { foreignKey: 'doctorId', targetKey: 'userId', as: 'doctorUser' });
// Keep an object-level relation to Doctor for convenience, but avoid DB-level
// FK creation because some legacy schemas do not enforce doctors.user_id unique.
Consultation.belongsTo(Doctor, {
  foreignKey: 'doctorId',
  targetKey: 'userId',
  as: 'doctor',
  constraints: false,
});

MedicalRecord.belongsTo(User, { foreignKey: 'patientId', targetKey: 'userId', as: 'patient' });
MedicalRecord.belongsTo(Consultation, { foreignKey: 'consultationId', targetKey: 'consultationId' });

Notification.belongsTo(User, { foreignKey: 'userId', targetKey: 'userId' });

Chat.hasMany(ChatMessage, { foreignKey: 'chatId' });
ChatMessage.belongsTo(Chat, { foreignKey: 'chatId' });

// new associations
Consultation.hasMany(Message, { foreignKey: 'consultId' });
Message.belongsTo(Consultation, { foreignKey: 'consultId' });
Message.belongsTo(User, { foreignKey: 'senderId' });

Consultation.hasMany(CallLog, { foreignKey: 'consultId' });
CallLog.belongsTo(Consultation, { foreignKey: 'consultId' });

// billing relationships
Billing.belongsTo(User, { foreignKey: 'patientId', as: 'patient' });
Billing.belongsTo(User, { foreignKey: 'doctorId', as: 'doctor' });
Billing.belongsTo(Consultation, { foreignKey: 'consultId' });
User.hasMany(Billing, { foreignKey: 'patientId', as: 'patientBills' });
User.hasMany(Billing, { foreignKey: 'doctorId', as: 'doctorBills' });

Doctor.hasMany(DoctorAvailabilitySlot, {
  foreignKey: 'doctorId',
  sourceKey: 'userId',
  constraints: false,
});
DoctorAvailabilitySlot.belongsTo(Doctor, {
  foreignKey: 'doctorId',
  targetKey: 'userId',
  constraints: false,
});

// DoctorReview associations — skip Doctor FK for SQLite compat (Doctor PK is also FK to Users)
// Doctor.hasMany(DoctorReview) not used; query by doctorId column directly
DoctorReview.belongsTo(User, { foreignKey: 'patientId', targetKey: 'userId', as: 'reviewer' });

module.exports = {
  User,
  Doctor,
  Patient,
  Consultation,
  MedicalRecord,
  Notification,
  Message,
  CallLog,
  MediaFile,
  Billing,
  Chat,
  ChatMessage,
  Prescription,
  OtpToken,
  DoctorAvailabilitySlot,
  DoctorReview,
  AuditLog
};

// Encryption hooks for sensitive fields (active when ENCRYPTION_KEY is set)
addEncryptionHooks(Patient, ['medicalHistory', 'allergies', 'currentMedications', 'insurancePolicyNumber']);
addEncryptionHooks(MedicalRecord, ['diagnosis', 'treatment']);
addEncryptionHooks(Prescription, ['diagnosis', 'notes']);
