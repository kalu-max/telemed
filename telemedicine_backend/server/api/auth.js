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

  // Validation
  if (!email || !password || !name || !role) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const existing = await User.findOne({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: 'User already exists' });
  }

  const hashedPassword = await bcrypt.hash(password, 10);
  const userId = `user_${Date.now()}`;

  const user = await User.create({
    userId,
    email,
    password: hashedPassword,
    name,
    role,
  });

  // Create doctor profile entry if role is doctor
  if (role === 'doctor') {
    await Doctor.create({
      userId,
      specialization: specialization || '',
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
        name,
        specialization: specialization || '',
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
      email,
      name,
      role,
      doctorId: role === 'doctor' ? userId : null
    },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '24h' }
  );

  logger.info(`New user registered: ${email} (${role})`);

  res.status(201).json({
    message: 'User registered successfully',
    token,
    user: {
      userId,
      email,
      name,
      role,
      specialization: specialization || null
    }
  });
}));

// Login
router.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }

  const user = await User.findOne({ where: { email } });
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

  logger.info(`User logged in: ${email}`);

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

  if (!email || !newPassword) {
    return res.status(400).json({ error: 'Email and newPassword are required' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const user = await User.findOne({ where: { email } });
  if (!user) {
    return res.status(404).json({ error: 'No account found with that email address' });
  }

  const hashed = await bcrypt.hash(newPassword, 10);
  await user.update({ password: hashed });

  logger.info(`Password reset for: ${email}`);
  res.json({ success: true, message: 'Password reset successfully. You can now log in with your new password.' });
}));

module.exports = router;
