const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { asyncHandler } = require('../middleware/errorHandler');
const { authorizeRole } = require('../middleware/auth');
const { fetchIceServers } = require('../services/iceServers');
const logger = require('../utils/logger');

// Lazy accessor so we don't import before the module is initialised
function getActiveConnections() {
  try {
    return require('../websocket/communicationHandler').activeConnections;
  } catch (e) {
    return new Map();
  }
}

function emitToUser(userId, event, payload) {
  try {
    const conns = getActiveConnections();
    const s = conns.get(userId);
    if (s) s.emit(event, payload);
  } catch (_) { /* best-effort */ }
}

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 },
});
const reportsDir = path.join(__dirname, '..', '..', 'public', 'uploads', 'reports');
const chatMediaDir = path.join(__dirname, '..', '..', 'public', 'uploads', 'chat-media');
if (!fs.existsSync(reportsDir)) {
  fs.mkdirSync(reportsDir, { recursive: true });
}
if (!fs.existsSync(chatMediaDir)) {
  fs.mkdirSync(chatMediaDir, { recursive: true });
}

// Mock database
const doctors = {};
const patients = {};
const appointments = {};

// Load persisted doctors from DB into the in-memory map on startup
(async () => {
  try {
    const { Doctor, User } = require('../models/index');
    const dbDoctors = await Doctor.findAll({ include: [{ model: User, attributes: ['name', 'email'] }] });
    for (const d of dbDoctors) {
      const name = d.User ? d.User.name : 'Doctor';
      doctors[d.userId] = {
        userId: d.userId,
        name,
        specialization: d.specialization || '',
        rating: parseFloat(d.rating) || 0,
        isAvailable: d.isAvailable !== false,
        yearsOfExperience: d.yearsOfExperience || 0,
        consultationFee: parseFloat(d.consultationFee) || 0,
        bio: d.bio || '',
        totalConsultations: d.totalConsultations || 0,
      };
    }
  } catch (e) {
    // DB not ready yet or no doctors seeded — silently skip
  }
})();

// notifications inbox (userId -> array of messages)
const notifications = {};

// helper to queue notification for a user
function pushNotification(userId, message) {
  if (!notifications[userId]) notifications[userId] = [];
  notifications[userId].push({ message, timestamp: new Date() });
}

// patient health metrics store: patientId -> [{ metric, value, timestamp }]
const healthMetrics = {};

// simple chat store: chatId -> { chatId, participants: [userId], messages: [{senderId, text, timestamp}] }
const chats = {};

function ensureArrayMap(map, key) {
  if (!map[key]) map[key] = [];
  return map[key];
}

// Get RTC ICE/TURN configuration for the current authenticated user.
router.get('/rtc/ice-servers', asyncHandler(async (req, res) => {
  const requesterId = req.user?.userId || 'unknown';
  const iceConfig = await fetchIceServers({ ttlSeconds: req.query.ttl });

  logger.info(
    `ICE config requested by ${requesterId} using provider ${iceConfig.provider}`,
  );

  res.json({
    provider: iceConfig.provider,
    ttl: iceConfig.ttl,
    fetchedAt: new Date().toISOString(),
    iceServers: iceConfig.iceServers,
  });
}));

// Get all available doctors
router.get('/doctors/available', asyncHandler(async (req, res) => {
  const { specialization, sortBy = 'rating' } = req.query;

  let availableDoctors = Object.values(doctors).filter(doc => 
    doc.isAvailable && (specialization ? doc.specialization === specialization : true)
  );

  if (sortBy === 'rating') {
    availableDoctors.sort((a, b) => b.rating - a.rating);
  } else if (sortBy === 'experience') {
    availableDoctors.sort((a, b) => b.yearsOfExperience - a.yearsOfExperience);
  }

  res.json({
    count: availableDoctors.length,
    doctors: availableDoctors
  });
}));

