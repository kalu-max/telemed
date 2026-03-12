const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { asyncHandler } = require('../middleware/errorHandler');
const { authorizeRole } = require('../middleware/auth');
const { fetchIceServers } = require('../services/iceServers');
const { fcm } = require('../config/firebase');
const logger = require('../utils/logger');
const { User, Doctor, Patient, Consultation, Notification: NotificationModel, Chat, ChatMessage, DoctorAvailabilitySlot, MedicalRecord, DoctorReview, AuditLog, Prescription } = require('../models/index');
const { Op } = require('sequelize');

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

// In-memory cache for fast lookups (seeded from DB on startup)
const doctors = {};
const patients = {};
const appointments = {};
const notifications = {};
const healthMetrics = {};
const chats = {};

// Seed in-memory caches from DB on startup
(async () => {
  try {
    // Load doctors
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
    // Load appointments
    const dbAppts = await Consultation.findAll();
    for (const a of dbAppts) {
      appointments[a.consultationId] = {
        appointmentId: a.consultationId,
        doctorId: a.doctorId,
        doctorName: a.doctorName || '',
        patientId: a.patientId,
        patientName: a.patientName || '',
        slotTime: a.scheduledTime,
        reason: a.reason || '',
        status: a.status || 'scheduled',
        createdAt: a.createdAt,
        notes: a.notes || '',
        completedAt: a.completedAt,
        cancelledAt: a.cancelledAt,
        reports: a.reports || [],
      };
    }
    // Load notifications
    const dbNotifs = await NotificationModel.findAll({ order: [['createdAt', 'ASC']] });
    for (const n of dbNotifs) {
      if (!notifications[n.userId]) notifications[n.userId] = [];
      notifications[n.userId].push({ message: n.message, timestamp: n.createdAt });
    }
    // Load chats
    const dbChats = await Chat.findAll({ include: [{ model: ChatMessage, order: [['createdAt', 'ASC']] }] });
    for (const c of dbChats) {
      const msgs = (c.ChatMessages || []).map(m => ({
        senderId: m.senderId,
        text: m.text || '',
        messageType: m.messageType || 'text',
        imageUrl: m.imageUrl || undefined,
        fileName: m.fileName || undefined,
        mimeType: m.mimeType || undefined,
        size: m.size || undefined,
        timestamp: m.createdAt,
      }));
      chats[c.chatId] = { chatId: c.chatId, participants: c.participants, messages: msgs };
    }
    logger.info(`Cache seeded: ${Object.keys(doctors).length} doctors, ${Object.keys(appointments).length} appointments, ${Object.keys(chats).length} chats`);
  } catch (e) {
    logger.warn(`Cache seed skipped: ${e.message}`);
  }
})();

