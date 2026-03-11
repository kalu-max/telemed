module.exports = (sequelize, DataTypes) => {
  const DoctorPresence = sequelize.define('DoctorPresence', {
    presenceId: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    doctorId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
      index: true,
    },
    status: {
      type: DataTypes.ENUM('online', 'busy', 'away', 'doNotDisturb', 'offline'),
      defaultValue: 'offline',
      allowNull: false,
    },
    isOnline: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      index: true,
    },
    lastSeen: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      index: true,
    },
    availableUntil: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    consultationType: {
      type: DataTypes.ENUM('videoCall', 'audioCall', 'chat', 'all'),
      defaultValue: 'all',
    },
    currentPatientId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    availabilityScore: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Score 0-100 for sorting availability',
    },
    responseTimeSeconds: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'Average response time in seconds',
    },
    ratingScore: {
      type: DataTypes.FLOAT,
      allowNull: true,
      validate: { min: 0, max: 5 },
    },
    totalConsultations: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    specialty: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    consultationFee: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'Fee in smallest currency unit (e.g., paise)',
    },
    languages: {
      type: DataTypes.JSON,
      defaultValue: ['English'],
    },
    bio: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    profileImageUrl: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    isVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    acceptsEmergency: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
  }, {
    tableName: 'doctor_presence',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['doctorId'] },
      { fields: ['status'] },
      { fields: ['isOnline'] },
      { fields: ['lastSeen'] },
      { fields: ['availabilityScore'] },
    ],
  });

  DoctorPresence.associate = (models) => {
    // Can add relationships here if needed
  };

  return DoctorPresence;
};
