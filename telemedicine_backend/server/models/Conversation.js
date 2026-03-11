/**
 * Conversation Model
 * Stores conversation metadata
 */

const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Conversation = sequelize.define(
    'Conversation',
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      participant1Id: {
        type: DataTypes.UUID,
        allowNull: false,
        index: true,
      },
      participant2Id: {
        type: DataTypes.UUID,
        allowNull: false,
        index: true,
      },
      participant1Name: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      participant2Name: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      participant1Avatar: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      participant2Avatar: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      lastMessageId: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      lastMessageTime: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW,
      },
      participant1UnreadCount: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      participant2UnreadCount: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      isMuted: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
      },
      isArchived: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
      },
      isEncrypted: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
      conversationType: {
        type: DataTypes.ENUM('private', 'group'),
        defaultValue: 'private',
      },
    },
    {
      timestamps: true,
      indexes: [
        { fields: ['participant1Id', 'participant2Id'] },
        { fields: ['lastMessageTime'] },
      ],
    }
  );

  return Conversation;
};
