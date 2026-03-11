/**
 * CallStatistics Model
 * Stores network metrics and quality metrics during calls
 */

const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const CallStatistics = sequelize.define(
    'CallStatistics',
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      callId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'CallSessions',
          key: 'id',
        },
        index: true,
      },
      avgBitrate: {
        type: DataTypes.FLOAT, // kbps
        allowNull: true,
      },
      maxBitrate: {
        type: DataTypes.FLOAT,
        allowNull: true,
      },
      minBitrate: {
        type: DataTypes.FLOAT,
        allowNull: true,
      },
      avgLatency: {
        type: DataTypes.FLOAT, // milliseconds
        allowNull: true,
      },
      packetLoss: {
        type: DataTypes.FLOAT, // percentage
        allowNull: true,
      },
      jitter: {
        type: DataTypes.FLOAT, // milliseconds
        allowNull: true,
      },
      audioLevel: {
        type: DataTypes.FLOAT,
        allowNull: true,
      },
      videoFps: {
        type: DataTypes.INTEGER,
        allowNull: true,
      },
      videoWidth: {
        type: DataTypes.INTEGER,
        allowNull: true,
      },
      videoHeight: {
        type: DataTypes.INTEGER,
        allowNull: true,
      },
      currentVideoQuality: {
        type: DataTypes.STRING,
        comment: 'low, medium, high',
      },
      timestamp: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW,
        index: true,
      },
      totalPacketsLost: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      totalPacketsReceived: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      roundTripTime: {
        type: DataTypes.FLOAT, // milliseconds
        allowNull: true,
      },
      audioCodec: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      videoCodec: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      networkType: {
        type: DataTypes.STRING,
        allowNull: true,
        comment: 'wifi, 4g, 5g, 3g, 2g',
      },
      signalStrength: {
        type: DataTypes.INTEGER,
        allowNull: true,
        comment: 'Signal strength 0-100',
      },
      cpuUsage: {
        type: DataTypes.FLOAT,
        allowNull: true,
        comment: 'CPU usage percentage',
      },
      memoryUsage: {
        type: DataTypes.FLOAT,
        allowNull: true,
        comment: 'Memory usage percentage',
      },
      qualityScore: {
        type: DataTypes.INTEGER,
        allowNull: true,
        comment: 'Quality score 0-100',
      },
    },
    {
      timestamps: true,
      indexes: [
        { fields: ['callId', 'timestamp'] },
        { fields: ['timestamp'] },
      ],
    }
  );

  return CallStatistics;
};
