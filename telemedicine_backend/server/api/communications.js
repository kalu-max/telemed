/**
 * Messaging and Communication API endpoints
 * Handles text messages, voice messages, video calls, and real-time communication
 */

const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const { sequelize } = require('../config/database');
const { Op } = require('sequelize');
const logger = require('../utils/logger');

// Models (to be created)
const ChatMessage = require('../models/ChatMessage');
const Conversation = require('../models/Conversation');
const VoiceMessage = require('../models/VoiceMessage');
const CallSession = require('../models/CallSession');
const CallStatistics = require('../models/CallStatistics');

/**
 * GET /api/communications/conversations
 * Get all conversations for a user
 */
router.get('/conversations', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const conversations = await Conversation.findAll({
      where: {
        [Op.or]: [
          { participant1Id: userId },
          { participant2Id: userId }
        ]
      },
      include: [
        {
          model: ChatMessage,
          as: 'lastMessage',
          limit: 1,
          order: [['timestamp', 'DESC']]
        }
      ],
      order: [['updatedAt', 'DESC']],
    });

    res.json({
      success: true,
      data: conversations,
    });
  } catch (error) {
    logger.error('Error fetching conversations:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch conversations',
    });
  }
});

/**
 * GET /api/communications/conversations/:conversationId/messages
 * Get messages for a conversation with pagination
 */
router.get('/conversations/:conversationId/messages', verifyToken, async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const conversationId = req.params.conversationId;
    const offset = (page - 1) * limit;

    const { count, rows } = await ChatMessage.findAndCountAll({
      where: { conversationId },
      order: [['timestamp', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({
      success: true,
      data: rows.reverse(),
      pagination: {
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(count / limit),
      },
    });
  } catch (error) {
    logger.error('Error fetching messages:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch messages',
    });
  }
});

/**
 * POST /api/communications/messages
 * Store message in database (for persistence)
 */
router.post('/messages', verifyToken, async (req, res) => {
  try {
    const {
      conversationId,
      senderId,
      receiverId,
      content,
      messageType = 'text',
      metadata,
    } = req.body;

    const message = await ChatMessage.create({
      id: req.body.id,
      conversationId,
      senderId,
      receiverId,
      content,
      messageType,
      status: 'delivered',
      timestamp: new Date(),
      metadata,
      isSynced: true,
    });

    res.json({
      success: true,
      data: message,
    });
  } catch (error) {
    logger.error('Error storing message:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to store message',
    });
  }
});

/**
 * PUT /api/communications/messages/:messageId/status
 * Update message status (delivered, read, etc.)
 */
router.put('/messages/:messageId/status', verifyToken, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { status } = req.body;

    const message = await ChatMessage.findByPk(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        error: 'Message not found',
      });
    }

    message.status = status;
    if (status === 'read') {
      message.readAt = new Date();
    } else if (status === 'delivered') {
      message.deliveredAt = new Date();
    }

    await message.save();

    res.json({
      success: true,
      data: message,
    });
  } catch (error) {
    logger.error('Error updating message status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update message status',
    });
  }
});

/**
 * POST /api/communications/voice-messages
 * Store voice message metadata
 */
router.post('/voice-messages', verifyToken, async (req, res) => {
  try {
    const {
      messageId,
      duration,
      fileSize,
      codec = 'opus',
      bitrate = 24000,
    } = req.body;

    const voiceMessage = await VoiceMessage.create({
      messageId,
      duration,
      fileSize,
      codec,
      bitrate,
    });

    res.json({
      success: true,
      data: voiceMessage,
    });
  } catch (error) {
    logger.error('Error storing voice message:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to store voice message',
    });
  }
});

/**
 * POST /api/communications/calls
 * Create a call session record
 */
router.post('/calls', verifyToken, async (req, res) => {
  try {
    const {
      id,
      callerId,
      receiverId,
      callType = 'audio',
      direction = 'outgoing',
    } = req.body;

    const call = await CallSession.create({
      id,
      callerId,
      receiverId,
      callType,
      direction,
      status: 'initiating',
      initiatedAt: new Date(),
      isEncrypted: true,
    });

    res.json({
      success: true,
      data: call,
    });
  } catch (error) {
    logger.error('Error creating call session:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create call session',
    });
  }
});

