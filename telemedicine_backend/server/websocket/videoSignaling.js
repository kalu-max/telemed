const logger = require('../utils/logger');

// Track active peer connections and users
const userSockets = new Map(); // userId -> socket
const activeCalls = new Map(); // callId -> {initiator, recipient, ...}
const iceServers = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
  { urls: 'stun:stun2.l.google.com:19302' },
  { urls: 'stun:stun3.l.google.com:19302' },
  { urls: 'stun:stun4.l.google.com:19302' }
];

module.exports = function setupVideoSignaling(io) {
  // Namespace for video signaling
  const videoNamespace = io.of('/video');

  videoNamespace.on('connection', (socket) => {
    const userId = socket.userId;
    logger.info(`User connected: ${userId}`);

    // Register user socket
    userSockets.set(userId, socket);

    // Handle user available
    socket.on('user:available', (data) => {
      const { status, networkQuality } = data;
      logger.info(`User status: ${userId} -> ${status}`);
      
      socket.broadcast.emit('user:status-changed', {
        userId,
        status,
        networkQuality,
        timestamp: new Date()
      });
    });

    // Initiate call
    socket.on('call:initiate', (data, callback) => {
      const { recipientId, type, initiatorName, callId } = data;
      const recipientSocket = userSockets.get(recipientId);

      if (!recipientSocket) {
        logger.warn(`Recipient not available: ${recipientId}`);
        callback({ success: false, error: 'Recipient not available' });
        return;
      }

      activeCalls.set(callId, {
        callId,
        initiatorId: userId,
        initiatorName,
        recipientId,
        type,
        status: 'ringing',
        startTime: new Date(),
        iceServers
      });

      logger.info(`Call initiated: ${callId} (${userId} -> ${recipientId})`);

      // Send call invitation to recipient
      recipientSocket.emit('call:incoming', {
        callId,
        initiatorId: userId,
        initiatorName,
        type,
        iceServers
      });

      callback({ success: true, callId, iceServers });

      // Set 30-second timeout for call response
      setTimeout(() => {
        const call = activeCalls.get(callId);
        if (call && call.status === 'ringing') {
          socket.emit('call:timeout', { callId });
          recipientSocket.emit('call:timeout', { callId });
          activeCalls.delete(callId);
          logger.info(`Call timeout: ${callId}`);
        }
      }, 30000);
    });

    // Answer call
    socket.on('call:answer', (data) => {
      const { callId, sdpAnswer } = data;
      const call = activeCalls.get(callId);

      if (!call) {
        logger.warn(`Call not found: ${callId}`);
        return;
      }

      call.status = 'connected';
      call.connectTime = new Date();

      const initiatorSocket = userSockets.get(call.initiatorId);
      if (initiatorSocket) {
        initiatorSocket.emit('call:answered', {
          callId,
          sdpAnswer,
          recipientId: userId
        });
      }

      logger.info(`Call answered: ${callId}`);
    });

    // Reject call
    socket.on('call:reject', (data) => {
      const { callId, reason } = data;
      const call = activeCalls.get(callId);

      if (!call) return;

      const initiatorSocket = userSockets.get(call.initiatorId);
      if (initiatorSocket) {
        initiatorSocket.emit('call:rejected', {
          callId,
          reason: reason || 'Recipient declined'
        });
      }

      activeCalls.delete(callId);
      logger.info(`Call rejected: ${callId}`);
    });

    // Handle ICE candidates
    socket.on('ice:candidate', (data) => {
      const { callId, candidate, candidateInitData } = data;
      const call = activeCalls.get(callId);

      if (!call) return;

      const targetUserId = call.initiatorId === userId ? call.recipientId : call.initiatorId;
      const targetSocket = userSockets.get(targetUserId);

      if (targetSocket) {
        targetSocket.emit('ice:candidate', {
          callId,
          candidate,
          candidateInitData,
          from: userId
        });
      }
    });

    // Handle SDP Offer
    socket.on('sdp:offer', (data) => {
      const { callId, sdpOffer } = data;
      const call = activeCalls.get(callId);

      if (!call) return;

      const targetUserId = call.initiatorId === userId ? call.recipientId : call.initiatorId;
      const targetSocket = userSockets.get(targetUserId);

      if (targetSocket) {
        targetSocket.emit('sdp:offer', {
          callId,
          sdpOffer,
          from: userId
        });
      }
    });

    // End call
    socket.on('call:end', (data) => {
      const { callId } = data;
      const call = activeCalls.get(callId);

      if (!call) return;

      call.status = 'ended';
      call.endTime = new Date();
      call.duration = Math.floor((call.endTime - call.startTime) / 1000);

      const targetUserId = call.initiatorId === userId ? call.recipientId : call.initiatorId;
      const targetSocket = userSockets.get(targetUserId);

      if (targetSocket) {
        targetSocket.emit('call:ended', {
          callId,
          duration: call.duration
        });
      }

      activeCalls.delete(callId);
      logger.info(`Call ended: ${callId}, duration: ${call.duration}s`);
    });

    // Update call quality metrics
    socket.on('call:quality', (data) => {
      const { callId, metrics } = data;
      const call = activeCalls.get(callId);

      if (!call) return;

      if (!call.qualityMetrics) {
        call.qualityMetrics = [];
      }

      call.qualityMetrics.push({
        ...metrics,
        timestamp: new Date(),
        from: userId
      });

      // Keep only last 50 metrics
      if (call.qualityMetrics.length > 50) {
        call.qualityMetrics.shift();
      }

      const targetUserId = call.initiatorId === userId ? call.recipientId : call.initiatorId;
      const targetSocket = userSockets.get(targetUserId);

      if (targetSocket) {
        targetSocket.emit('call:quality-update', {
          callId,
          metrics,
          from: userId
        });
      }

      logger.debug(`Quality metrics received for ${callId}:`, metrics);
    });

    // Network quality change notification
    socket.on('network:quality-changed', (data) => {
      const { quality, bandwidth } = data;
      logger.info(`Network quality changed for ${userId}: ${quality}`);

      socket.broadcast.emit('network:peer-quality-changed', {
        userId,
        quality,
        bandwidth
      });
    });

    // Disconnect handler
    socket.on('disconnect', () => {
      logger.info(`User disconnected: ${userId}`);
      userSockets.delete(userId);

      // End all active calls for this user
      for (const [callId, call] of activeCalls.entries()) {
        if (call.initiatorId === userId || call.recipientId === userId) {
          const targetUserId = call.initiatorId === userId ? call.recipientId : call.initiatorId;
          const targetSocket = userSockets.get(targetUserId);

          if (targetSocket) {
            targetSocket.emit('call:peer-disconnected', {
              callId,
              peerId: userId
            });
          }

          activeCalls.delete(callId);
          logger.info(`Call forced ended due to disconnect: ${callId}`);
        }
      }

      socket.broadcast.emit('user:disconnected', { userId });
    });

    // Error handler
    socket.on('error', (error) => {
      logger.error(`Socket error for user ${userId}:`, error);
    });
  });

  logger.info('WebRTC Signaling Server initialized');
};
