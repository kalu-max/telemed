const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { asyncHandler } = require('../middleware/errorHandler');
const logger = require('../utils/logger');
const { fcm } = require('../config/firebase');

const router = express.Router();

// Setup recording storage
const recordingsDir = path.join(__dirname, '..', '..', 'public', 'uploads', 'recordings');
if (!fs.existsSync(recordingsDir)) {
  fs.mkdirSync(recordingsDir, { recursive: true });
}
const recordingUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 }, // 100MB max recording
});

// Database
const callHistory = {};
const ongoingCalls = {};
const missedCalls = {}; // userId -> [{ callId, from, timestamp, type }]

// Initiate a call
router.post('/initiate', asyncHandler(async (req, res) => {
  const { recipientId, type, initiatorName } = req.body;
  const initiatorId = req.user.userId;

  if (!recipientId || !type) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const callId = `call_${Date.now()}`;
  const callData = {
    callId,
    initiatorId,
    initiatorName,
    recipientId,
    type, // 'audio' or 'video'
    status: 'ringing', // ringing, connected, ended
    startTime: new Date(),
    endTime: null,
    duration: 0,
    networkQuality: 'good',
    recordingUrl: null,
    notes: ''
  };

  ongoingCalls[callId] = callData;
  logger.info(`Call initiated: ${callId} (${initiatorId} -> ${recipientId})`);

  res.status(201).json({
    callId,
    message: 'Call initiated, waiting for recipient to answer'
  });
}));

// Answer a call
router.post('/answer', asyncHandler(async (req, res) => {
  const { callId } = req.body;
  const userId = req.user.userId;

  if (!callId || !ongoingCalls[callId]) {
    return res.status(404).json({ error: 'Call not found' });
  }

  const call = ongoingCalls[callId];
  if (call.recipientId !== userId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  call.status = 'connected';
  call.connectTime = new Date();

  logger.info(`Call answered: ${callId}`);

  res.json({
    callId,
    message: 'Call answered',
    call
  });
}));

// Reject a call
router.post('/reject', asyncHandler(async (req, res) => {
  const { callId } = req.body;
  const userId = req.user.userId;

  if (!callId || !ongoingCalls[callId]) {
    return res.status(404).json({ error: 'Call not found' });
  }

  const call = ongoingCalls[callId];
  call.status = 'rejected';
  call.endTime = new Date();

  // Track as missed call for the initiator
  const missedUserId = call.initiatorId;
  if (!missedCalls[call.recipientId]) missedCalls[call.recipientId] = [];
  missedCalls[call.recipientId].push({
    callId,
    from: call.initiatorId,
    fromName: call.initiatorName,
    type: call.type,
    timestamp: new Date(),
    status: 'rejected',
  });

  // Save to history
  callHistory[callId] = call;
  delete ongoingCalls[callId];

  // Notify initiator of rejection
  try { await fcm.sendPushToUser(missedUserId, 'Call Rejected', `Your ${call.type} call was rejected`); } catch (_) {}

  logger.info(`Call rejected: ${callId}`);

  res.json({
    callId,
    message: 'Call rejected'
  });
}));

// End a call
router.post('/end', asyncHandler(async (req, res) => {
  const { callId } = req.body;

  if (!callId || !ongoingCalls[callId]) {
    return res.status(404).json({ error: 'Call not found' });
  }

  const call = ongoingCalls[callId];
  call.status = 'ended';
  call.endTime = new Date();
  call.duration = Math.floor((call.endTime - call.startTime) / 1000);

  // Save to history
  callHistory[callId] = call;
  delete ongoingCalls[callId];

  logger.info(`Call ended: ${callId}, duration: ${call.duration}s`);

  res.json({
    callId,
    message: 'Call ended',
    call
  });
}));

// Get call history
router.get('/history', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const role = req.user.role;
  
  const userCallHistory = Object.values(callHistory).filter(call => {
    if (role === 'patient') {
      return call.initiatorId === userId || call.recipientId === userId;
    } else {
      return call.initiatorId === userId || call.recipientId === userId;
    }
  }).sort((a, b) => new Date(b.startTime) - new Date(a.startTime));

  res.json({
    count: userCallHistory.length,
    calls: userCallHistory
  });
}));

// Get ongoing calls
router.get('/ongoing', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  
  const userOngoingCalls = Object.values(ongoingCalls).filter(call => 
    call.initiatorId === userId || call.recipientId === userId
  );

  res.json({
    count: userOngoingCalls.length,
    calls: userOngoingCalls
  });
}));

