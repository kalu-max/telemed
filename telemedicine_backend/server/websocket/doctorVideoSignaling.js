const logger = require('../utils/logger');

// Track active connections
const doctorSockets = new Map(); // doctorId -> socket
const patientSockets = new Map(); // patientId -> socket
const activeCalls = new Map(); // callId -> call details
const ongoingCalls = new Map(); // userId -> callId

/**
 * Setup video signaling for doctor-patient video conferencing
 * Handles WebRTC offer/answer exchange and ICE candidates
 */
module.exports = function setupVideoSignaling(io) {
  // Main namespace for video calls
  io.on('connection', (socket) => {
    const userId = socket.userId;
    const role = socket.role || 'patient';
    
    logger.info(`User connected: ${userId} (${role})`);

    // Register doctor or patient
    if (role === 'doctor') {
      doctorSockets.set(userId, socket);
    } else {
      patientSockets.set(userId, socket);
    }

    // Emit online status
    io.emit('user:online', { 
      userId, 
      role, 
      timestamp: new Date().toISOString() 
    });

    // ==================== CALL INITIATION ====================

    /**
     * Patient initiates call to doctor
     * Event: patient:call-request
     * Data: { doctorId, patientId, patientName, patientAvatar }
     */
    socket.on('patient:call-request', (data) => {
      const { doctorId, patientId, patientName, patientAvatar } = data;
      const doctorSocket = doctorSockets.get(doctorId);

      logger.info(`Call request from patient ${patientId} to doctor ${doctorId}`);

      if (!doctorSocket) {
        socket.emit('call:error', { 
          message: 'Doctor is not available at the moment' 
        });
        logger.warn(`Doctor ${doctorId} not found or offline`);
        return;
      }

      // Generate call ID
      const callId = `call_${Date.now()}_${patientId}`;
      
      // Store call info
      activeCalls.set(callId, {
        callId,
        doctorId,
        patientId,
        patientName,
        patientAvatar,
        initiator: patientId,
        status: 'ringing',
        startTime: new Date(),
        doctorSocketId: doctorSocket.id,
        patientSocketId: socket.id
      });

      ongoingCalls.set(patientId, callId);
      patientSockets.set(patientId, socket);

      // Notify doctor about incoming call using the event name the doctor app listens for
      doctorSocket.emit('call:incoming', {
        callId,
        callerId: patientId,
        callerName: patientName,
        patientAvatar,
        timestamp: new Date().toISOString()
      });

      // Notify patient that call is ringing
      socket.emit('call:ringing', { callId });

      logger.info(`Call ${callId} initiated - waiting for doctor response`);
    });

    /**
     * Patient initiates call using initiateCall event (sent by VideoCallingService)
     * Data: { callId, callerId, callerName, receiverId, receiverName, offer }
     */
    socket.on('initiateCall', (data) => {
      const { callId, callerId, callerName, receiverId, receiverName, offer } = data;
      const patientId = callerId;
      const doctorId = receiverId;
      const doctorSocket = doctorSockets.get(doctorId);

      logger.info(`initiateCall from patient ${patientId} to doctor ${doctorId}`);

      // Register patient socket
      patientSockets.set(patientId, socket);

      if (!doctorSocket) {
        socket.emit('call:error', { message: 'Doctor is not available at the moment' });
        logger.warn(`Doctor ${doctorId} not found or offline`);
        return;
      }

      activeCalls.set(callId, {
        callId,
        doctorId,
        patientId,
        patientName: callerName,
        offer,
        initiator: patientId,
        status: 'ringing',
        startTime: new Date(),
      });

      ongoingCalls.set(patientId, callId);

      // Forward to doctor with the offer so they can create an answer
      doctorSocket.emit('call:incoming', {
        callId,
        callerId: patientId,
        callerName,
        offer,
      });

      socket.emit('call:ringing', { callId });
      logger.info(`Call ${callId} ringing doctor ${doctorId}`);
    });

    /**
     * Doctor accepts call (sent by DoctorVideoCallService.acceptCall)
     * Data: { callId, callerId (=patientId), answer? }
     */
    socket.on('answerCall', (data) => {
      const { callId, callerId, answer } = data;
      const callInfo = activeCalls.get(callId);
      if (!callInfo) {
        logger.warn(`answerCall: call ${callId} not found`);
        return;
      }

      callInfo.status = 'connected';
      activeCalls.set(callId, callInfo);

      const patientSocket = patientSockets.get(callInfo.patientId);
      if (patientSocket) {
        if (answer) {
          // Forward the WebRTC answer SDP to patient
          patientSocket.emit('answer', { answer, senderId: userId });
        }
        patientSocket.emit('call:answered', { callId });
      }

      logger.info(`Call ${callId} accepted by doctor`);
    });

    /**
     * Relay plain 'offer' event (doctor-initiated calls or re-negotiation)
     */
    socket.on('offer', (data) => {
      const recipientId = data.recipientId;
      const recipientSocket = doctorSockets.get(recipientId) || patientSockets.get(recipientId);
      if (recipientSocket) {
        recipientSocket.emit('offer', { ...data, senderId: userId });
      }
    });

    /**
     * Relay plain 'answer' event (for symmetrical signaling)
     */
    socket.on('answer', (data) => {
      const recipientId = data.recipientId;
      const recipientSocket = doctorSockets.get(recipientId) || patientSockets.get(recipientId);
      if (recipientSocket) {
        recipientSocket.emit('answer', { ...data, senderId: userId });
      }
    });

    /**
     * Relay plain 'iceCandidate' event
     */
    socket.on('iceCandidate', (data) => {
      const recipientId = data.recipientId;
      const recipientSocket = doctorSockets.get(recipientId) || patientSockets.get(recipientId);
      if (recipientSocket) {
        recipientSocket.emit('iceCandidate', { ...data, senderId: userId });
      }
    });

    /**
     * Doctor accepts/rejects call
     * Event: call:respond
     * Data: { callId, accept: boolean }
     */
    socket.on('call:respond', (data) => {
      const { callId, accept } = data;
      const callInfo = activeCalls.get(callId);

      if (!callInfo) {
        socket.emit('call:error', { message: 'Call not found' });
        return;
      }

      logger.info(`Doctor response to ${callId}: ${accept ? 'accepted' : 'rejected'}`);

      if (accept) {
        // Call accepted - update status
        callInfo.status = 'accepted';
        activeCalls.set(callId, callInfo);

        // Get patient socket
        const patientSocket = patientSockets.get(callInfo.patientId);
        if (patientSocket) {
          patientSocket.emit('call:accepted', { callId });
        }

        // Notify both parties that WebRTC negotiation can begin
        socket.emit('call:start-webrtc', { callId });
        if (patientSocket) {
          patientSocket.emit('call:start-webrtc', { callId });
        }

        logger.info(`Call ${callId} accepted - WebRTC negotiation starting`);
      } else {
        // Call rejected
        const patientSocket = patientSockets.get(callInfo.patientId);
        if (patientSocket) {
          patientSocket.emit('call:rejected', { callId });
        }

        activeCalls.delete(callId);
        ongoingCalls.delete(callInfo.patientId);

        logger.info(`Call ${callId} rejected`);
      }
    });

    // ==================== WebRTC SIGNALING ====================

    /**
     * Exchange WebRTC offer between doctor and patient
     * Event: webrtc:offer
     * Data: { offer (RTCSessionDescription), recipientId }
     */
    socket.on('webrtc:offer', (data) => {
      const { offer, recipientId } = data;
      
      logger.debug(`WebRTC offer from ${userId} to ${recipientId}`);

      const recipientSocket = doctorSockets.get(recipientId) || 
                             patientSockets.get(recipientId);

      if (recipientSocket) {
        recipientSocket.emit('webrtc:offer', {
          offer,
          senderId: userId
        });
      } else {
        logger.warn(`Recipient ${recipientId} not found for offer`);
      }
    });

    /**
     * Exchange WebRTC answer between doctor and patient
     * Event: webrtc:answer
     * Data: { answer (RTCSessionDescription), recipientId }
     */
    socket.on('webrtc:answer', (data) => {
      const { answer, recipientId } = data;
      
      logger.debug(`WebRTC answer from ${userId} to ${recipientId}`);

      const recipientSocket = doctorSockets.get(recipientId) || 
                             patientSockets.get(recipientId);

      if (recipientSocket) {
        recipientSocket.emit('webrtc:answer', {
          answer,
          senderId: userId
        });
      } else {
        logger.warn(`Recipient ${recipientId} not found for answer`);
      }
    });

    /**
     * Exchange ICE candidates for NAT traversal
     * Event: webrtc:ice-candidate
     * Data: { candidate (RTCIceCandidate), recipientId }
     */
    socket.on('webrtc:ice-candidate', (data) => {
      const { candidate, recipientId } = data;
      
      logger.debug(`ICE candidate from ${userId} to ${recipientId}`);

      const recipientSocket = doctorSockets.get(recipientId) || 
                             patientSockets.get(recipientId);

      if (recipientSocket && candidate) {
        recipientSocket.emit('webrtc:ice-candidate', {
          candidate,
          senderId: userId
        });
      }
    });

    // ==================== CHAT MESSAGING ====================

    /**
     * Send chat message during call
     * Event: chat:message
     * Data: { message, recipientId, sender (doctor/patient) }
     */
    socket.on('chat:message', (data) => {
      const { message, recipientId, sender } = data;

      logger.info(`Chat message from ${userId} to ${recipientId}`);

      const recipientSocket = doctorSockets.get(recipientId) || 
                             patientSockets.get(recipientId);

      if (recipientSocket) {
        recipientSocket.emit('chat:message', {
          message,
          senderId: userId,
          sender,
          timestamp: new Date().toISOString()
        });
      }
    });

    // ==================== CALL QUALITY MONITORING ====================

    /**
     * Report call metrics (bandwidth, latency, quality)
     * Event: metrics:report
     * Data: { callId, resolution, fps, bitrate, latency, packetLoss, quality }
     */
    socket.on('metrics:report', (data) => {
      const { callId, metrics } = data;

      logger.debug(`Metrics report for call ${callId}:`, metrics);

      const callInfo = activeCalls.get(callId);
      if (callInfo) {
        callInfo.metrics = callInfo.metrics || {};
        callInfo.metrics[userId] = metrics;
        activeCalls.set(callId, callInfo);
      }

      // Store metrics for analytics (in production, save to database)
      io.emit('call:metrics', {
        callId,
        userId,
        metrics,
        timestamp: new Date().toISOString()
      });
    });

    /**
     * Network quality change notification
     * Event: network:quality-change
     * Data: { callId, quality (excellent/good/fair/poor) }
     */
    socket.on('network:quality-change', (data) => {
      const { callId, quality, bandwidth, latency } = data;

      logger.info(`Network quality change for ${userId}: ${quality}`);

      const callInfo = activeCalls.get(callId);
      const recipientId = callInfo?.doctorId === userId ? 
                         callInfo?.patientId : 
                         callInfo?.doctorId;

      if (recipientId) {
        const recipientSocket = doctorSockets.get(recipientId) || 
                               patientSockets.get(recipientId);
        
        if (recipientSocket) {
          recipientSocket.emit('peer:network-quality', {
            quality,
            bandwidth,
            latency,
            peerId: userId
          });
        }
      }
    });

    // ==================== SCREEN SHARING ====================

    /**
     * Notify peer about screen share start/stop
     * Event: screenshare:toggle
     * Data: { callId, recipientId, sharing: boolean }
     */
    socket.on('screenshare:toggle', (data) => {
      const { callId, recipientId, sharing } = data;

      logger.info(`Screen share ${sharing ? 'started' : 'stopped'} by ${userId}`);

      const recipientSocket = doctorSockets.get(recipientId) || 
                             patientSockets.get(recipientId);

      if (recipientSocket) {
        recipientSocket.emit('screenshare:toggle', {
          peerId: userId,
          sharing,
          callId
        });
      }
    });

    // ==================== CALL TERMINATION ====================

    /**
     * End call
     * Event: call:end
     * Data: { callId, recipientId, reason }
     */
    socket.on('call:end', (data) => {
      const { callId, recipientId, reason } = data;

      logger.info(`Call ${callId} ended by ${userId}. Reason: ${reason}`);

      const recipientSocket = doctorSockets.get(recipientId) || 
                             patientSockets.get(recipientId);

      if (recipientSocket) {
        recipientSocket.emit('call:ended', {
          callId,
          initiator: userId,
          reason
        });
      }

      // Clean up call data
      const callInfo = activeCalls.get(callId);
      if (callInfo) {
        // In production, save call record to database here
        logger.info(`Call ${callId} duration: ${
          Math.round((Date.now() - callInfo.startTime) / 1000)
        } seconds`);
      }

      activeCalls.delete(callId);
      ongoingCalls.delete(callInfo?.patientId);
      ongoingCalls.delete(callInfo?.doctorId);
    });

    /**
     * Handle call error
     * Event: call:error
     * Data: { callId, error }
     */
    socket.on('call:error', (data) => {
      const { callId, error } = data;

      logger.error(`Call error on ${callId}:`, error);

      const callInfo = activeCalls.get(callId);
      const recipientId = callInfo?.doctorId === userId ? 
                         callInfo?.patientId : 
                         callInfo?.doctorId;

      if (recipientId) {
        const recipientSocket = doctorSockets.get(recipientId) || 
                               patientSockets.get(recipientId);
        
        if (recipientSocket) {
          recipientSocket.emit('call:error', {
            callId,
            error: error.message || error
          });
        }
      }

      activeCalls.delete(callId);
    });

    // ==================== CONNECTION MANAGEMENT ====================

    /**
     * Handle disconnect
     */
    socket.on('disconnect', () => {
      logger.info(`User disconnected: ${userId} (${role})`);

      // Remove from registered sockets
      doctorSockets.delete(userId);
      patientSockets.delete(userId);

      // End any active calls
      const callId = ongoingCalls.get(userId);
      if (callId) {
        const callInfo = activeCalls.get(callId);
        if (callInfo) {
          const recipientId = callInfo.doctorId === userId ? 
                             callInfo.patientId : 
                             callInfo.doctorId;
          
          const recipientSocket = doctorSockets.get(recipientId) || 
                                 patientSockets.get(recipientId);
          
          if (recipientSocket) {
            recipientSocket.emit('call:ended', {
              callId,
              initiator: userId,
              reason: 'peer_disconnected'
            });
          }
        }

        activeCalls.delete(callId);
        ongoingCalls.delete(userId);
      }

      // Broadcast offline status
      io.emit('user:offline', { 
        userId, 
        role,
        timestamp: new Date().toISOString()
      });
    });

    // ==================== DEBUGGING ====================

    /**
     * Get connection stats (for monitoring)
     */
    socket.on('debug:stats', (callback) => {
      callback({
        totalDoctors: doctorSockets.size,
        totalPatients: patientSockets.size,
        activeCalls: activeCalls.size,
        ongoingCalls: ongoingCalls.size
      });
    });
  });
};
