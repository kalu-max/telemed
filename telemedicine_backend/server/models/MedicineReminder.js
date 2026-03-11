module.exports = (sequelize, DataTypes) => {
  const MedicineReminder = sequelize.define('MedicineReminder', {
    reminderId: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    prescriptionId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    medicineId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    medicineName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    reminderTimes: {
      type: DataTypes.JSON,
      allowNull: false,
      comment: 'Array of ISO8601 timestamps for reminders',
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    takenAt: {
      type: DataTypes.JSON,
      defaultValue: [],
      comment: 'Array of timestamps when medicine was marked as taken',
    },
    missedAt: {
      type: DataTypes.JSON,
      defaultValue: [],
      comment: 'Array of timestamps for missed doses',
    },
    adherencePercentage: {
      type: DataTypes.FLOAT,
      defaultValue: 0,
      validate: { min: 0, max: 100 },
    },
  }, {
    tableName: 'medicine_reminders',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['prescriptionId'] },
      { fields: ['medicineId'] },
    ],
  });

  MedicineReminder.associate = (models) => {
    MedicineReminder.belongsTo(models.Prescription, {
      foreignKey: 'prescriptionId',
      as: 'prescription',
    });
  };

  // Hook to calculate adherence percentage
  MedicineReminder.beforeSave((reminder, options) => {
    const taken = reminder.takenAt ? reminder.takenAt.length : 0;
    const missed = reminder.missedAt ? reminder.missedAt.length : 0;
    const total = taken + missed;
    reminder.adherencePercentage = total > 0 ? (taken / total) * 100 : 0;
  });

  return MedicineReminder;
};
