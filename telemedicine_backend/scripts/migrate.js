/**
 * Lightweight migration runner for Sequelize.
 *
 * Migrations are JS files in the `migrations/` directory named with a
 * timestamp prefix, e.g. `20260312_001_create_reviews.js`.
 *
 * Each file exports:
 *   up(queryInterface, Sequelize)   — apply the migration
 *   down(queryInterface, Sequelize) — revert it
 *
 * Usage:
 *   node scripts/migrate.js          — run pending migrations
 *   node scripts/migrate.js --undo   — revert the last migration
 *   node scripts/migrate.js --status — show migration status
 */

const path = require('path');
const fs = require('fs');
const { sequelize } = require('../server/config/database');
const { DataTypes } = require('sequelize');

const MIGRATIONS_DIR = path.join(__dirname, '..', 'migrations');

// Ensure a tracking table exists
async function ensureMeta() {
  await sequelize.getQueryInterface().createTable('SequelizeMeta', {
    name: {
      type: DataTypes.STRING,
      primaryKey: true,
      allowNull: false,
    },
    executedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  }).catch(() => {}); // already exists
}

async function getExecuted() {
  try {
    const [rows] = await sequelize.query('SELECT name FROM "SequelizeMeta" ORDER BY name');
    return rows.map(r => r.name);
  } catch {
    return [];
  }
}

function getPendingFiles(executed) {
  const files = fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.js'))
    .sort();
  return files.filter(f => !executed.includes(f));
}

async function runMigrations() {
  await sequelize.authenticate();
  await ensureMeta();
  const executed = await getExecuted();
  const pending = getPendingFiles(executed);

  if (pending.length === 0) {
    console.log('✅ No pending migrations.');
    return;
  }

  const qi = sequelize.getQueryInterface();
  for (const file of pending) {
    console.log(`⏳ Running: ${file}`);
    const migration = require(path.join(MIGRATIONS_DIR, file));
    await migration.up(qi, require('sequelize'));
    await sequelize.query(`INSERT INTO "SequelizeMeta" (name) VALUES ('${file}')`);
    console.log(`✅ Done: ${file}`);
  }
  console.log(`\n✅ ${pending.length} migration(s) applied.`);
}

async function undoLast() {
  await sequelize.authenticate();
  await ensureMeta();
  const executed = await getExecuted();
  if (executed.length === 0) {
    console.log('Nothing to undo.');
    return;
  }
  const last = executed[executed.length - 1];
  console.log(`⏪ Reverting: ${last}`);
  const qi = sequelize.getQueryInterface();
  const migration = require(path.join(MIGRATIONS_DIR, last));
  await migration.down(qi, require('sequelize'));
  await sequelize.query(`DELETE FROM "SequelizeMeta" WHERE name = '${last}'`);
  console.log(`✅ Reverted: ${last}`);
}

async function showStatus() {
  await sequelize.authenticate();
  await ensureMeta();
  const executed = await getExecuted();
  const all = fs.readdirSync(MIGRATIONS_DIR).filter(f => f.endsWith('.js')).sort();
  console.log('\nMigration Status:');
  console.log('─'.repeat(60));
  for (const f of all) {
    const status = executed.includes(f) ? '✅ applied' : '⏳ pending';
    console.log(`  ${status}  ${f}`);
  }
  console.log('─'.repeat(60));
  console.log(`Total: ${all.length} | Applied: ${executed.length} | Pending: ${all.length - executed.length}\n`);
}

(async () => {
  try {
    const arg = process.argv[2];
    if (arg === '--undo') await undoLast();
    else if (arg === '--status') await showStatus();
    else await runMigrations();
  } catch (e) {
    console.error('Migration error:', e.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
})();
