const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { asyncHandler } = require('../middleware/errorHandler');
const logger = require('../utils/logger');
const { User, Doctor } = require('../models/index');

const router = express.Router();

// Seed admin user into persistent DB on startup
const adminEmail = process.env.ADMIN_EMAIL || 'admin@telemedicine.com';
const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';
(async () => {
  try {
    const existing = await User.findOne({ where: { email: adminEmail } });
    if (!existing) {
      const hashed = await bcrypt.hash(adminPassword, 10);
      await User.create({
        userId: `user_admin_${Date.now()}`,
        email: adminEmail,
        password: hashed,
        name: 'System Admin',
        role: 'admin',
      });
      logger.info(`Seeded admin user (${adminEmail})`);
    }
  } catch (e) {
    logger.warn(`Admin seed skipped: ${e.message}`);
  }
})();
// Register
router.post('/register', asyncHandler(async (req, res) => {
  const { email, password, name, role, specialization } = req.body;
  const normalizedEmail = `${email || ''}`.trim().toLowerCase();
  const normalizedName = `${name || ''}`.trim();
  const normalizedRole = `${role || ''}`.trim().toLowerCase();
  const normalizedSpecialization = `${specialization || ''}`.trim();

  // Validation
  if (!normalizedEmail || !password || !normalizedName || !normalizedRole) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const allowedRoles = new Set(['patient', 'doctor', 'admin']);
  if (!allowedRoles.has(normalizedRole)) {
    return res.status(400).json({ error: 'Invalid role' });
  }

  const existing = await User.findOne({ where: { email: normalizedEmail } });
  if (existing) {
    return res.status(409).json({ error: 'User already exists' });
  }

  const hashedPassword = await bcrypt.hash(password, 10);
  const userId = `user_${Date.now()}`;

  const user = await User.create({
    userId,
    email: normalizedEmail,
    password: hashedPassword,
    name: normalizedName,
    role: normalizedRole,
  });

  // Create doctor profile entry if role is doctor
  if (normalizedRole === 'doctor') {
    await Doctor.create({
      userId,
      specialization: normalizedSpecialization,
      rating: 0,
      isAvailable: true,
      yearsOfExperience: 0,
      consultationFee: 0,
      bio: '',
      totalConsultations: 0,
    });

    // Also add to in-memory doctors map so patients can discover new doctors immediately
    try {
      const { doctors } = require('./users');
      doctors[userId] = {
        userId,
        name: normalizedName,
        specialization: normalizedSpecialization,
        rating: 0,
        isAvailable: true,
        yearsOfExperience: 0,
        consultationFee: 0,
        bio: '',
        updatedAt: new Date(),
        totalConsultations: 0,
      };
    } catch (_) {}
  }

  const token = jwt.sign(
    {
      userId,
      email: normalizedEmail,
      name: normalizedName,
      role: normalizedRole,
      doctorId: normalizedRole === 'doctor' ? userId : null
    },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '24h' }
  );

  logger.info(`New user registered: ${normalizedEmail} (${normalizedRole})`);

  res.status(201).json({
    message: 'User registered successfully',
    token,
    user: {
      userId,
      email: normalizedEmail,
      name: normalizedName,
      role: normalizedRole,
      specialization: normalizedSpecialization || null
    }
  });
}));

// Login
router.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = `${email || ''}`.trim().toLowerCase();

  if (!normalizedEmail || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }

  const user = await User.findOne({ where: { email: normalizedEmail } });
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const passwordMatch = await bcrypt.compare(password, user.password);
  if (!passwordMatch) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  // Fetch doctor specialization if applicable
  let specialization = null;
  if (user.role === 'doctor') {
    try {
      const doctorProfile = await Doctor.findOne({ where: { userId: user.userId } });
      specialization = doctorProfile?.specialization || null;
    } catch (_) {}
  }

  const token = jwt.sign(
    {
      userId: user.userId,
      email: user.email,
      name: user.name,
      role: user.role,
      doctorId: user.role === 'doctor' ? user.userId : null
    },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '24h' }
  );

  logger.info(`User logged in: ${normalizedEmail}`);

  res.json({
    message: 'Login successful',
    token,
    user: {
      userId: user.userId,
      email: user.email,
      name: user.name,
      role: user.role,
      specialization,
    }
  });
}));

// Refresh token
router.post('/refresh', asyncHandler(async (req, res) => {
  const { token } = req.body;

  if (!token) {
    return res.status(400).json({ error: 'Token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
    const newToken = jwt.sign(
      {
        userId: decoded.userId,
        email: decoded.email,
        name: decoded.name,
        role: decoded.role,
        doctorId: decoded.doctorId
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '24h' }
    );

    res.json({ token: newToken });
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
}));

// Logout
router.post('/logout', (req, res) => {
  // Token invalidation can be handled by client removing token
  // In production, use Redis blacklist
  res.json({ message: 'Logged out successfully' });
});

// Reset password (direct reset without email OTP; extend with SMTP for production)
router.post('/reset-password', asyncHandler(async (req, res) => {
  const { email, newPassword } = req.body;
  const normalizedEmail = `${email || ''}`.trim().toLowerCase();

  if (!normalizedEmail || !newPassword) {
    return res.status(400).json({ error: 'Email and newPassword are required' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const user = await User.findOne({ where: { email: normalizedEmail } });
  if (!user) {
    return res.status(404).json({ error: 'No account found with that email address' });
  }

  const hashed = await bcrypt.hash(newPassword, 10);
  await user.update({ password: hashed });

  logger.info(`Password reset for: ${normalizedEmail}`);
  res.json({ success: true, message: 'Password reset successfully. You can now log in with your new password.' });
}));

module.exports = router;
