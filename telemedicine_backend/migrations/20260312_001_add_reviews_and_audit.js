/**
 * Initial migration — creates all tables that the app needs.
 * This captures the current schema so future changes can be tracked incrementally.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const { DataTypes } = Sequelize;

    // doctor_reviews
    await queryInterface.createTable('doctor_reviews', {
      review_id: { type: DataTypes.STRING, primaryKey: true, field: 'review_id' },
      doctor_id: { type: DataTypes.STRING, references: { model: 'doctors', key: 'user_id' } },
      patient_id: { type: DataTypes.STRING, references: { model: 'users', key: 'user_id' } },
      consultation_id: { type: DataTypes.STRING },
      rating: { type: DataTypes.INTEGER, allowNull: false },
      comment: { type: DataTypes.TEXT },
      is_anonymous: { type: DataTypes.BOOLEAN, defaultValue: false },
      created_at: { type: DataTypes.DATE, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    }).catch(() => {});

    // audit_logs
    await queryInterface.createTable('audit_logs', {
      log_id: { type: DataTypes.STRING, primaryKey: true, field: 'log_id' },
      user_id: { type: DataTypes.STRING },
      action: { type: DataTypes.STRING, allowNull: false },
      resource_type: { type: DataTypes.STRING, allowNull: false },
      resource_id: { type: DataTypes.STRING },
      details: { type: DataTypes.TEXT },
      ip_address: { type: DataTypes.STRING },
      user_agent: { type: DataTypes.STRING },
      created_at: { type: DataTypes.DATE, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    }).catch(() => {});

    // Add indexes
    await queryInterface.addIndex('audit_logs', ['user_id']).catch(() => {});
    await queryInterface.addIndex('audit_logs', ['resource_type']).catch(() => {});
    await queryInterface.addIndex('audit_logs', ['created_at']).catch(() => {});
  },

  async down(queryInterface) {
    await queryInterface.dropTable('audit_logs').catch(() => {});
    await queryInterface.dropTable('doctor_reviews').catch(() => {});
  },
};