// helper to queue notification for a user (persisted + in-memory + push)
async function pushNotification(userId, message) {
  const ts = new Date();
  if (!notifications[userId]) notifications[userId] = [];
  notifications[userId].push({ message, timestamp: ts });
  try {
    await NotificationModel.create({
      notificationId: `notif_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      userId,
      message,
      type: 'system',
    });
  } catch (_) {}
  // Send FCM push notification (best-effort)
  try {
    await fcm.sendPushToUser(userId, 'Telemedicine', message);
  } catch (_) {}
}

// patient health metrics store (kept in-memory — lightweight telemetry)
function ensureArrayMap(map, key) {
  if (!map[key]) map[key] = [];
  return map[key];
}

// Get RTC ICE/TURN configuration
router.get('/rtc/ice-servers', asyncHandler(async (req, res) => {
  const requesterId = req.user?.userId || 'unknown';
  const iceConfig = await fetchIceServers({ ttlSeconds: req.query.ttl });
  logger.info(`ICE config requested by ${requesterId} using provider ${iceConfig.provider}`);
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
  if (sortBy === 'rating') availableDoctors.sort((a, b) => b.rating - a.rating);
  else if (sortBy === 'experience') availableDoctors.sort((a, b) => b.yearsOfExperience - a.yearsOfExperience);
  res.json({ count: availableDoctors.length, doctors: availableDoctors });
}));

// Get doctor profile
router.get('/doctors/:doctorId', asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  const doctor = doctors[doctorId];
  if (!doctor) return res.status(404).json({ error: 'Doctor not found' });
  res.json(doctor);
}));

// Update doctor profile (doctors only)
router.put('/doctors/:doctorId', authorizeRole('doctor'), asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  const { bio, specialization, qualification, yearsOfExperience, consultationFee, availableSlots } = req.body;
  if (req.user.userId !== doctorId) return res.status(403).json({ error: 'Unauthorized' });

  if (!doctors[doctorId]) {
    doctors[doctorId] = { userId: doctorId, rating: 4.5, totalConsultations: 0, isOnline: false, isAvailable: false };
  }
  const doctor = doctors[doctorId];
  doctor.bio = bio || doctor.bio;
  doctor.specialization = specialization || doctor.specialization;
  doctor.qualification = qualification || doctor.qualification;
  doctor.yearsOfExperience = yearsOfExperience || doctor.yearsOfExperience;
  doctor.consultationFee = consultationFee || doctor.consultationFee;
  doctor.availableSlots = availableSlots || doctor.availableSlots || [];
  doctor.updatedAt = new Date();

  // Persist to DB
  try {
    await Doctor.upsert({
      userId: doctorId,
      bio: doctor.bio,
      specialization: doctor.specialization,
      yearsOfExperience: doctor.yearsOfExperience,
      consultationFee: doctor.consultationFee,
    });
  } catch (e) { logger.warn(`Doctor DB update failed: ${e.message}`); }

  logger.info(`Doctor profile updated: ${doctorId}`);
  res.json({ message: 'Profile updated successfully', doctor });
}));

// Delete doctor account
router.delete('/doctors/:doctorId', authorizeRole('doctor'), asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  if (req.user.userId !== doctorId) return res.status(403).json({ error: 'Unauthorized' });
  if (doctors[doctorId]) delete doctors[doctorId];
  try { await Doctor.destroy({ where: { userId: doctorId } }); } catch (_) {}
  try { await User.destroy({ where: { userId: doctorId } }); } catch (_) {}
  logger.info(`Doctor account deleted: ${doctorId}`);
  res.json({ message: 'Doctor account deleted' });
}));

// Get patient profile
router.get('/patients/:patientId', asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  // Try cache first, then DB
  let patient = patients[patientId];
  if (!patient) {
    try {
      const dbPat = await Patient.findByPk(patientId, { include: [{ model: User, attributes: ['name', 'email', 'phone'] }] });
      if (dbPat) {
        patient = {
          userId: patientId,
          name: dbPat.User?.name,
          email: dbPat.User?.email,
          phone: dbPat.User?.phone,
          dateOfBirth: dbPat.dateOfBirth,
          gender: dbPat.gender,
          medicalHistory: dbPat.medicalHistory,
        };
        patients[patientId] = patient;
      }
    } catch (_) {}
  }
  if (!patient) return res.status(404).json({ error: 'Patient not found' });
  res.json(patient);
}));

// Update patient profile (patients only)
router.put('/patients/:patientId', authorizeRole('patient'), asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { name, dateOfBirth, gender, phone, address, medicalHistory, bloodType } = req.body;
  if (req.user.userId !== patientId) return res.status(403).json({ error: 'Unauthorized' });

  if (!patients[patientId]) {
    patients[patientId] = { userId: patientId, medicalHistory: [], appointments: [] };
  }
  const patient = patients[patientId];
  patient.dateOfBirth = dateOfBirth || patient.dateOfBirth;
  patient.gender = gender || patient.gender;
  patient.phone = phone || patient.phone;
  patient.address = address || patient.address;
  patient.bloodType = bloodType || patient.bloodType;
  patient.medicalHistory = medicalHistory || patient.medicalHistory;
  patient.updatedAt = new Date();

  // Persist to DB
  try {
    await Patient.upsert({ userId: patientId, dateOfBirth, gender, medicalHistory: typeof medicalHistory === 'string' ? medicalHistory : JSON.stringify(medicalHistory || '') });
    if (name || phone) await User.update({ ...(name && { name }), ...(phone && { phone }) }, { where: { userId: patientId } });
  } catch (e) { logger.warn(`Patient DB update failed: ${e.message}`); }

  logger.info(`Patient profile updated: ${patientId}`);
  res.json({ message: 'Profile updated successfully', patient });
}));

// Book appointment (persisted to DB)
router.post('/appointments/book', authorizeRole('patient'), asyncHandler(async (req, res) => {
  const { doctorId, slotTime, reason } = req.body;
  const patientId = req.user.userId;
  if (!doctorId || !slotTime || !reason) return res.status(400).json({ error: 'Missing required fields' });

  const appointmentId = `appt_${Date.now()}`;
  const patientName = req.user.name || patientId;
  const doctorName = doctors[doctorId]?.name || 'Doctor';

  const apptData = {
    appointmentId,
    doctorId,
    doctorName,
    patientId,
    patientName,
    slotTime: new Date(slotTime),
    reason,
    status: 'scheduled',
    createdAt: new Date(),
    notes: '',
  };
  appointments[appointmentId] = apptData;

  // Persist
  try {
    await Consultation.create({
      consultationId: appointmentId,
      patientId,
      doctorId,
      patientName,
      doctorName,
      scheduledTime: new Date(slotTime),
      reason,
      status: 'scheduled',
    });
  } catch (e) { logger.warn(`Appointment DB create failed: ${e.message}`); }

  logger.info(`Appointment booked: ${appointmentId} (Patient: ${patientId}, Doctor: ${doctorId})`);
  pushNotification(doctorId, `New consultation request from ${patientName}: ${reason}`);
  emitToUser(doctorId, 'newAppointment', {
    appointmentId, patientId, patientName, slotTime, reason, status: 'scheduled', createdAt: new Date().toISOString(),
  });

  res.status(201).json({ appointmentId, message: 'Appointment booked successfully', appointment: appointments[appointmentId] });
}));

// Health metrics
router.post('/patients/:patientId/metrics', authorizeRole('patient'), asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  if (req.user.userId !== patientId) return res.status(403).json({ error: 'Unauthorized' });
  const { metric, value } = req.body;
  if (!metric || value == null) return res.status(400).json({ error: 'metric and value required' });
  ensureArrayMap(healthMetrics, patientId).push({ metric, value, timestamp: new Date() });
  res.status(201).json({ message: 'Metric added' });
}));

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

// ------- Chat endpoints (persisted) -------

router.post('/chats/start', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { participants } = req.body;
  if (!participants || !Array.isArray(participants)) return res.status(400).json({ error: 'participants array required (2+)' });

  const normalizedParticipants = Array.from(
    new Set(participants.map((id) => `${id || ''}`.trim()).filter(Boolean).concat(requester.userId))
  );
  if (normalizedParticipants.length < 2) return res.status(400).json({ error: 'participants array required (2+)' });

  // Reuse existing 1:1 chat
  const existingChat = Object.values(chats).find((chat) => {
    if (!Array.isArray(chat.participants)) return false;
    if (chat.participants.length !== normalizedParticipants.length) return false;
    return normalizedParticipants.every((pid) => chat.participants.includes(pid));
  });
  if (existingChat) return res.json({ chatId: existingChat.chatId, reused: true, chat: existingChat });

  const chatId = `chat_${Date.now()}`;
  chats[chatId] = { chatId, participants: normalizedParticipants, messages: [] };

  try { await Chat.create({ chatId, participants: normalizedParticipants }); } catch (e) { logger.warn(`Chat DB create: ${e.message}`); }

  res.status(201).json({ chatId, chat: chats[chatId] });
}));

router.post('/chats/:chatId/message', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: 'text required' });

  const msg = { senderId: requester.userId, text, messageType: 'text', timestamp: new Date() };
  chat.messages.push(msg);

  try {
    await ChatMessage.create({ messageId: `msg_${Date.now()}_${Math.random().toString(36).slice(2,6)}`, chatId, senderId: requester.userId, text, messageType: 'text' });
  } catch (_) {}

  try {
    chat.participants.forEach(p => {
      if (p !== requester.userId) {
        const snippet = text.length > 80 ? text.substring(0, 77) + '...' : text;
        pushNotification(p, `New message from ${requester.name || requester.userId}: ${snippet}`);
      }
    });
  } catch (_) {}
  res.json({ message: 'Message sent' });
}));

router.post('/chats/:chatId/message/media', upload.single('image'), asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  if (!req.file) return res.status(400).json({ error: 'image file is required' });

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

  try {
    await ChatMessage.create({ messageId: `msg_${Date.now()}_${Math.random().toString(36).slice(2,6)}`, chatId, senderId: requester.userId, text: message.text, messageType: 'image', imageUrl: message.imageUrl, fileName: message.fileName, mimeType: message.mimeType, size: message.size });
  } catch (_) {}

  res.status(201).json({ message: 'Image uploaded successfully', chatId, data: message });
}));

router.get('/chats/:chatId/messages', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  res.json({ messages: chat.messages });
}));

router.get('/chats', asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const userId = req.query.userId || requester.userId;
  if (userId !== requester.userId && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  const list = Object.values(chats).filter(c => c.participants.includes(userId));
  // Enrich with participant names from in-memory caches so clients can show real names
  const enriched = list.map(chat => {
    const participantNames = {};
    for (const pid of (chat.participants || [])) {
      if (doctors[pid]) {
        participantNames[pid] = doctors[pid].name || pid;
      } else {
        // Try to find the name from appointments (patient name)
        const appt = Object.values(appointments).find(a => a.patientId === pid || a.doctorId === pid);
        if (appt) {
          participantNames[pid] = appt.patientId === pid ? (appt.patientName || pid) : (appt.doctorName || pid);
        } else {
          participantNames[pid] = pid; // fallback: raw id
        }
      }
    }
    return { ...chat, participantNames };
  });
  res.json({ count: enriched.length, chats: enriched });
}));

// Get user appointments
router.get('/appointments', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const role = req.user.role;
  const userAppointments = Object.values(appointments).filter(appt => {
    if (role === 'patient') return appt.patientId === userId;
    else if (role === 'doctor') return appt.doctorId === userId;
    return false;
  });
  res.json({ count: userAppointments.length, appointments: userAppointments });
}));

// Update appointment status (persisted)
router.put('/appointments/:appointmentId', asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const { status, notes } = req.body;
  const requesterId = req.user.userId;
  const appointment = appointments[appointmentId];
  if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
  if (appointment.patientId !== requesterId && appointment.doctorId !== requesterId) return res.status(403).json({ error: 'Unauthorized' });

  const validStatuses = ['scheduled', 'connected', 'in-progress', 'completed', 'cancelled', 'missed'];
  if (!status || !validStatuses.includes(status)) return res.status(400).json({ error: `Invalid status. Allowed: ${validStatuses.join(', ')}` });

  appointment.status = status;
  appointment.updatedAt = new Date();
  if (typeof notes === 'string') appointment.notes = notes;
  if (status === 'completed') appointment.completedAt = new Date();
  if (status === 'cancelled') appointment.cancelledAt = new Date();

  // Persist
  try {
    const updates = { status, notes: appointment.notes };
    if (status === 'completed') updates.completedAt = new Date();
    if (status === 'cancelled') updates.cancelledAt = new Date();
    if (status === 'connected') updates.startTime = new Date();
    if (status === 'completed') updates.endTime = new Date();
    await Consultation.update(updates, { where: { consultationId: appointmentId } });
  } catch (e) { logger.warn(`Appt DB update: ${e.message}`); }

  const otherUserId = appointment.patientId === requesterId ? appointment.doctorId : appointment.patientId;
  pushNotification(otherUserId, `Appointment ${appointmentId} updated to ${status}`);

  if (status === 'connected' || status === 'in-progress') {
    emitToUser(otherUserId, 'appointmentAccepted', { appointmentId, status, doctorId: appointment.doctorId, patientId: appointment.patientId });
  } else if (status === 'cancelled') {
    emitToUser(otherUserId, 'appointmentCancelled', { appointmentId });
  }

  res.json({ appointmentId, message: 'Appointment status updated', appointment });
}));

// Upload report for appointment
router.post('/appointments/:appointmentId/report', upload.single('report'), asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const requesterId = req.user.userId;
  const appointment = appointments[appointmentId];
  if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
  if (appointment.patientId !== requesterId && appointment.doctorId !== requesterId) return res.status(403).json({ error: 'Unauthorized' });
  if (!req.file) return res.status(400).json({ error: 'report file is required' });

  const ext = path.extname(req.file.originalname || '') || '.bin';
  const safeFileName = `${appointmentId}_${Date.now()}${ext}`;
  const filePath = path.join(reportsDir, safeFileName);
  fs.writeFileSync(filePath, req.file.buffer);

  const report = {
    reportId: `report_${Date.now()}`, fileName: req.file.originalname, storedFileName: safeFileName,
    mimeType: req.file.mimetype, size: req.file.size, uploadedBy: requesterId, uploadedAt: new Date(), url: `/uploads/reports/${safeFileName}`,
  };
  if (!appointment.reports) appointment.reports = [];
  appointment.reports.push(report);
  appointment.updatedAt = new Date();

  try { await Consultation.update({ reports: appointment.reports }, { where: { consultationId: appointmentId } }); } catch (_) {}

  res.json({ message: 'Report uploaded successfully', appointmentId, report });
}));

router.get('/appointments/:appointmentId/report', asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const requesterId = req.user.userId;
  const appointment = appointments[appointmentId];
  if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
  if (appointment.patientId !== requesterId && appointment.doctorId !== requesterId) return res.status(403).json({ error: 'Unauthorized' });
  res.json({ appointmentId, reports: appointment.reports || [] });
}));

// Notifications
router.get('/notifications', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const userNotes = notifications[userId] || [];
  res.json({ notifications: userNotes });
}));

// Cancel appointment
router.put('/appointments/:appointmentId/cancel', asyncHandler(async (req, res) => {
  const { appointmentId } = req.params;
  const userId = req.user.userId;
  const appointment = appointments[appointmentId];
  if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
  if (appointment.patientId !== userId && appointment.doctorId !== userId) return res.status(403).json({ error: 'Unauthorized' });
  appointment.status = 'cancelled';
  appointment.cancelledAt = new Date();
  try { await Consultation.update({ status: 'cancelled', cancelledAt: new Date() }, { where: { consultationId: appointmentId } }); } catch (_) {}
  logger.info(`Appointment cancelled: ${appointmentId}`);
  res.json({ appointmentId, message: 'Appointment cancelled', appointment });
}));

// ----- Doctor Availability Slots -----

// Get availability slots for a doctor
router.get('/doctors/:doctorId/availability', asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  const slots = await DoctorAvailabilitySlot.findAll({
    where: { doctorId, isActive: true },
    order: [['dayOfWeek', 'ASC'], ['startTime', 'ASC']],
  });
  res.json({ doctorId, slots });
}));

// Set/update availability slots (doctor only)
router.put('/doctors/:doctorId/availability', authorizeRole('doctor'), asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  if (req.user.userId !== doctorId) return res.status(403).json({ error: 'Unauthorized' });
  const { slots } = req.body; // array of { dayOfWeek, startTime, endTime, slotDurationMinutes? }
  if (!Array.isArray(slots)) return res.status(400).json({ error: 'slots array required' });

  // Replace all slots for this doctor
  await DoctorAvailabilitySlot.destroy({ where: { doctorId } });
  const created = [];
  for (const s of slots) {
    if (s.dayOfWeek == null || !s.startTime || !s.endTime) continue;
    const slot = await DoctorAvailabilitySlot.create({
      slotId: `slot_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      doctorId,
      dayOfWeek: s.dayOfWeek,
      startTime: s.startTime,
      endTime: s.endTime,
      slotDurationMinutes: s.slotDurationMinutes || 30,
      isActive: true,
    });
    created.push(slot);
  }
  logger.info(`Doctor ${doctorId} updated ${created.length} availability slots`);
  res.json({ message: 'Availability updated', slots: created });
}));