// Get doctor profile
router.get('/doctors/:doctorId', asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  const doctor = doctors[doctorId];

  if (!doctor) {
    return res.status(404).json({ error: 'Doctor not found' });
  }

  res.json(doctor);
}));

// Update doctor profile (doctors only)
router.put('/doctors/:doctorId', authorizeRole('doctor'), asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  const { bio, specialization, qualification, yearsOfExperience, consultationFee, availableSlots } = req.body;

  if (req.user.userId !== doctorId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  if (!doctors[doctorId]) {
    doctors[doctorId] = {
      userId: doctorId,
      rating: 4.5,
      totalConsultations: 0,
      isOnline: false,
      isAvailable: false
    };
  }

  const doctor = doctors[doctorId];
  doctor.bio = bio || doctor.bio;
  doctor.specialization = specialization || doctor.specialization;
  doctor.qualification = qualification || doctor.qualification;
  doctor.yearsOfExperience = yearsOfExperience || doctor.yearsOfExperience;
  doctor.consultationFee = consultationFee || doctor.consultationFee;
  doctor.availableSlots = availableSlots || doctor.availableSlots || [];
  doctor.updatedAt = new Date();

  logger.info(`Doctor profile updated: ${doctorId}`);

  res.json({
    message: 'Profile updated successfully',
    doctor
  });
}));

// Delete doctor account (doctors only)
router.delete('/doctors/:doctorId', authorizeRole('doctor'), asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  if (req.user.userId !== doctorId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  // remove from doctors list
  if (doctors[doctorId]) {
    delete doctors[doctorId];
  }

  // also remove from users map if accessible
  try {
    const { users } = require('./auth');
    if (users) {
      Object.keys(users).forEach(email => {
        if (users[email].userId === doctorId) {
          delete users[email];
        }
      });
    }
  } catch (err) {
    // ignore, auth module may not export users
  }

  logger.info(`Doctor account deleted: ${doctorId}`);
  res.json({ message: 'Doctor account deleted' });
}));

// Get patient profile
router.get('/patients/:patientId', asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const patient = patients[patientId];

  if (!patient) {
    return res.status(404).json({ error: 'Patient not found' });
  }

  res.json(patient);
}));

// Update patient profile (patients only)
router.put('/patients/:patientId', authorizeRole('patient'), asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { dateOfBirth, gender, phone, address, medicalHistory } = req.body;

  if (req.user.userId !== patientId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  if (!patients[patientId]) {
    patients[patientId] = {
      userId: patientId,
      medicalHistory: [],
      appointments: []
    };
  }

  const patient = patients[patientId];
  patient.dateOfBirth = dateOfBirth || patient.dateOfBirth;
  patient.gender = gender || patient.gender;
  patient.phone = phone || patient.phone;
  patient.address = address || patient.address;
  patient.medicalHistory = medicalHistory || patient.medicalHistory;
  patient.updatedAt = new Date();

  logger.info(`Patient profile updated: ${patientId}`);

  res.json({
    message: 'Profile updated successfully',
    patient
  });
}));

// Book appointment
router.post('/appointments/book', authorizeRole('patient'), asyncHandler(async (req, res) => {
  const { doctorId, slotTime, reason } = req.body;
  const patientId = req.user.userId;

  if (!doctorId || !slotTime || !reason) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const appointmentId = `appt_${Date.now()}`;
  const patientName = req.user.name || patientId;
  const doctorName = doctors[doctorId]?.name || 'Doctor';
  appointments[appointmentId] = {
    appointmentId,
    doctorId,
    doctorName,
    patientId,
    patientName,
    slotTime: new Date(slotTime),
    reason,
    status: 'scheduled',
    createdAt: new Date(),
    notes: ''
  };

  logger.info(`Appointment booked: ${appointmentId} (Patient: ${patientId}, Doctor: ${doctorId})`);

  // Real-time notification to doctor
  pushNotification(doctorId, `New consultation request from ${patientName}: ${reason}`);
  emitToUser(doctorId, 'newAppointment', {
    appointmentId,
    patientId,
    patientName,
    slotTime,
    reason,
    status: 'scheduled',
    createdAt: new Date().toISOString(),
  });

  res.status(201).json({
    appointmentId,
    message: 'Appointment booked successfully',
    appointment: appointments[appointmentId]
  });
}));

