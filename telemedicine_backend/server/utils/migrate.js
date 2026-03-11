/**
 * Migration utilities for moving from in-memory storage to databases
 * Use this to transition existing mock data to PostgreSQL/Firebase
 */

const { User, Doctor, Patient, Consultation } = require('../models');
const { firestore } = require('../config/firebase');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');

/**
 * Migrate user data from in-memory format to PostgreSQL
 * @param {Object} usersMap - Original in-memory users object
 */
async function migrateUsersToPostgreSQL(usersMap) {
  try {
    logger.info('📦 Migrating users to PostgreSQL...');
    let count = 0;

    for (const [email, userData] of Object.entries(usersMap)) {
      // Check if user already exists
      const exists = await User.findByPk(userData.userId);
      if (exists) {
        logger.debug(`User ${email} already exists, skipping`);
        continue;
      }

      // Create user
      await User.create({
        userId: userData.userId,
        email: userData.email,
        password: userData.password, // Already hashed
        name: userData.name,
        role: userData.role,
        isOnline: userData.isOnline,
        lastLogin: userData.lastLogin || null
      });

      // If doctor, create doctor profile
      if (userData.role === 'doctor') {
        await Doctor.create({
          userId: userData.userId,
          specialization: userData.specialization || 'General Practice',
          rating: userData.rating || 0,
          isAvailable: userData.role === 'doctor',
          yearsOfExperience: 0,
          consultationFee: 0,
          totalConsultations: userData.callCount || 0
        });
      }

      // If patient, create patient profile
      if (userData.role === 'patient') {
        await Patient.create({
          userId: userData.userId,
          gender: 'other',
          medicalHistory: ''
        });
      }

      count++;
    }

    logger.info(`✅ Migrated ${count} users to PostgreSQL`);
  } catch (error) {
    logger.error('❌ User migration failed:', error.message);
    throw error;
  }
}

/**
 * Migrate doctor list from in-memory to PostgreSQL
 * @param {Object} doctorsMap - Original in-memory doctors object
 */
async function migrateDoctorsToPostgreSQL(doctorsMap) {
  try {
    logger.info('📦 Migrating doctors to PostgreSQL...');
    let count = 0;

    for (const [userId, doctorData] of Object.entries(doctorsMap)) {
      const exists = await Doctor.findByPk(userId);
      if (exists) {
        logger.debug(`Doctor ${userId} already exists, skipping`);
        continue;
      }

      // Check if user exists
      const user = await User.findByPk(userId);
      if (!user) {
        logger.warn(`User ${userId} not found, skipping doctor migration`);
        continue;
      }

      await Doctor.create({
        userId: doctorData.userId,
        specialization: doctorData.specialization || '',
        rating: doctorData.rating || 0,
        isAvailable: doctorData.isAvailable !== false,
        yearsOfExperience: doctorData.yearsOfExperience || 0,
        consultationFee: doctorData.consultationFee || 0,
        totalConsultations: doctorData.totalConsultations || 0,
        bio: doctorData.bio || '',
        officeLocation: doctorData.officeLocation || ''
      });

      count++;
    }

    logger.info(`✅ Migrated ${count} doctors to PostgreSQL`);
  } catch (error) {
    logger.error('❌ Doctor migration failed:', error.message);
    throw error;
  }
}

/**
 * Migrate call/consultation data to PostgreSQL
 * @param {Array} callsArray - Array of call objects from in-memory storage
 */
async function migrateCallsToPostgreSQL(callsArray) {
  try {
    logger.info('📦 Migrating calls to PostgreSQL...');
    let count = 0;

    for (const call of callsArray) {
      const exists = await Consultation.findByPk(call.callId);
      if (exists) {
        logger.debug(`Call ${call.callId} already exists, skipping`);
        continue;
      }

      await Consultation.create({
        consultationId: call.callId,
        patientId: call.patientId,
        doctorId: call.doctorId,
        startTime: call.startTime ? new Date(call.startTime) : null,
        endTime: call.endTime ? new Date(call.endTime) : null,
        status: call.status || 'completed',
        notes: call.notes || '',
        recordingUrl: call.recordingUrl || ''
      });

      count++;
    }

    logger.info(`✅ Migrated ${count} calls to PostgreSQL`);
  } catch (error) {
    logger.error('❌ Call migration failed:', error.message);
    throw error;
  }
}

/**
 * Migrate active calls/real-time data to Firebase Realtime DB
 * @param {Object} activeCallsMap - Map of currently active calls
 */
async function migrateActiveCallsToFirebase(activeCallsMap) {
  try {
    logger.info('📦 Migrating active calls to Firebase...');
    let count = 0;

    for (const [callId, callData] of Object.entries(activeCallsMap)) {
      await firestore.set('activeConsultations', callId, {
        callId: callId,
        patientId: callData.patientId,
        doctorId: callData.doctorId,
        startTime: callData.startTime || Date.now(),
        participants: callData.participants || [],
        webrtcOffers: callData.webrtcOffers || {},
        webrtcAnswers: callData.webrtcAnswers || {},
        iceCandidates: callData.iceCandidates || {}
      });

      count++;
    }

    logger.info(`✅ Migrated ${count} active calls to Firebase`);
  } catch (error) {
    logger.error('❌ Active calls migration failed:', error.message);
    throw error;
  }
}

/**
 * Complete migration orchestrator
 * Runs all migrations in order
 */
async function runCompleteMigration(data) {
  try {
    logger.info('🚀 Starting complete data migration...\n');

    if (data.users) {
      await migrateUsersToPostgreSQL(data.users);
    }

    if (data.doctors) {
      await migrateDoctorsToPostgreSQL(data.doctors);
    }

    if (data.calls) {
      await migrateCallsToPostgreSQL(data.calls);
    }

    if (data.activeCalls) {
      await migrateActiveCallsToFirebase(data.activeCalls);
    }

    logger.info('\n✅ All migrations completed successfully!');
    return true;
  } catch (error) {
    logger.error('❌ Migration failed:', error.message);
    return false;
  }
}

/**
 * Export data from databases for backup
 */
async function exportAllData() {
  try {
    const users = await User.findAll({ include: [Doctor, Patient] });
    const consultations = await Consultation.findAll({
      include: [{ association: 'patient' }, { association: 'Doctor' }]
    });

    return {
      timestamp: new Date().toISOString(),
      users: users,
      consultations: consultations,
      totalUsers: users.length
    };
  } catch (error) {
    logger.error('❌ Export failed:', error.message);
    throw error;
  }
}

module.exports = {
  migrateUsersToPostgreSQL,
  migrateDoctorsToPostgreSQL,
  migrateCallsToPostgreSQL,
  migrateActiveCallsToFirebase,
  runCompleteMigration,
  exportAllData
};