// Get available time slots for a specific doctor on a date
router.get('/doctors/:doctorId/slots', asyncHandler(async (req, res) => {
  const { doctorId } = req.params;
  const { date } = req.query; // ISO date string e.g. 2025-01-15
  if (!date) return res.status(400).json({ error: 'date query param required (YYYY-MM-DD)' });

  const targetDate = new Date(date);
  const dayOfWeek = targetDate.getDay(); // 0=Sun .. 6=Sat

  const availSlots = await DoctorAvailabilitySlot.findAll({
    where: { doctorId, dayOfWeek, isActive: true },
    order: [['startTime', 'ASC']],
  });

  if (availSlots.length === 0) {
    return res.json({ doctorId, date, slots: [], message: 'No availability on this day' });
  }

  // Get existing bookings for this doctor on this date
  const dayStart = new Date(date + 'T00:00:00Z');
  const dayEnd = new Date(date + 'T23:59:59Z');
  const { Op } = require('sequelize');
  const existingBookings = await Consultation.findAll({
    where: {
      doctorId,
      scheduledTime: { [Op.between]: [dayStart, dayEnd] },
      status: { [Op.notIn]: ['cancelled'] },
    },
  });
  const bookedTimes = new Set(existingBookings.map(b => {
    const d = new Date(b.scheduledTime);
    return `${String(d.getUTCHours()).padStart(2, '0')}:${String(d.getUTCMinutes()).padStart(2, '0')}`;
  }));

  // Generate individual time slots
  const timeSlots = [];
  for (const avail of availSlots) {
    const [startH, startM] = avail.startTime.split(':').map(Number);
    const [endH, endM] = avail.endTime.split(':').map(Number);
    const duration = avail.slotDurationMinutes || 30;
    let currentMin = startH * 60 + startM;
    const endMin = endH * 60 + endM;

    while (currentMin + duration <= endMin) {
      const hh = String(Math.floor(currentMin / 60)).padStart(2, '0');
      const mm = String(currentMin % 60).padStart(2, '0');
      const timeStr = `${hh}:${mm}`;
      timeSlots.push({
        time: timeStr,
        available: !bookedTimes.has(timeStr),
      });
      currentMin += duration;
    }
  }

  res.json({ doctorId, date, slots: timeSlots });
}));

