/**
 * CallSession Model
 * Stores video/audio call session records
 */

const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const CallSession = sequelize.define(
    'CallSession',
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      callerId: {
        type: DataTypes.UUID,
        allowNull: false,
        index: true,
      },
      callerName: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      callerAvatarUrl: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      receiverId: {
        type: DataTypes.UUID,
        allowNull: false,
        index: true,
      },
      receiverName: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      receiverAvatarUrl: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      callType: {
        type: DataTypes.ENUM('audio', 'video', 'groupVideo'),
        defaultValue: 'audio',
      },
      status: {
        type: DataTypes.ENUM(
          'initiating',
          'ringing',
          'accepted',
          'connecting',
          'connected',
          'disconnecting',
          'disconnected',
          'rejected',
          'missed',
          'failed',
          'ended'
        ),
        defaultValue: 'initiating',
      },
      direction: {
        type: DataTypes.ENUM('incoming', 'outgoing'),
        allowNull: false,
      },
      initiatedAt: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW,
      },
      startedAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      endedAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      duration: {
        type: DataTypes.INTEGER, // seconds
        allowNull: true,
      },
      participantCount: {
        type: DataTypes.INTEGER,
        defaultValue: 2,
        comment: 'For group calls',
      },
      participantIds: {
        type: DataTypes.JSON,
        allowNull: true,
        comment: 'Array of participant IDs for group calls',
      },
      isEncrypted: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
      recordingId: {
        type: DataTypes.UUID,
        allowNull: true,
        comment: 'Reference to call recording if available',
      },
      qualityMetrics: {
        type: DataTypes.JSON,
        allowNull: true,
        comment: 'Aggregated quality metrics from call',
      },
      failureReason: {
        type: DataTypes.STRING,
        allowNull: true,
        comment: 'Reason for call failure',
      },
      networkType: {
        type: DataTypes.STRING,
        allowNull: true,
        comment: 'Network type used during call (wifi, 4g, 5g, etc.)',
      },
    },
    {
      timestamps: true,
      indexes: [
        { fields: ['callerId', 'initiatedAt'] },
        { fields: ['receiverId', 'initiatedAt'] },
        { fields: ['status'] },
      ],
    }
  );

  return CallSession;
};
