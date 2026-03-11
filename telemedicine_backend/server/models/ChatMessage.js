/**
 * ChatMessage Model
 * Stores all text messages in the system
 */

const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const ChatMessage = sequelize.define(
    'ChatMessage',
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      conversationId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'Conversations',
          key: 'id',
        },
      },
      senderId: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      senderName: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      receiverId: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      content: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      messageType: {
        type: DataTypes.ENUM('text', 'voice', 'image', 'video', 'file', 'system'),
        defaultValue: 'text',
      },
      status: {
        type: DataTypes.ENUM('sending', 'sent', 'delivered', 'read', 'failed'),
        defaultValue: 'sent',
      },
      timestamp: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW,
        index: true,
      },
      readAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      deliveredAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      metadata: {
        type: DataTypes.JSON,
        allowNull: true,
      },
      encryptionStatus: {
        type: DataTypes.ENUM('encrypted', 'decrypted', 'unencrypted', 'failed'),
        defaultValue: 'unencrypted',
      },
      isSynced: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
      deletedAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    },
    {
      timestamps: true,
      paranoid: false, // Soft delete via deletedAt field
      indexes: [
        { fields: ['conversationId', 'timestamp'] },
        { fields: ['senderId', 'timestamp'] },
        { fields: ['receiverId', 'timestamp'] },
      ],
    }
  );

  return ChatMessage;
};