// ----- Search -----

router.get('/search', asyncHandler(async (req, res) => {
  const { q } = req.query;
  const requester = req.user;
  if (!q || q.trim().length < 2) return res.status(400).json({ error: 'Search query must be at least 2 characters' });

  const query = q.trim().toLowerCase();
  const results = { doctors: [], appointments: [], patients: [] };

  // Search doctors
  results.doctors = Object.values(doctors).filter(d =>
    (d.name || '').toLowerCase().includes(query) ||
    (d.specialization || '').toLowerCase().includes(query)
  ).slice(0, 20);

  // Search appointments the user has access to
  const userAppts = Object.values(appointments).filter(appt => {
    if (requester.role === 'admin') return true;
    if (requester.role === 'patient') return appt.patientId === requester.userId;
    if (requester.role === 'doctor') return appt.doctorId === requester.userId;
    return false;
  });
  results.appointments = userAppts.filter(a =>
    (a.doctorName || '').toLowerCase().includes(query) ||
    (a.patientName || '').toLowerCase().includes(query) ||
    (a.reason || '').toLowerCase().includes(query) ||
    (a.appointmentId || '').toLowerCase().includes(query)
  ).slice(0, 20);

  // Admins and doctors can search patients
  if (requester.role === 'admin' || requester.role === 'doctor') {
    try {
      const { Op } = require('sequelize');
      const dbPatients = await User.findAll({
        where: {
          role: 'patient',
          [Op.or]: [
            { name: { [Op.like]: `%${query}%` } },
            { email: { [Op.like]: `%${query}%` } },
          ]
        },
        attributes: ['userId', 'name', 'email'],
        limit: 20
      });
      results.patients = dbPatients.map(p => ({ userId: p.userId, name: p.name, email: p.email }));
    } catch (_) {}
  }

  res.json(results);
}));

