#!/usr/bin/env node

/**
 * Database initialization and seeding script
 * Usage: node scripts/initDatabase.js [--seed] [--force]
 * 
 * --seed: Populate with sample data
 * --force: Drop existing tables and recreate
 */

require('dotenv').config();

const { sequelize, syncDatabase } = require('../server/config/database');
const { User, Doctor, Patient, Consultation } = require('../server/models');
const bcrypt = require('bcryptjs');
const logger = require('../server/utils/logger');

const args = process.argv.slice(2);
const shouldSeed = args.includes('--seed');
const shouldForce = args.includes('--force');

async function initDatabase() {
  try {
    logger.info('🔄 Initializing database...');

    // Sync database (create tables)
    await syncDatabase(shouldForce);
    logger.info('✅ Database synchronized');

    if (shouldSeed) {
      await seedDatabase();
    }

    logger.info('✅ Database initialization complete');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Database initialization failed:', error.message);
    process.exit(1);
  }
}

async function seedDatabase() {
  try {
    logger.info('🌱 Seeding database with sample data...');

    // Create admin user
    const adminHash = await bcrypt.hash('admin123', 10);
    const admin = await User.create({
      userId: `user_admin_${Date.now()}`,
      email: 'admin@telemedicine.com',
      password: adminHash,
      name: 'System Administrator',
      role: 'admin'
    });
    logger.info('✅ Created admin user');

    // Create sample doctors
    const doctorData = [
      {
        name: 'Dr. Sarah Johnson',
        specialization: 'Cardiology',
        yearsOfExperience: 10,
        consultationFee: 50,
        bio: 'Board-certified cardiologist with 10 years of experience'
      },
      {
        name: 'Dr. Michael Chen',
        specialization: 'Dermatology',
        yearsOfExperience: 8,
        consultationFee: 40,
        bio: 'Specialist in skin conditions and cosmetic dermatology'
      },
      {
        name: 'Dr. Emily Rodriguez',
        specialization: 'Pediatrics',
        yearsOfExperience: 12,
        consultationFee: 45,
        bio: 'Pediatrician dedicated to child health and wellness'
      }
    ];

    for (const data of doctorData) {
      const passwordHash = await bcrypt.hash('doctor123', 10);
      const user = await User.create({
        userId: `user_doctor_${Date.now()}_${Math.random()}`,
        email: `${data.name.split(' ')[1].toLowerCase()}@telemedicine.com`,
        password: passwordHash,
        name: data.name,
        role: 'doctor'
      });

      await Doctor.create({
        userId: user.userId,
        specialization: data.specialization,
        bio: data.bio,
        yearsOfExperience: data.yearsOfExperience,
        consultationFee: data.consultationFee,
        rating: Math.floor(Math.random() * 5) + 1,
        isAvailable: true
      });
    }
    logger.info('✅ Created sample doctors');

    // Create sample patients
    const patientData = [
      { name: 'Alice Williams', dateOfBirth: '1990-05-15' },
      { name: 'Bob Martinez', dateOfBirth: '1985-10-22' },
      { name: 'Carol Davis', dateOfBirth: '1995-03-08' }
    ];

    for (const data of patientData) {
      const passwordHash = await bcrypt.hash('patient123', 10);
      const user = await User.create({
        userId: `user_patient_${Date.now()}_${Math.random()}`,
        email: `${data.name.split(' ')[0].toLowerCase()}@patient.com`,
        password: passwordHash,
        name: data.name,
        role: 'patient'
      });

      await Patient.create({
        userId: user.userId,
        dateOfBirth: new Date(data.dateOfBirth),
        gender: ['male', 'female', 'other'][Math.floor(Math.random() * 3)],
        medicalHistory: 'No significant medical history',
        allergies: 'None'
      });
    }
    logger.info('✅ Created sample patients');

    logger.info('📊 Sample data created:');
    logger.info('   - 1 admin user');
    logger.info('   - 3 doctors');
    logger.info('   - 3 patients');
    logger.info('\n📝 Default credentials:');
    logger.info('   Admin: admin@telemedicine.com / admin123');
    logger.info('   Doctor: johnson@telemedicine.com / doctor123');
    logger.info('   Patient: alice@patient.com / patient123');
  } catch (error) {
    logger.error('❌ Seeding failed:', error.message);
    throw error;
  }
}

// Run initialization
initDatabase();
