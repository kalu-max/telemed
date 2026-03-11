const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

const router = express.Router();

// Mock database
const callHistory = {};
const ongoingCalls = {};

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

// Record call
router.post('/:callId/record', asyncHandler(async (req, res) => {
  const { callId } = req.params;
  const { recordingUrl } = req.body;

  const call = ongoingCalls[callId] || callHistory[callId];
  if (!call) {
    return res.status(404).json({ error: 'Call not found' });
  }

  call.recordingUrl = recordingUrl;
  call.recordedAt = new Date();

  logger.info(`Call recording started: ${callId}`);

  res.json({
    callId,
    message: 'Recording started',
    recordingUrl
  });
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