// ----------------------------
// Health metrics endpoints
// ----------------------------

// Add a health metric for a patient (patient only)
router.post('/patients/:patientId/metrics', authorizeRole('patient'), asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  if (req.user.userId !== patientId) return res.status(403).json({ error: 'Unauthorized' });
  const { metric, value } = req.body;
  if (!metric || value == null) return res.status(400).json({ error: 'metric and value required' });
  ensureArrayMap(healthMetrics, patientId).push({ metric, value, timestamp: new Date() });
  res.status(201).json({ message: 'Metric added' });
}));

// Get health metrics for a patient (patient, doctor of record or admin)
router.get('/patients/:patientId/metrics', asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  if (requester.userId !== patientId && requester.role !== 'doctor' && requester.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized' });
  }
  const list = healthMetrics[patientId] || [];
  res.json({ count: list.length, metrics: list });
}));

// ----------------------------
// Chat endpoints (simple REST polling)
// ----------------------------

// Start a chat between participants (any authenticated user)
router.post('/chats/start', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { participants } = req.body;
  if (!participants || !Array.isArray(participants)) {
    return res.status(400).json({ error: 'participants array required (2+)'});
  }

  // Normalize participant list and always include requester.
  const normalizedParticipants = Array.from(
    new Set(
      participants
        .map((id) => `${id || ''}`.trim())
        .filter(Boolean)
        .concat(requester.userId),
    ),
  );

  if (normalizedParticipants.length < 2) {
    return res.status(400).json({ error: 'participants array required (2+)'});
  }

  // Reuse an existing 1:1 chat with the same participants.
  const existingChat = Object.values(chats).find((chat) => {
    if (!Array.isArray(chat.participants)) {
      return false;
    }
    if (chat.participants.length !== normalizedParticipants.length) {
      return false;
    }

    return normalizedParticipants.every((participantId) =>
      chat.participants.includes(participantId),
    );
  });

  if (existingChat) {
    return res.json({
      chatId: existingChat.chatId,
      reused: true,
      chat: existingChat,
    });
  }

  const chatId = `chat_${Date.now()}`;
  chats[chatId] = {
    chatId,
    participants: normalizedParticipants,
    messages: [],
  };
  res.status(201).json({ chatId, chat: chats[chatId] });
}));

// Post message to chat
router.post('/chats/:chatId/message', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: 'text required' });
  chat.messages.push({ senderId: requester.userId, text, messageType: 'text', timestamp: new Date() });
  // push notification to other participants
  try {
    chat.participants.forEach(p => {
      if (p !== requester.userId) {
        const snippet = text.length > 80 ? text.substring(0, 77) + '...' : text;
        pushNotification(p, `New message from ${requester.name || requester.userId}: ${snippet}`);
      }
    });
  } catch (e) {
    // ignore notification errors
  }
  res.json({ message: 'Message sent' });
}));

// Upload media/photo in chat
router.post('/chats/:chatId/message/media', upload.single('image'), asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized' });
  }
  if (!req.file) {
    return res.status(400).json({ error: 'image file is required' });
  }

  const ext = path.extname(req.file.originalname || '') || '.bin';
  const safeFileName = `${chatId}_${Date.now()}${ext}`;
  const filePath = path.join(chatMediaDir, safeFileName);
  fs.writeFileSync(filePath, req.file.buffer);

  const message = {
    senderId: requester.userId,
    messageType: 'image',
    text: req.body?.caption || '',
    imageUrl: `/uploads/chat-media/${safeFileName}`,
    fileName: req.file.originalname,
    mimeType: req.file.mimetype,
    size: req.file.size,
    timestamp: new Date(),
  };
  chat.messages.push(message);

  res.status(201).json({
    message: 'Image uploaded successfully',
    chatId,
    data: message,
  });
}));