// Get missed calls for current user (must be before /:callId to avoid param matching)
router.get('/missed', asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const userMissed = missedCalls[userId] || [];
  res.json({
    count: userMissed.length,
    missedCalls: userMissed.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp)),
  });
}));

// Get call details
router.get('/:callId', asyncHandler(async (req, res) => {
  const { callId } = req.params;
  const call = ongoingCalls[callId] || callHistory[callId];

  if (!call) {
    return res.status(404).json({ error: 'Call not found' });
  }

  res.json(call);
}));

// Update call quality metrics
router.post('/:callId/metrics', asyncHandler(async (req, res) => {
  const { callId } = req.params;
  const { 
    networkQuality, 
    videoResolution, 
    frameRate, 
    bitrate, 
    latency, 
    packetLoss,
    bandwidth
  } = req.body;

  const call = ongoingCalls[callId] || callHistory[callId];
  if (!call) {
    return res.status(404).json({ error: 'Call not found' });
  }

  call.metrics = {
    networkQuality,
    videoResolution,
    frameRate,
    bitrate,
    latency,
    packetLoss,
    bandwidth,
    timestamp: new Date()
  };

  logger.info(`Call metrics updated: ${callId}`, call.metrics);

  res.json({
    callId,
    message: 'Metrics updated',
    metrics: call.metrics
  });
}));

// Record call — accept a recording file upload
router.post('/:callId/record', recordingUpload.single('recording'), asyncHandler(async (req, res) => {
  const { callId } = req.params;

  const call = ongoingCalls[callId] || callHistory[callId];
  if (!call) {
    return res.status(404).json({ error: 'Call not found' });
  }

  if (req.file) {
    // Save uploaded recording file
    const ext = path.extname(req.file.originalname || '') || '.webm';
    const safeFileName = `recording_${callId}_${Date.now()}${ext}`;
    const filePath = path.join(recordingsDir, safeFileName);
    fs.writeFileSync(filePath, req.file.buffer);
    call.recordingUrl = `/uploads/recordings/${safeFileName}`;
    call.recordingSize = req.file.size;
  } else if (req.body.recordingUrl) {
    // Accept external URL
    call.recordingUrl = req.body.recordingUrl;
  }

  call.recordedAt = new Date();
  call.isRecording = true;

  logger.info(`Call recording saved: ${callId} (${call.recordingUrl})`);

  res.json({
    callId,
    message: 'Recording saved',
    recordingUrl: call.recordingUrl
  });
}));

// Stop recording
router.post('/:callId/record/stop', asyncHandler(async (req, res) => {
  const { callId } = req.params;

  const call = ongoingCalls[callId] || callHistory[callId];
  if (!call) {
    return res.status(404).json({ error: 'Call not found' });
  }

  call.isRecording = false;
  call.recordingStoppedAt = new Date();

  logger.info(`Call recording stopped: ${callId}`);
  res.json({ callId, message: 'Recording stopped' });
}));

// Request callback (patient/doctor requests to be called back)
router.post('/callback-request', asyncHandler(async (req, res) => {
  const { targetUserId, type, message } = req.body;
  const requesterId = req.user.userId;
  const requesterName = req.user.name || requesterId;

  if (!targetUserId || !type) {
    return res.status(400).json({ error: 'targetUserId and type required' });
  }

  const callbackRequest = {
    requestId: `cb_${Date.now()}`,
    requesterId,
    requesterName,
    targetUserId,
    type,
    message: message || `${requesterName} requested a callback`,
    status: 'pending',
    createdAt: new Date(),
  };

  // Add to missed calls of target so they see it
  if (!missedCalls[targetUserId]) missedCalls[targetUserId] = [];
  missedCalls[targetUserId].push({
    callId: callbackRequest.requestId,
    from: requesterId,
    fromName: requesterName,
    type,
    timestamp: new Date(),
    status: 'callback_requested',
    message: callbackRequest.message,
  });

  // Send push notification for callback
  try { await fcm.sendPushToUser(targetUserId, 'Callback Request', callbackRequest.message); } catch (_) {}

  logger.info(`Callback requested: ${requesterId} -> ${targetUserId}`);
  res.status(201).json({ message: 'Callback request sent', callbackRequest });
}));

// Add notes to call
router.post('/:callId/notes', asyncHandler(async (req, res) => {
  const { callId } = req.params;
  const { notes } = req.body;

  const call = callHistory[callId];
  if (!call) {
    return res.status(404).json({ error: 'Call not found' });
  }

  call.notes = notes;
  call.notesUpdatedAt = new Date();

  logger.info(`Notes added to call: ${callId}`);

  res.json({
    callId,
    message: 'Notes saved',
    notes
  });
}));

module.exports = router;