// ----- File/document sharing in chat -----

router.post('/chats/:chatId/message/file', upload.single('file'), asyncHandler(async (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  const { chatId } = req.params;
  const chat = chats[chatId];
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  if (!chat.participants.includes(requester.userId) && requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
  if (!req.file) return res.status(400).json({ error: 'file is required' });

  // Validate file type
  const allowedMimeTypes = [
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain', 'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ];
  if (!allowedMimeTypes.includes(req.file.mimetype)) {
    return res.status(400).json({ error: 'File type not allowed' });
  }

  const ext = path.extname(req.file.originalname || '') || '.bin';
  const safeFileName = `${chatId}_${Date.now()}${ext}`;
  const filePath2 = path.join(chatMediaDir, safeFileName);
  fs.writeFileSync(filePath2, req.file.buffer);

  const isImage = req.file.mimetype.startsWith('image/');
  const message = {
    senderId: requester.userId,
    messageType: isImage ? 'image' : 'file',
    text: req.body?.caption || '',
    imageUrl: isImage ? `/uploads/chat-media/${safeFileName}` : undefined,
    fileUrl: !isImage ? `/uploads/chat-media/${safeFileName}` : undefined,
    fileName: req.file.originalname,
    mimeType: req.file.mimetype,
    size: req.file.size,
    timestamp: new Date(),
  };
  chat.messages.push(message);

  try {
    await ChatMessage.create({
      messageId: `msg_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      chatId,
      senderId: requester.userId,
      text: message.text,
      messageType: message.messageType,
      imageUrl: message.imageUrl || null,
      fileUrl: message.fileUrl || null,
      fileName: message.fileName,
      mimeType: message.mimeType,
      size: message.size,
    });
  } catch (_) {}

  try {
    chat.participants.forEach(p => {
      if (p !== requester.userId) {
        pushNotification(p, `${requester.name || requester.userId} shared a file: ${message.fileName}`);
      }
    });
  } catch (_) {}

  res.status(201).json({ message: 'File uploaded successfully', chatId, data: message });
}));

// ----- FCM Token Registration -----

router.post('/fcm-token', asyncHandler(async (req, res) => {
  const { token } = req.body;
  const userId = req.user.userId;
  if (!token) return res.status(400).json({ error: 'token is required' });
  try {
    await User.update({ fcmToken: token }, { where: { userId } });
  } catch (_) {}
  res.json({ message: 'FCM token registered' });
}));

// ----- Admin routes -----

router.get('/admin/users', authorizeRole('admin'), asyncHandler(async (req, res) => {
  try {
    const users = await User.findAll({ attributes: ['userId', 'email', 'name', 'role'] });
    const userList = users.map(u => ({ userId: u.userId, email: u.email, name: u.name, role: u.role, specialization: null }));
    // Attach specialization for doctors
    for (const u of userList) {
      if (u.role === 'doctor' && doctors[u.userId]) u.specialization = doctors[u.userId].specialization;
    }
    res.json({ users: userList });
  } catch (e) {
    res.json({ users: [] });
  }
}));

router.delete('/admin/users/:userId', authorizeRole('admin'), asyncHandler(async (req, res) => {
  const { userId } = req.params;
  if (doctors[userId]) delete doctors[userId];
  if (patients[userId]) delete patients[userId];
  if (notifications[userId]) delete notifications[userId];
  try {
    await Doctor.destroy({ where: { userId } });
    await Patient.destroy({ where: { userId } });
    await User.destroy({ where: { userId } });
  } catch (_) {}
  logger.info(`Admin deleted user ${userId}`);
  res.json({ message: 'User removed' });
}));

router.post('/admin/notify', authorizeRole('admin'), asyncHandler(async (req, res) => {
  const { target, message } = req.body;
  if (!target || !message) return res.status(400).json({ error: 'target and message required' });

  let users = [];
  try { users = await User.findAll({ attributes: ['userId', 'email', 'role'] }); } catch (_) {}

  if (target === 'all') {
    for (const u of users) await pushNotification(u.userId, message);
  } else if (target === 'doctors' || target === 'patients') {
    const role = target === 'doctors' ? 'doctor' : 'patient';
    for (const u of users.filter(u => u.role === role)) await pushNotification(u.userId, message);
  } else {
    const byId = users.find(u => u.userId === target);
    const byEmail = users.find(u => u.email === target);
    const found = byId || byEmail;
    if (found) await pushNotification(found.userId, message);
    else return res.status(404).json({ error: 'Target user not found' });
  }
  res.json({ message: 'Notification sent' });
}));

// System statistics for admin
router.get('/admin/stats', authorizeRole('admin'), asyncHandler(async (req, res) => {
  const totalUsers = await User.count();
  const totalDoctors = await User.count({ where: { role: 'doctor' } });
  const totalPatients = await User.count({ where: { role: 'patient' } });
  const totalAppointments = Object.keys(appointments).length;
  const activeAppointments = Object.values(appointments).filter(a => ['scheduled', 'connected', 'in-progress'].includes(a.status)).length;
  const completedAppointments = Object.values(appointments).filter(a => a.status === 'completed').length;
  const totalChats = Object.keys(chats).length;
  res.json({
    totalUsers, totalDoctors, totalPatients,
    totalAppointments, activeAppointments, completedAppointments,
    totalChats,
  });
}));

// ---- HIPAA Audit Logging Helper ----
async function auditLog(req, action, resourceType, resourceId, details) {
  try {
    await AuditLog.create({
      logId: `audit_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      userId: req.user?.userId || 'system',
      action,
      resourceType,
      resourceId: resourceId || null,
      details: typeof details === 'string' ? details : JSON.stringify(details || {}),
      ipAddress: req.ip || req.headers['x-forwarded-for'] || 'unknown',
      userAgent: req.headers['user-agent'] || 'unknown',
    });
  } catch (e) { logger.warn(`Audit log failed: ${e.message}`); }
}

// ---- #7 Medical Records for Patient ----
router.get('/medical-records', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const role = req.user.role;
  let records;
  if (role === 'patient') {
    records = await MedicalRecord.findAll({ where: { patientId: userId }, order: [['createdAt', 'DESC']] });
  } else if (role === 'doctor') {
    const patientId = req.query.patientId;
    if (!patientId) return res.status(400).json({ error: 'patientId required' });
    records = await MedicalRecord.findAll({ where: { patientId }, order: [['createdAt', 'DESC']] });
  } else {
    records = await MedicalRecord.findAll({ order: [['createdAt', 'DESC']], limit: 100 });
  }
  await auditLog(req, 'VIEW', 'medical_record', null, { count: records.length });
  res.json({ records });
}));

router.post('/medical-records', asyncHandler(async (req, res) => {
  const { patientId, consultationId, diagnosis, treatment } = req.body;
  if (!patientId || !diagnosis) return res.status(400).json({ error: 'patientId and diagnosis required' });
  const record = await MedicalRecord.create({
    recordId: `mr_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    patientId,
    consultationId: consultationId || null,
    diagnosis,
    treatment: treatment || null,
  });
  await auditLog(req, 'CREATE', 'medical_record', record.recordId, { patientId });
  res.status(201).json({ record });
}));

// ---- #8 Doctor Review/Rating System ----
router.get('/doctors/:doctorId/reviews', asyncHandler(async (req, res) => {
  const reviews = await DoctorReview.findAll({
    where: { doctorId: req.params.doctorId },
    include: [{ model: User, as: 'reviewer', attributes: ['name'] }],
    order: [['createdAt', 'DESC']],
  });
  const mapped = reviews.map(r => ({
    reviewId: r.reviewId,
    rating: r.rating,
    comment: r.comment,
    patientName: r.isAnonymous ? 'Anonymous' : (r.reviewer?.name || 'Patient'),
    isAnonymous: r.isAnonymous,
    createdAt: r.createdAt,
  }));
  const avg = mapped.length ? (mapped.reduce((s, r) => s + r.rating, 0) / mapped.length).toFixed(2) : 0;
  res.json({ reviews: mapped, averageRating: parseFloat(avg), totalReviews: mapped.length });
}));

router.post('/doctors/:doctorId/reviews', asyncHandler(async (req, res) => {
  const { rating, comment, consultationId, isAnonymous } = req.body;
  if (!rating || rating < 1 || rating > 5) return res.status(400).json({ error: 'Rating must be 1-5' });
  if (req.user.role !== 'patient') return res.status(403).json({ error: 'Only patients can leave reviews' });
  // Prevent duplicate reviews per consultation
  if (consultationId) {
    const existing = await DoctorReview.findOne({ where: { consultationId, patientId: req.user.userId } });
    if (existing) return res.status(409).json({ error: 'You already reviewed this consultation' });
  }
  const review = await DoctorReview.create({
    reviewId: `rev_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    doctorId: req.params.doctorId,
    patientId: req.user.userId,
    consultationId: consultationId || null,
    rating: parseInt(rating),
    comment: comment || null,
    isAnonymous: !!isAnonymous,
  });
  // Update doctor average rating
  const allReviews = await DoctorReview.findAll({ where: { doctorId: req.params.doctorId } });
  const avgRating = allReviews.reduce((s, r) => s + r.rating, 0) / allReviews.length;
  await Doctor.update({ rating: avgRating.toFixed(2) }, { where: { userId: req.params.doctorId } });
  await auditLog(req, 'CREATE', 'doctor_review', review.reviewId, { doctorId: req.params.doctorId, rating });
  res.status(201).json({ review });
}));

// ---- #16 Message search in chat ----
router.get('/chats/:chatId/search', asyncHandler(async (req, res) => {
  const { q } = req.query;
  if (!q || q.length < 2) return res.status(400).json({ error: 'Query must be at least 2 characters' });
  const messages = await ChatMessage.findAll({
    where: {
      chatId: req.params.chatId,
      text: { [Op.like]: `%${q}%` },
    },
    order: [['createdAt', 'DESC']],
    limit: 50,
  });
  res.json({ messages });
}));

// ---- #17 Consultation notes for patient ----
router.get('/consultations/:consultationId/notes', asyncHandler(async (req, res) => {
  const consult = await Consultation.findOne({ where: { consultationId: req.params.consultationId } });
  if (!consult) return res.status(404).json({ error: 'Consultation not found' });
  // Only the patient or doctor involved can see notes
  if (req.user.userId !== consult.patientId && req.user.userId !== consult.doctorId && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied' });
  }
  await auditLog(req, 'VIEW', 'consultation', consult.consultationId, { field: 'notes' });
  res.json({
    consultationId: consult.consultationId,
    notes: consult.notes || '',
    prescription: consult.prescription || '',
    doctorName: consult.doctorName,
    completedAt: consult.completedAt,
    status: consult.status,
  });
}));

router.put('/consultations/:consultationId/notes', asyncHandler(async (req, res) => {
  const { notes } = req.body;
  const consult = await Consultation.findOne({ where: { consultationId: req.params.consultationId } });
  if (!consult) return res.status(404).json({ error: 'Consultation not found' });
  if (req.user.userId !== consult.doctorId && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Only the doctor can update notes' });
  }
  await consult.update({ notes });
  // Also update in-memory cache
  if (appointments[consult.consultationId]) {
    appointments[consult.consultationId].notes = notes;
  }
  await auditLog(req, 'UPDATE', 'consultation', consult.consultationId, { field: 'notes' });
  res.json({ message: 'Notes updated', notes });
}));

// ---- #26 HIPAA Audit Trail ----
router.get('/admin/audit-logs', authorizeRole('admin'), asyncHandler(async (req, res) => {
  const { userId, resourceType, startDate, endDate, limit: queryLimit } = req.query;
  const where = {};
  if (userId) where.userId = userId;
  if (resourceType) where.resourceType = resourceType;
  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt[Op.gte] = new Date(startDate);
    if (endDate) where.createdAt[Op.lte] = new Date(endDate);
  }
  const logs = await AuditLog.findAll({
    where,
    order: [['createdAt', 'DESC']],
    limit: Math.min(parseInt(queryLimit) || 100, 500),
  });
  res.json({ logs });
}));

