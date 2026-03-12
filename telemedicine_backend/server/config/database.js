const { Sequelize } = require('sequelize');
const logger = require('../utils/logger');

// Database connection setup (dialect adjustable for tests)
const dialect = process.env.DB_DIALECT || 'sqlite';
const isProduction = process.env.NODE_ENV === 'production';

function parseBoolean(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return null;
}

// Default behavior:
// - production: skip expensive ALTER sync (use migrations)
// - non-production: allow ALTER sync for faster local iteration
const parsedSyncAlter = parseBoolean(process.env.DB_SYNC_ALTER);
const shouldAlterSchema = parsedSyncAlter !== null ? parsedSyncAlter : !isProduction;

const sequelizeOptions = {
  dialect,
  logging: (msg) => logger.debug(msg),
  pool: {
    max: 5,
    min: 0,
    acquire: 30000,
    idle: 10000
  },
  define: {
    timestamps: true,
    underscored: dialect === 'postgres' // snake_case only for Postgres, sqlite tests use camelCase for FK compatibility
  }
};

if (dialect === 'postgres') {
  // Render and most cloud Postgres require SSL
  sequelizeOptions.dialectOptions = {
    ssl: {
      require: true,
      rejectUnauthorized: false
    }
  };
  if (!process.env.DATABASE_URL) {
    sequelizeOptions.host = process.env.DB_HOST || 'localhost';
    sequelizeOptions.port = process.env.DB_PORT || 5432;
  }
} else if (dialect === 'sqlite') {
  // use in‑memory by default for tests
  sequelizeOptions.storage = process.env.DB_STORAGE || ':memory:';
}

const sequelize = process.env.DATABASE_URL
  ? new Sequelize(process.env.DATABASE_URL, sequelizeOptions)
  : new Sequelize(
      process.env.DB_NAME || 'telemedicine_db',
      process.env.DB_USER || 'postgres',
      process.env.DB_PASSWORD || 'password',
      sequelizeOptions
    );

// Test connection
sequelize.authenticate()
  .then(() => {
    logger.info('✅ PostgreSQL connection established');
  })
  .catch((err) => {
    logger.error('❌ PostgreSQL connection failed:', err.message);
  });

// Sync models with database
const syncDatabase = async (force = false) => {
  try {
    if (force) {
      await sequelize.sync({ force: true });
    } else if (dialect === 'sqlite') {
      // SQLite ALTER TABLE is limited — create missing tables, skip alter
      await sequelize.sync({ force: false });
    } else {
      await sequelize.sync({ alter: shouldAlterSchema, force: false });
    }
    logger.info('✅ Database synchronized');
  } catch (err) {
    const parentMessage = err && err.parent && err.parent.message ? ` | ${err.parent.message}` : '';
    const sqlState = err && err.parent && err.parent.code ? ` | SQLSTATE ${err.parent.code}` : '';
    logger.error(`❌ Database sync failed: ${err.message || 'Unknown error'}${parentMessage}${sqlState}`);
    if (err && err.sql) {
      logger.error(`❌ Failed SQL: ${err.sql}`);
    }
    // On SQLite, retry without alter as a fallback
    if (dialect === 'sqlite') {
      try {
        await sequelize.sync({ force: true });
        logger.info('✅ Database re-created (force sync fallback)');
      } catch (err2) {
        logger.error('❌ Force sync also failed:', err2.message);
        throw err2;
      }
      return;
    }
    // In production Postgres, fail fast so deploy logs clearly reflect schema issues.
    throw err;
  }
};

module.exports = { sequelize, syncDatabase };
