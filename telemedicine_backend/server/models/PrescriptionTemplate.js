module.exports = (sequelize, DataTypes) => {
  const PrescriptionTemplate = sequelize.define('PrescriptionTemplate', {
    templateId: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    doctorId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    templateName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    templateDescription: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    medicines: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: [],
      comment: 'JSON array of medicine objects',
    },
    diagnosis: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    additionalInstructions: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    isPublic: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      comment: 'If true, can be shared with other doctors',
    },
    usageCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Number of times this template was used',
    },
  }, {
    tableName: 'prescription_templates',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['doctorId'] },
      { fields: ['templateName'] },
    ],
  });

  PrescriptionTemplate.associate = (models) => {
    // Can add associations here
  };

  return PrescriptionTemplate;
};
