const crypto = require('crypto');
const logger = require('./logger');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const AUTH_TAG_LENGTH = 16;

function getEncryptionKey() {
  const key = process.env.ENCRYPTION_KEY;
  if (!key) return null;
  // Key must be exactly 32 bytes (256 bits)
  const buf = Buffer.from(key, 'hex');
  if (buf.length !== 32) {
    logger.warn('ENCRYPTION_KEY must be 64 hex characters (32 bytes). Encryption disabled.');
    return null;
  }
  return buf;
}

/**
 * Encrypt plaintext using AES-256-GCM.
 * Returns base64 string: iv + authTag + ciphertext
 * Returns plaintext if encryption key is not configured.
 */
function encrypt(plaintext) {
  if (!plaintext) return plaintext;
  const key = getEncryptionKey();
  if (!key) return plaintext;

  try {
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    // Format: iv (12 bytes) + authTag (16 bytes) + ciphertext
    const combined = Buffer.concat([iv, authTag, encrypted]);
    return 'enc:' + combined.toString('base64');
  } catch (err) {
    logger.error(`Encryption failed: ${err.message}`);
    return plaintext;
  }
}

/**
 * Decrypt ciphertext produced by encrypt().
 * Returns plaintext. If the value is not encrypted (no 'enc:' prefix), returns as-is.
 */
function decrypt(ciphertext) {
  if (!ciphertext || typeof ciphertext !== 'string') return ciphertext;
  if (!ciphertext.startsWith('enc:')) return ciphertext; // not encrypted

  const key = getEncryptionKey();
  if (!key) {
    logger.warn('Cannot decrypt: ENCRYPTION_KEY not configured');
    return ciphertext;
  }

  try {
    const combined = Buffer.from(ciphertext.slice(4), 'base64');
    const iv = combined.subarray(0, IV_LENGTH);
    const authTag = combined.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH);
    const encrypted = combined.subarray(IV_LENGTH + AUTH_TAG_LENGTH);

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString('utf8');
  } catch (err) {
    logger.error(`Decryption failed: ${err.message}`);
    return ciphertext;
  }
}

/**
 * Create Sequelize hooks for a model to auto-encrypt/decrypt specified fields.
 */
function addEncryptionHooks(model, fields) {
  model.addHook('beforeCreate', 'encryptFields', (instance) => {
    for (const field of fields) {
      const val = instance.getDataValue(field);
      if (val) instance.setDataValue(field, encrypt(val));
    }
  });

  model.addHook('beforeUpdate', 'encryptFields', (instance) => {
    for (const field of fields) {
      if (instance.changed(field)) {
        const val = instance.getDataValue(field);
        if (val) instance.setDataValue(field, encrypt(val));
      }
    }
  });

  model.addHook('afterFind', 'decryptFields', (results) => {
    if (!results) return;
    const instances = Array.isArray(results) ? results : [results];
    for (const instance of instances) {
      if (!instance || !instance.getDataValue) continue;
      for (const field of fields) {
        const val = instance.getDataValue(field);
        if (val) instance.setDataValue(field, decrypt(val));
      }
    }
  });
}

module.exports = { encrypt, decrypt, addEncryptionHooks };