// Get messages for a chat
router.get('/chats/:chatId/messages', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  res.json({ messages: chat.messages });
}));

// List chats for a user
router.get('/chats', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const userId = req.query.userId || requester.userId;
  if (userId !== requester.userId && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  const list = Object.values(chats).filter(c => c.participants.includes(userId));
  res.json({ count: list.length, chats: list });
}));

// Get user appointments
router.get('/appointments', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const role = req.user.role;

  const userAppointments = Object.values(appointments).filter(appt => {
    if (role === 'patient') {
      return appt.patientId === userId;
    } else if (role === 'doctor') {
      return appt.doctorId === userId;
    }
    return false;
  });

  res.json({
    count: userAppointments.length,
    appointments: userAppointments
  });
}));

// Update appointment status (patient/doctor participants only)
router.put('/appointments/:appointmentId', asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const { status, notes } = req.body;
  const requesterId = req.user.userId;

  const appointment = appointments[appointmentId];
  if (!appointment) {
    return res.status(404).json({ error: 'Appointment not found' });
  }
  if (appointment.patientId !== requesterId && appointment.doctorId !== requesterId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  const validStatuses = ['scheduled', 'connected', 'in-progress', 'completed', 'cancelled', 'missed'];
  if (!status || !validStatuses.includes(status)) {
    return res.status(400).json({ error: `Invalid status. Allowed: ${validStatuses.join(', ')}` });
  }

  appointment.status = status;
  appointment.updatedAt = new Date();
  if (typeof notes === 'string') {
    appointment.notes = notes;
  }
  if (status === 'completed') {
    appointment.completedAt = new Date();
  }
  if (status === 'cancelled') {
    appointment.cancelledAt = new Date();
  }

  const otherUserId = appointment.patientId === requesterId ? appointment.doctorId : appointment.patientId;
  pushNotification(otherUserId, `Appointment ${appointmentId} updated to ${status}`);

  // Real-time notification to the other party
  if (status === 'connected' || status === 'in-progress') {
    emitToUser(otherUserId, 'appointmentAccepted', {
      appointmentId,
      status,
      doctorId: appointment.doctorId,
      patientId: appointment.patientId,
    });
  } else if (status === 'cancelled') {
    emitToUser(otherUserId, 'appointmentCancelled', { appointmentId });
  }

  res.json({
    appointmentId,
    message: 'Appointment status updated',
    appointment,
  });
}));

// Upload a report file for an appointment
router.post('/appointments/:appointmentId/report', upload.single('report'), asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const requesterId = req.user.userId;

  const appointment = appointments[appointmentId];
  if (!appointment) {
    return res.status(404).json({ error: 'Appointment not found' });
  }
  if (appointment.patientId !== requesterId && appointment.doctorId !== requesterId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }
  if (!req.file) {
    return res.status(400).json({ error: 'report file is required' });
  }

  const ext = path.extname(req.file.originalname || '') || '.bin';
  const safeFileName = `${appointmentId}_${Date.now()}${ext}`;
  const filePath = path.join(reportsDir, safeFileName);
  fs.writeFileSync(filePath, req.file.buffer);

  const report = {
    reportId: `report_${Date.now()}`,
    fileName: req.file.originalname,
    storedFileName: safeFileName,
    mimeType: req.file.mimetype,
    size: req.file.size,
    uploadedBy: requesterId,
    uploadedAt: new Date(),
    url: `/uploads/reports/${safeFileName}`,
  };

  if (!appointment.reports) {
    appointment.reports = [];
  }
  appointment.reports.push(report);
  appointment.updatedAt = new Date();

  res.json({
    message: 'Report uploaded successfully',
    appointmentId,
    report,
  });
}));

