module.exports = (sequelize, DataTypes) => {
  const Medicine = sequelize.define('Medicine', {
    medicineId: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    prescriptionId: {
      type: DataTypes.UUID,
      allowNull: false,
      index: true,
    },
    medicineName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    genericName: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    dosage: {
      type: DataTypes.FLOAT,
      allowNull: false,
    },
    dosageUnit: {
      type: DataTypes.ENUM('mg', 'g', 'ml', 'mcg', 'iu', 'units', 'tablet', 'capsule', 'drops', 'inhales'),
      defaultValue: 'mg',
    },
    frequency: {
      type: DataTypes.STRING,
      allowNull: false,
      comment: 'e.g., Twice Daily, Every 6 hours',
    },
    durationDays: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 7,
    },
    instructions: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'e.g., Take with water, After meals',
    },
    sideEffects: {
      type: DataTypes.JSON,
      defaultValue: [],
    },
    contraindications: {
      type: DataTypes.JSON,
      defaultValue: [],
    },
    requiresRefill: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    manufacturerName: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    price: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
  }, {
    tableName: 'medicines',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['prescriptionId'] },
      { fields: ['medicineName'] },
    ],
  });

  Medicine.associate = (models) => {
    Medicine.belongsTo(models.Prescription, {
      foreignKey: 'prescriptionId',
      as: 'prescription',
    });
  };

  return Medicine;
};
