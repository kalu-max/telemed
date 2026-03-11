/**
 * Socket.IO event handlers for real-time communication
 * Handles messaging, typing indicators, calls, and live metrics
 */

const logger = require('../utils/logger');
const jwt = require('jsonwebtoken');

// In-memory store for active connections
const activeConnections = new Map();
const roomConnections = new Map();
const activeCalls = new Map(); // callId -> { callerId, receiverId, status, createdAt }
const CALL_ALLOWED_APPOINTMENT_STATUSES = new Set([
  'scheduled',
  'pending',
  'connected',
  'in-progress',
]);

function hasActiveAppointmentBetweenUsers(userAId, userBId) {
  if (!userAId || !userBId) {
    return false;
  }

  try {
    const { appointments } = require('../api/users');
    return Object.values(appointments || {}).some((appointment) => {
      const status = `${appointment?.status || ''}`.trim();
      if (!CALL_ALLOWED_APPOINTMENT_STATUSES.has(status)) {
        return false;
      }

      const patientId = `${appointment?.patientId || ''}`.trim();
      const doctorId = `${appointment?.doctorId || ''}`.trim();

      return (
        (patientId === userAId && doctorId === userBId) ||
        (patientId === userBId && doctorId === userAId)
      );
    });
  } catch (error) {
    logger.warn(`Appointment lookup failed while authorizing call: ${error.message}`);
    return false;
  }
}

function registerSocketIdentity(socket, data = {}) {
  const declaredUserId = (data.userId || socket.userId || '').toString().trim();
  if (!declaredUserId) {
    return null;
  }

  socket.userId = declaredUserId;
  socket.role = (data.role || data.userRole || socket.role || 'patient')
    .toString()
    .trim() || 'patient';
  activeConnections.set(declaredUserId, socket);
  return { userId: socket.userId, role: socket.role };
}

/**
 * Initialize Socket.IO communication server
 */
