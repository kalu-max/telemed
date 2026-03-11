const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

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
      model: Doctor,
      key: 'user_id'
    }
  },
  scheduledTime: DataTypes.DATE,
  startTime: DataTypes.DATE,
  endTime: DataTypes.DATE,
  status: {
    type: DataTypes.ENUM('scheduled', 'ongoing', 'completed', 'cancelled'),
    defaultValue: 'scheduled'
  },
  reason: DataTypes.TEXT,
  notes: DataTypes.TEXT,
  prescription: DataTypes.TEXT,
  recordingUrl: DataTypes.STRING
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
    field: 'consultation_id',
    references: {
      model: Consultation,
      key: 'consultation_id'
    }
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
      key: 'consultationId'
    }
  },
  senderId: {
    type: DataTypes.STRING,
    references: {
      model: User,
      key: 'userId'
    }
  },
  content: DataTypes.TEXT,
  mediaId: {
    type: DataTypes.STRING,
    references: {
      model: 'MediaFiles',
      key: 'fileId'
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
      key: 'consultationId'
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
      key: 'userId'
    }
  },
  doctorId: {
    type: DataTypes.STRING,
    references: {
      model: User,
      key: 'userId'
    }
  },
  consultId: {
    type: DataTypes.STRING,
    references: {
      model: Consultation,
      key: 'consultationId'
    }
  },
  amount: DataTypes.DECIMAL(10, 2),
  status: DataTypes.ENUM('pending', 'paid', 'cancelled')
}, {
  tableName: 'billing'
});

// Associations
User.hasOne(Doctor, { foreignKey: 'user_id' });
User.hasOne(Patient, { foreignKey: 'user_id' });
Doctor.belongsTo(User, { foreignKey: 'user_id' });
Patient.belongsTo(User, { foreignKey: 'user_id' });

Consultation.belongsTo(User, { foreignKey: 'patient_id', targetKey: 'userId', as: 'patient' });
Consultation.belongsTo(Doctor, { foreignKey: 'doctor_id', targetKey: 'userId' });

MedicalRecord.belongsTo(User, { targetKey: 'userId' });
MedicalRecord.belongsTo(Consultation, { foreignKey: 'consultationId' });

Notification.belongsTo(User, { foreignKey: 'userId' });

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
  Billing
};