/**
 * PUT /api/communications/calls/:callId/status
 * Update call status
 */
router.put('/calls/:callId/status', verifyToken, async (req, res) => {
  try {
    const { callId } = req.params;
    const { status } = req.body;

    const call = await CallSession.findByPk(callId);
    if (!call) {
      return res.status(404).json({
        success: false,
        error: 'Call not found',
      });
    }

    call.status = status;
    if (status === 'connected') {
      call.startedAt = new Date();
    } else if (status === 'ended') {
      call.endedAt = new Date();
      if (call.startedAt) {
        call.duration = Math.floor(
          (call.endedAt - call.startedAt) / 1000
        );
      }
    }

    await call.save();

    res.json({
      success: true,
      data: call,
    });
  } catch (error) {
    logger.error('Error updating call status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update call status',
    });
  }
});

/**
 * POST /api/communications/call-statistics
 * Store call statistics
 */
router.post('/call-statistics', verifyToken, async (req, res) => {
  try {
    const {
      callId,
      avgBitrate,
      avgLatency,
      packetLoss,
      jitter,
      videoFps,
      currentVideoQuality,
      totalPacketsLost,
      totalPacketsReceived,
    } = req.body;

    const stats = await CallStatistics.create({
      callId,
      avgBitrate,
      avgLatency,
      packetLoss,
      jitter,
      videoFps,
      currentVideoQuality,
      timestamp: new Date(),
      totalPacketsLost,
      totalPacketsReceived,
    });

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    logger.error('Error storing call statistics:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to store call statistics',
    });
  }
});

/**
 * GET /api/communications/calls/:callId
 * Get call details and history
 */
router.get('/calls/:callId', verifyToken, async (req, res) => {
  try {
    const { callId } = req.params;

    const call = await CallSession.findByPk(callId, {
      include: [
        {
          model: CallStatistics,
          as: 'statistics',
          limit: 1,
          order: [['timestamp', 'DESC']],
        },
      ],
    });

    if (!call) {
      return res.status(404).json({
        success: false,
        error: 'Call not found',
      });
    }

    res.json({
      success: true,
      data: call,
    });
  } catch (error) {
    logger.error('Error fetching call details:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch call details',
    });
  }
});

/**
 * GET /api/communications/calls/user/:userId
 * Get call history for a user
 */
router.get('/calls/user/:userId', verifyToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50 } = req.query;

    const calls = await CallSession.findAll({
      where: {
        [Op.or]: [
          { callerId: userId },
          { receiverId: userId },
        ],
      },
      order: [['initiatedAt', 'DESC']],
      limit: parseInt(limit),
    });

    res.json({
      success: true,
      data: calls,
    });
  } catch (error) {
    logger.error('Error fetching call history:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch call history',
    });
  }
});

/**
 * POST /api/communications/sync/offline-messages
 * Sync offline messages when user regains connectivity
 */
router.post('/sync/offline-messages', verifyToken, async (req, res) => {
  try {
    const { messages } = req.body;
    const userId = req.user.id;

    const savedMessages = await Promise.all(
      messages.map((msg) =>
        ChatMessage.findOrCreate({
          where: { id: msg.id },
          defaults: {
            ...msg,
            isSynced: true,
          },
        })
      )
    );

    res.json({
      success: true,
      synced: savedMessages.length,
    });
  } catch (error) {
    logger.error('Error syncing offline messages:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to sync messages',
    });
  }
});

/**
 * DELETE /api/communications/messages/:messageId
 * Delete a message (soft delete for compliance)
 */
router.delete('/messages/:messageId', verifyToken, async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await ChatMessage.findByPk(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        error: 'Message not found',
      });
    }

    // Soft delete for HIPAA/GDPR compliance
    message.deletedAt = new Date();
    message.content = '[DELETED]';
    await message.save();

    res.json({
      success: true,
      message: 'Message deleted',
    });
  } catch (error) {
    logger.error('Error deleting message:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete message',
    });
  }
});

module.exports = router;