function initializeCommunicationSocket(io) {
  io.on('connection', (socket) => {
    logger.info(`New connection established: ${socket.id}`);

    // Authenticate user (JWT preferred, query fallback for local dev clients)
    const token = socket.handshake?.auth?.token;
    let userId;
    let role = 'patient';

    try {
      if (token) {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
        userId = decoded.userId || decoded.id;
        role = decoded.role || role;
      }
    } catch (error) {
      logger.warn('Socket authentication failed:', error.message);
    }

    if (!userId) {
      const queryUserId = socket.handshake?.query?.userId;
      const queryRole = socket.handshake?.query?.role;
      if (typeof queryUserId === 'string' && queryUserId.trim().length > 0) {
        userId = queryUserId.trim();
      }
      if (typeof queryRole === 'string' && queryRole.trim()) {
        role = queryRole.trim();
      }
    }

    if (userId) {
      const identity = registerSocketIdentity(socket, { userId, role });
      socket.emit('authenticated', identity);
    } else {
      logger.warn(`Socket ${socket.id} connected without resolved user id`);
    }

    // Keep a direct way for clients to refresh their online identity.
    socket.on('user:online', (data = {}) => {
      const identity = registerSocketIdentity(socket, data);
      if (!identity) return;
      socket.emit('authenticated', identity);
    });

    socket.on('authenticate', (data = {}) => {
      const identity = registerSocketIdentity(socket, data);
      if (!identity) return;
      socket.emit('authenticated', identity);
    });

    // ==================== TEXT MESSAGING EVENTS ====================

    /**
     * Send message event
     * Emitted when user sends a text message
     */
    socket.on('sendMessage', (data) => {
      try {
        const {
          messageId,
          conversationId,
          senderId,
          senderName,
          receiverId,
          content,
          timestamp,
        } = data;

        logger.info(`Message sent from ${senderId} to ${receiverId}`);

        // Broadcast to recipient
        const recipientSocket = activeConnections.get(receiverId);
        if (recipientSocket) {
          recipientSocket.emit('message', {
            id: messageId,
            conversationId,
            senderId,
            senderName,
            receiverId,
            content,
            messageType: 'text',
            status: 'delivered',
            timestamp,
          });

          // Auto-send delivery receipt
          socket.emit('deliveryReceipt', {
            messageId,
            senderId,
            receiverId,
            timestamp: new Date().toISOString(),
          });
        } else {
          // Store message for later delivery (offline handling)
          logger.info(`Recipient ${receiverId} offline, storing message`);
        }
      } catch (error) {
        logger.error('Error handling sendMessage:', error);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    /**
     * Typing indicator event
     * Emitted when user starts typing
     */
    socket.on('typing', (data) => {
      try {
        const { conversationId, senderId, senderName, recipientId } = data;

        const recipientSocket = activeConnections.get(recipientId);
        if (recipientSocket) {
          recipientSocket.emit('typing', {
            conversationId,
            senderId,
            senderName,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (error) {
        logger.error('Error handling typing:', error);
      }
    });

    /**
     * Stop typing event
     * Emitted when user stops typing
     */
    socket.on('stopTyping', (data) => {
      try {
        const { conversationId, senderId, recipientId } = data;

        const recipientSocket = activeConnections.get(recipientId);
        if (recipientSocket) {
          recipientSocket.emit('stopTyping', {
            conversationId,
            senderId,
          });
        }
      } catch (error) {
        logger.error('Error handling stopTyping:', error);
      }
    });

    /**
     * Delivery receipt event
     * Emitted when message is delivered
     */
    socket.on('deliveryReceipt', (data) => {
      try {
        const { messageId, senderId, receiverId, timestamp } = data;

        const senderSocket = activeConnections.get(senderId);
        if (senderSocket) {
          senderSocket.emit('deliveryReceipt', {
            messageId,
            senderId,
            receiverId,
            timestamp,
          });
        }
      } catch (error) {
        logger.error('Error handling deliveryReceipt:', error);
      }
    });

    /**
     * Read receipt event
     * Emitted when message is read
     */
    socket.on('readReceipt', (data) => {
      try {
        const { messageId, senderId, receiverId, timestamp } = data;

        const senderSocket = activeConnections.get(senderId);
        if (senderSocket) {
          senderSocket.emit('readReceipt', {
            messageId,
            senderId,
            receiverId,
            timestamp,
          });
        }
      } catch (error) {
        logger.error('Error handling readReceipt:', error);
      }
    });

    // ==================== VOICE MESSAGING EVENTS ====================

    /**
     * Send voice message event
     * Emitted when user sends a voice message
     */
    socket.on('sendVoiceMessage', (data) => {
      try {
        const {
          messageId,
          conversationId,
          senderId,
          receiverId,
          audioData,
          duration,
          fileSize,
          codec,
          bitrate,
        } = data;

        logger.info(
          `Voice message sent from ${senderId} to ${receiverId}, size: ${fileSize}B, codec: ${codec}`
        );

        const recipientSocket = activeConnections.get(receiverId);
        if (recipientSocket) {
          // For bandwidth optimization, you can compress or transcode here
          recipientSocket.emit('voiceMessage', {
            id: messageId,
            conversationId,
            senderId,
            receiverId,
            audioData,
            duration,
            fileSize,
            codec,
            bitrate,
            timestamp: new Date().toISOString(),
          });

          socket.emit('deliveryReceipt', {
            messageId,
            senderId,
            receiverId,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (error) {
        logger.error('Error handling sendVoiceMessage:', error);
        socket.emit('error', { message: 'Failed to send voice message' });
      }
    });

    // ==================== VIDEO CALLING EVENTS ====================

    /**
     * Initiate call event
     * Emitted when user initiates a video call
     */
    socket.on('initiateCall', (data) => {
      try {
        const {
          callId: incomingCallId,
          callerId: declaredCallerId,
          callerName,
          receiverId,
          callType,
          offer,
        } = data;
        const callerId = `${socket.userId || declaredCallerId || ''}`.trim();
        const normalizedReceiverId = `${receiverId || ''}`.trim();
        const normalizedCallerName = `${callerName || socket.userId || 'Unknown'}`.trim();
        const callId = incomingCallId || `call_${Date.now()}`;

        if (!callerId || !normalizedReceiverId) {
          socket.emit('callFailed', {
            callId,
            reason: 'Invalid caller or recipient',
          });
          return;
        }

        if (!hasActiveAppointmentBetweenUsers(callerId, normalizedReceiverId)) {
          logger.warn(
            `Call blocked (no active appointment): ${callerId} -> ${normalizedReceiverId}`,
          );
          socket.emit('callFailed', {
            callId,
            reason: 'Call allowed only for active appointments',
          });
          return;
        }

        logger.info(`Call initiated: ${callId} from ${callerId} to ${normalizedReceiverId}`);

        const receiverSocket = activeConnections.get(normalizedReceiverId);
        if (receiverSocket) {
          // Normalize offer to { sdp, type } regardless of input (patient sends plain string)
          const normalizedOffer = typeof offer === 'string'
            ? { sdp: offer, type: 'offer' }
            : (offer || null);

          // Emit call:incoming for ringtone/UI notification (doctor app listens)
          receiverSocket.emit('call:incoming', {
            callId,
            callerId,
            callerName: normalizedCallerName,
            callType,
            timestamp: new Date().toISOString(),
          });

          // Emit offer for WebRTC setup (both apps listen for 'offer')
          if (normalizedOffer) {
            receiverSocket.emit('offer', {
              callId,
              callerId,
              callerName: normalizedCallerName,
              offer: normalizedOffer,
              timestamp: new Date().toISOString(),
            });
          }

          // Track call for targeted routing
          activeCalls.set(callId, {
            callerId,
            receiverId: normalizedReceiverId,
            status: 'ringing',
            createdAt: new Date().toISOString(),
          });
        } else {
          logger.warn(`Receiver ${normalizedReceiverId} offline for call ${callId}`);
          socket.emit('callFailed', {
            callId,
            reason: 'Recipient offline',
          });
        }
      } catch (error) {
        logger.error('Error handling initiateCall:', error);
        socket.emit('error', { message: 'Failed to initiate call' });
      }
    });

    /**
     * Answer call event
     * Emitted when user accepts a call
     */
    socket.on('answerCall', (data) => {
      try {
        const { callId, callerId: explicitCallerId, answer } = data;
        const call = activeCalls.get(callId);
        const targetId = call?.callerId || explicitCallerId;

        logger.info(`Call answered: ${callId}`);

        if (!targetId) {
          logger.warn(`answerCall: cannot locate caller for call ${callId}`);
          return;
        }

        const callerSocket = activeConnections.get(targetId);
        if (callerSocket) {
          callerSocket.emit('callAnswered', { callId, answer });
          callerSocket.emit('call:answered', { callId, answer }); // alias for doctor app
          logger.info(`Call ${callId} answer routed to ${targetId}`);
        }

        if (call) {
          call.status = 'connected';
          activeCalls.set(callId, call);
        }
      } catch (error) {
        logger.error('Error handling answerCall:', error);
      }
    });

    /**
     * WebRTC answer relay event
     * Emitted by doctor after processing an incoming offer
     */
    socket.on('answer', (data) => {
      try {
        const { callId, answer, recipientId } = data;
        const call = activeCalls.get(callId);
        const currentUserId = socket.userId;
        const targetId = recipientId ||
          (call
            ? (call.callerId === currentUserId ? call.receiverId : call.callerId)
            : null);

        logger.info(`WebRTC answer for call ${callId} → ${targetId}`);

        const targetSocket = targetId ? activeConnections.get(targetId) : null;
        if (targetSocket) {
          targetSocket.emit('answer', { callId, answer });
        } else {
          socket.broadcast.emit('answer', { callId, answer });
        }
      } catch (error) {
        logger.error('Error handling answer:', error);
      }
    });

    /**
     * ICE candidate event
     * Emitted for WebRTC ICE candidates
     */
    socket.on('iceCandidate', (data) => {
      try {
        const { callId, candidate, sdpMlineIndex, sdpMid, targetUserId } = data;
        const call = activeCalls.get(callId);
        const currentUserId = socket.userId;
        let targetId = targetUserId;
        if (!targetId && call) {
          targetId = call.callerId === currentUserId ? call.receiverId : call.callerId;
        }

        logger.debug(`ICE candidate for call ${callId} → ${targetId}`);

        const targetSocket = targetId ? activeConnections.get(targetId) : null;
        if (targetSocket) {
          targetSocket.emit('iceCandidate', { callId, candidate, sdpMlineIndex, sdpMid });
        } else {
          socket.broadcast.emit('iceCandidate', { callId, candidate, sdpMlineIndex, sdpMid });
        }
      } catch (error) {
        logger.error('Error handling iceCandidate:', error);
      }
    });

    /**
     * Reject call event
     * Emitted when user rejects an incoming call
     */
    socket.on('rejectCall', (data) => {
      try {
        const { callId, senderId } = data;
        const call = activeCalls.get(callId);
        const currentUserId = senderId || socket.userId;
        const targetId = call
          ? (call.callerId === currentUserId ? call.receiverId : call.callerId)
          : null;

        logger.info(`Call rejected: ${callId} by ${currentUserId}`);

        const targetSocket = targetId ? activeConnections.get(targetId) : null;
        if (targetSocket) {
          targetSocket.emit('callRejected', { callId, rejectedBy: currentUserId });
        } else {
          socket.broadcast.emit('callRejected', { callId, rejectedBy: currentUserId });
        }

        if (call) activeCalls.delete(callId);
      } catch (error) {
        logger.error('Error handling rejectCall:', error);
      }
    });

    /**
     * End call event
     * Emitted when user ends a call
     */
    socket.on('endCall', (data) => {
      try {
        const { callId, senderId } = data;
        const call = activeCalls.get(callId);
        const currentUserId = senderId || socket.userId;
        const targetId = call
          ? (call.callerId === currentUserId ? call.receiverId : call.callerId)
          : null;

        logger.info(`Call ended: ${callId} by ${currentUserId}`);

        const targetSocket = targetId ? activeConnections.get(targetId) : null;
        if (targetSocket) {
          targetSocket.emit('callEnded', { callId, endedBy: currentUserId });
          targetSocket.emit('call:ended', { callId, endedBy: currentUserId }); // alias for doctor app
        } else {
          socket.broadcast.emit('callEnded', { callId, endedBy: currentUserId });
        }

        if (call) activeCalls.delete(callId);
      } catch (error) {
        logger.error('Error handling endCall:', error);
      }
    });

    // ==================== BANDWIDTH & NETWORK EVENTS ====================

    /**
     * Network metrics event
     * Emitted periodically during a call to report network metrics
     */
    socket.on('networkMetrics', (data) => {
      try {
        const {
          callId,
          bandwidth,
          latency,
          packetLoss,
          jitter,
          signalStrength,
        } = data;

        logger.debug(`Network metrics for call ${callId}: ${bandwidth}Mbps, ${latency}ms latency`);

        // Could log these for analysis
        socket.emit('metricsAcknowledged', { callId });
      } catch (error) {
        logger.error('Error handling networkMetrics:', error);
      }
    });

    /**
     * Bitrate adjustment event
     * Emitted when adaptive bitrate needs to be adjusted
     */
    socket.on('adjustBitrate', (data) => {
      try {
        const { callId, newBitrate, videoQuality } = data;

        logger.info(`Bitrate adjusted for call ${callId}: ${newBitrate}kbps, quality: ${videoQuality}`);

        socket.broadcast.emit('bitrateAdjusted', {
          callId,
          newBitrate,
          videoQuality,
        });
      } catch (error) {
        logger.error('Error handling adjustBitrate:', error);
      }
    });

    // ==================== OFFLINE SYNC EVENTS ====================

    /**
     * Sync message event
     * Emitted when user comes back online with offline messages
     */
    socket.on('syncMessage', (data) => {
      try {
        logger.info(`Syncing message: ${data.id}`);

        const recipientSocket = activeConnections.get(data.receiverId);
        if (recipientSocket) {
          recipientSocket.emit('message', {
            ...data,
            status: 'delivered',
          });

          socket.emit('syncMessageConfirmed', {
            messageId: data.id,
          });
        }
      } catch (error) {
        logger.error('Error handling syncMessage:', error);
      }
    });

    /**
     * Privacy/HIPAA events
     * Mark data as anonymized for compliance
     */
    socket.on('requestDataAnonymization', (data) => {
      try {
        const { conversationId } = data;

        logger.info(`Data anonymization requested for conversation ${conversationId}`);

        // Queue anonymization job
        socket.emit('anonymizationStarted', {
          conversationId,
        });
      } catch (error) {
        logger.error('Error handling requestDataAnonymization:', error);
      }
    });

    // ==================== CONNECTION MANAGEMENT ====================

    /**
     * Disconnect event
     * Cleanup when user disconnects
     */
    socket.on('disconnect', () => {
      logger.info(`User disconnected: ${userId || 'unknown'}`);

      if (userId) {
        activeConnections.delete(userId);

        // Notify other users that this user is offline
        socket.broadcast.emit('userOffline', {
          userId,
          timestamp: new Date().toISOString(),
        });
      }
    });

    /**
     * Error handler
     */
    socket.on('error', (error) => {
      logger.error(`Socket error for user ${userId}:`, error);
    });
  });
}

/**
 * Get online users
 */
function getOnlineUsers() {
  return Array.from(activeConnections.keys());
}

/**
 * Broadcast to all connections
 */
function broadcastToAll(event, data) {
  for (const socket of activeConnections.values()) {
    socket.emit(event, data);
  }
}

module.exports = {
  initializeCommunicationSocket,
  getOnlineUsers,
  broadcastToAll,
  activeConnections,
};