// Retrieve reports attached to an appointment
router.get('/appointments/:appointmentId/report', asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const requesterId = req.user.userId;

  const appointment = appointments[appointmentId];
  if (!appointment) {
    return res.status(404).json({ error: 'Appointment not found' });
  }
  if (appointment.patientId !== requesterId && appointment.doctorId !== requesterId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  res.json({
    appointmentId,
    reports: appointment.reports || [],
  });
}));

// //////////////////////////////
// Notification endpoints
// //////////////////////////////

// Retrieve notifications for the authenticated user
router.get('/notifications', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  console.log(`📧 Getting notifications for user: ${userId}`);
  const userNotes = notifications[userId] || [];
  console.log(`📧 Found ${userNotes.length} notifications`);
  res.json({ notifications: userNotes });
}));


// Cancel appointment
router.put('/appointments/:appointmentId/cancel', asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const userId = req.user.userId;

  const appointment = appointments[appointmentId];
  if (!appointment) {
    return res.status(404).json({ error: 'Appointment not found' });
  }

  if (appointment.patientId !== userId && appointment.doctorId !== userId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  appointment.status = 'cancelled';
  appointment.cancelledAt = new Date();

  logger.info(`Appointment cancelled: ${appointmentId}`);

  res.json({
    appointmentId,
    message: 'Appointment cancelled',
    appointment
  });
}));

// --------------------------
// Admin routes
// --------------------------

// list all users (admins only)
router.get('/admin/users', authorizeRole('admin'), asyncHandler(async (req, res) => {
  // gather from auth module if available
  let userList = [];
  try {
    const { users } = require('./auth');
    userList = Object.values(users).map(u => ({
      userId: u.userId,
      email: u.email,
      name: u.name,
      role: u.role,
      specialization: u.specialization || null
    }));
  } catch (err) {
    userList = [];
  }
  res.json({ users: userList });
}));

// delete arbitrary user (admins only)
router.delete('/admin/users/:userId', authorizeRole('admin'), asyncHandler(async (req, res) => {
  const { userId } = req.params;
  // remove from auth store
  try {
    const { users } = require('./auth');
    Object.keys(users).forEach(email => {
      if (users[email].userId === userId) {
        delete users[email];
      }
    });
  } catch (err) {}

  // also strip doctor/patient maps
  if (doctors[userId]) delete doctors[userId];
  if (patients[userId]) delete patients[userId];

  // drop notifications
  if (notifications[userId]) delete notifications[userId];

  logger.info(`Admin deleted user ${userId}`);
  res.json({ message: 'User removed' });
}));

// send notification (admins only)
// body: { target: 'all'|'doctors'|'patients'|<userId>|<email>, message }
router.post('/admin/notify', authorizeRole('admin'), asyncHandler(async (req, res) => {
  const { target, message } = req.body;
  if (!target || !message) {
    return res.status(400).json({ error: 'target and message required' });
  }

  // load users
  let userEntries = [];
  try {
    const { users } = require('./auth');
    userEntries = Object.values(users);
  } catch (err) {
    userEntries = [];
  }

  const deliver = (userId) => pushNotification(userId, message);

  if (target === 'all') {
    userEntries.forEach(u => deliver(u.userId));
  } else if (target === 'doctors' || target === 'patients') {
    userEntries
      .filter(u => u.role === (target === 'doctors' ? 'doctor' : 'patient'))
      .forEach(u => deliver(u.userId));
  } else {
    // treat as userId or email
    const byId = userEntries.find(u => u.userId === target);
    if (byId) {
      deliver(byId.userId);
    } else {
      const byEmail = userEntries.find(u => u.email === target);
      if (byEmail) deliver(byEmail.userId);
      else return res.status(404).json({ error: 'Target user not found' });
    }
  }

  res.json({ message: 'Notification sent' });
}));

// expose data maps for other modules to update when needed
module.exports = router;
module.exports.doctors = doctors;
module.exports.patients = patients;
module.exports.appointments = appointments;
module.exports.notifications = notifications;
module.exports.healthMetrics = healthMetrics;
module.exports.chats = chats;
