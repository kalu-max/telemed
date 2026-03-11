module.exports = (sequelize, DataTypes) => {
  const Prescription = sequelize.define('Prescription', {
    prescriptionId: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    patientId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    patientName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    patientEmail: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    patientPhone: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    doctorId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    doctorName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    doctorLicenseNumber: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    consultationId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    consultationDate: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    symptoms: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    diagnosis: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    clinicalNotes: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    dietaryInstructions: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    lifestyleInstructions: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    followUpInstructions: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    followUpDate: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    followUpDaysInterval: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    labTests: {
      type: DataTypes.JSON,
      defaultValue: [],
      comment: 'Array of recommended lab tests',
    },
    referralDoctor: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM('draft', 'active', 'completed', 'cancelled', 'expired'),
      defaultValue: 'active',
      allowNull: false,
      index: true,
    },
    issuedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      allowNull: false,
      index: true,
    },
    expiryDate: {
      type: DataTypes.DATE,
      allowNull: true,
      index: true,
    },
    digitalSignature: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    prescriptionImageUrl: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'Handwritten prescription image URL',
    },
    pdfUrl: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'URL to download prescription as PDF',
    },
    isEncrypted: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    patientViewed: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    viewedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true,
      comment: 'Soft delete for HIPAA compliance',
    },
  }, {
    tableName: 'prescriptions',
    timestamps: true,
    underscored: true,
    paranoid: true, // Enable soft delete
    indexes: [
      { fields: ['patientId'] },
      { fields: ['doctorId'] },
      { fields: ['consultationId'] },
      { fields: ['status'] },
      { fields: ['issuedAt'] },
      { fields: ['expiryDate'] },
      { fields: ['patientId', 'status'] },
    ],
  });

  Prescription.associate = (models) => {
    Prescription.hasMany(models.Medicine, {
      foreignKey: 'prescriptionId',
      as: 'medicines',
      onDelete: 'CASCADE',
    });

    Prescription.hasMany(models.MedicineReminder, {
      foreignKey: 'prescriptionId',
      as: 'reminders',
      onDelete: 'CASCADE',
    });

    Prescription.belongsTo(models.CallSession, {
      foreignKey: 'consultationId',
      as: 'consultation',
    });
  };

  // Method to check if prescription is valid
  Prescription.prototype.isValid = function() {
    const now = new Date();
    return this.status === 'active' && (!this.expiryDate || now < this.expiryDate);
  };

  return Prescription;
};