// ---- #27 Export/Download Patient Data (GDPR) ----
router.get('/patients/:patientId/export', asyncHandler(async (req, res) => {
  const targetId = req.params.patientId;
  // Only the patient themselves or an admin can export
  if (req.user.userId !== targetId && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied' });
  }
  const user = await User.findByPk(targetId);
  const patient = await Patient.findByPk(targetId);
  const consults = await Consultation.findAll({ where: { patientId: targetId } });
  const records = await MedicalRecord.findAll({ where: { patientId: targetId } });
  const prescriptions = await Prescription.findAll({ where: { patientId: targetId } });
  const reviews = await DoctorReview.findAll({ where: { patientId: targetId } });
  const notifs = await NotificationModel.findAll({ where: { userId: targetId } });

  await auditLog(req, 'EXPORT', 'patient_data', targetId, { format: 'json' });

  res.setHeader('Content-Disposition', `attachment; filename=patient_data_${targetId}.json`);
  res.setHeader('Content-Type', 'application/json');
  res.json({
    exportDate: new Date().toISOString(),
    user: user ? { name: user.name, email: user.email, phone: user.phone, createdAt: user.createdAt } : null,
    patient: patient ? {
      dateOfBirth: patient.dateOfBirth, gender: patient.gender,
      medicalHistory: patient.medicalHistory, emergencyContact: patient.emergencyContact,
      allergies: patient.allergies, currentMedications: patient.currentMedications,
      insuranceProvider: patient.insuranceProvider,
    } : null,
    consultations: consults.map(c => ({
      id: c.consultationId, doctorName: c.doctorName, scheduledTime: c.scheduledTime,
      status: c.status, reason: c.reason, notes: c.notes, completedAt: c.completedAt,
    })),
    medicalRecords: records.map(r => ({
      id: r.recordId, diagnosis: r.diagnosis, treatment: r.treatment, createdAt: r.createdAt,
    })),
    prescriptions: prescriptions.map(p => ({
      id: p.prescriptionId, diagnosis: p.diagnosis, medications: p.medications,
      status: p.status, createdAt: p.createdAt,
    })),
    reviews: reviews.map(r => ({
      doctorId: r.doctorId, rating: r.rating, comment: r.comment, createdAt: r.createdAt,
    })),
    notifications: notifs.map(n => ({
      message: n.message, type: n.type, createdAt: n.createdAt,
    })),
  });
}));

// ---- #6 Appointment Reminder Check ----
// Called by a cron/scheduler — returns upcoming appointments within a window
router.get('/reminders/upcoming', asyncHandler(async (req, res) => {
  const windowMinutes = parseInt(req.query.windowMinutes) || 30;
  const now = new Date();
  const windowEnd = new Date(now.getTime() + windowMinutes * 60000);
  const upcoming = await Consultation.findAll({
    where: {
      scheduledTime: { [Op.between]: [now, windowEnd] },
      status: { [Op.in]: ['scheduled', 'pending'] },
    },
  });
  // Send reminders
  for (const appt of upcoming) {
    await pushNotification(appt.patientId, `Reminder: Your appointment with ${appt.doctorName || 'your doctor'} is in ${windowMinutes} minutes`);
    await pushNotification(appt.doctorId, `Reminder: Appointment with ${appt.patientName || 'patient'} is in ${windowMinutes} minutes`);
  }
  res.json({ reminded: upcoming.length });
}));

module.exports = router;
module.exports.doctors = doctors;
module.exports.patients = patients;
module.exports.appointments = appointments;
module.exports.notifications = notifications;
module.exports.healthMetrics = healthMetrics;
module.exports.chats = chats;
module.exports.pushNotification = pushNotification;
