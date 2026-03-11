/**
 * VoiceMessage Model
 * Stores voice message metadata with Opus codec info
 */

const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const VoiceMessage = sequelize.define(
    'VoiceMessage',
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      messageId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'ChatMessages',
          key: 'id',
        },
      },
      audioFilePath: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      duration: {
        type: DataTypes.INTEGER, // milliseconds
        allowNull: false,
      },
      fileSize: {
        type: DataTypes.INTEGER, // bytes
        allowNull: false,
      },
      codec: {
        type: DataTypes.STRING,
        defaultValue: 'opus',
        comment: 'Audio codec used (opus, aac, mp3, etc.)',
      },
      bitrate: {
        type: DataTypes.INTEGER, // bits per second
        defaultValue: 24000,
        comment: 'Audio bitrate for compression',
      },
      sampleRate: {
        type: DataTypes.INTEGER, // Hz
        defaultValue: 16000,
        comment: 'Audio sample rate (16000 = wideband)',
      },
      channels: {
        type: DataTypes.INTEGER,
        defaultValue: 1,
        comment: 'Number of audio channels (1 = mono)',
      },
      waveformData: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: 'Serialized waveform data for UI visualization',
      },
      isTranscoded: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        comment: 'Whether audio has been transcoded for bandwidth optimization',
      },
      originalCodec: {
        type: DataTypes.STRING,
        allowNull: true,
        comment: 'Original codec before transcoding',
      },
      checksumHash: {
        type: DataTypes.STRING,
        allowNull: true,
        comment: 'Hash for integrity verification',
      },
    },
    {
      timestamps: true,
      indexes: [{ fields: ['messageId'] }, { fields: ['createdAt'] }],
    }
  );

  return VoiceMessage;
};
