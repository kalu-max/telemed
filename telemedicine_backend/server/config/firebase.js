const admin = require('firebase-admin');
const path = require('path');
const logger = require('../utils/logger');

// Initialize Firebase Admin SDK
let db = null;
let auth = null;
let realtimeDb = null;

let serviceAccount;
try {
  // Load service account from environment or file
  if (process.env.FIREBASE_CONFIG) {
    serviceAccount = JSON.parse(process.env.FIREBASE_CONFIG);
  } else {
    const configPath = process.env.FIREBASE_CONFIG_PATH || 
                       path.join(__dirname, '../../firebaseConfig.json');
    if (require('fs').existsSync(configPath)) {
      serviceAccount = require(configPath);
    } else {
      throw new Error('service account file not found');
    }
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
    projectId: process.env.FIREBASE_PROJECT_ID
  });

  logger.info('✅ Firebase Admin SDK initialized');

  if (admin.apps.length) {
    db = admin.firestore();
    auth = admin.auth();
    realtimeDb = admin.database();
  }
} catch (err) {
  logger.warn('⚠️  Firebase initialization skipped:', err.message);
  logger.warn('   Set FIREBASE_CONFIG environment variable or place firebaseConfig.json in project root');
}

// Firestore utility functions
const firestore = {
  // Set document
  set: async (collection, docId, data) => {
    if (!db) {
      logger.error('Firestore not initialized');
      return null;
    }
    try {
      await db.collection(collection).doc(docId).set(data, { merge: true });
      logger.debug(`Firestore: Set ${collection}/${docId}`);
      return data;
    } catch (err) {
      logger.error(`Firestore error:`, err.message);
      throw err;
    }
  },

  // Get document
  get: async (collection, docId) => {
    if (!db) {
      logger.error('Firestore not initialized');
      return null;
    }
    try {
      const doc = await db.collection(collection).doc(docId).get();
      return doc.exists ? doc.data() : null;
    } catch (err) {
      logger.error(`Firestore error:`, err.message);
      throw err;
    }
  },

  // Query documents
  query: async (collection, whereClause) => {
    if (!db) {
      logger.error('Firestore not initialized');
      return [];
    }
    try {
      let query = db.collection(collection);
      if (whereClause) {
        Object.entries(whereClause).forEach(([key, value]) => {
          query = query.where(key, '==', value);
        });
      }
      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (err) {
      logger.error(`Firestore error:`, err.message);
      throw err;
    }
  },

  // Delete document
  delete: async (collection, docId) => {
    if (!db) {
      logger.error('Firestore not initialized');
      return false;
    }
    try {
      await db.collection(collection).doc(docId).delete();
      logger.debug(`Firestore: Deleted ${collection}/${docId}`);
      return true;
    } catch (err) {
      logger.error(`Firestore error:`, err.message);
      throw err;
    }
  },

  // Batch write
  batch: async (operations) => {
    if (!db) {
      logger.error('Firestore not initialized');
      return false;
    }
    try {
      const batch = db.batch();
      operations.forEach(({ type, collection, docId, data }) => {
        const ref = db.collection(collection).doc(docId);
        if (type === 'set') batch.set(ref, data, { merge: true });
        if (type === 'update') batch.update(ref, data);
        if (type === 'delete') batch.delete(ref);
      });
      await batch.commit();
      logger.debug(`Firestore: Batch commit ${operations.length} operations`);
      return true;
    } catch (err) {
      logger.error(`Firestore error:`, err.message);
      throw err;
    }
  }
};

// Firebase Auth utility functions
const firebaseAuth = {
  // Create user
  createUser: async (email, password) => {
    if (!auth) {
      logger.error('Firebase Auth not initialized');
      return null;
    }
    try {
      const user = await auth.createUser({ email, password });
      logger.debug(`Firebase Auth: Created user ${user.uid}`);
      return user;
    } catch (err) {
      logger.error(`Firebase Auth error:`, err.message);
      throw err;
    }
  },

  // Get user
  getUser: async (uid) => {
    if (!auth) {
      logger.error('Firebase Auth not initialized');
      return null;
    }
    try {
      const user = await auth.getUser(uid);
      return user;
    } catch (err) {
      logger.error(`Firebase Auth error:`, err.message);
      throw err;
    }
  },

  // Generate ID token
  generateIdToken: async (uid) => {
    if (!auth) {
      logger.error('Firebase Auth not initialized');
      return null;
    }
    try {
      const token = await auth.createCustomToken(uid);
      return token;
    } catch (err) {
      logger.error(`Firebase Auth error:`, err.message);
      throw err;
    }
  },

  // Verify token
  verifyToken: async (token) => {
    if (!auth) {
      logger.error('Firebase Auth not initialized');
      return null;
    }
    try {
      const decoded = await auth.verifyIdToken(token);
      return decoded;
    } catch (err) {
      logger.error(`Firebase Auth error:`, err.message);
      throw err;
    }
  }
};

// Realtime database utility functions
const realtimeDatabase = {
  // Set value
  set: async (path, data) => {
    if (!realtimeDb) {
      logger.error('Realtime Database not initialized');
      return false;
    }
    try {
      await realtimeDb.ref(path).set(data);
      logger.debug(`Realtime DB: Set ${path}`);
      return true;
    } catch (err) {
      logger.error(`Realtime DB error:`, err.message);
      throw err;
    }
  },

  // Get value
  get: async (path) => {
    if (!realtimeDb) {
      logger.error('Realtime Database not initialized');
      return null;
    }
    try {
      const snapshot = await realtimeDb.ref(path).get();
      return snapshot.val();
    } catch (err) {
      logger.error(`Realtime DB error:`, err.message);
      throw err;
    }
  },

  // Delete value
  delete: async (path) => {
    if (!realtimeDb) {
      logger.error('Realtime Database not initialized');
      return false;
    }
    try {
      await realtimeDb.ref(path).remove();
      logger.debug(`Realtime DB: Deleted ${path}`);
      return true;
    } catch (err) {
      logger.error(`Realtime DB error:`, err.message);
      throw err;
    }
  }
};

module.exports = {
  admin,
  db,
  auth,
  realtimeDb,
  firestore,
  firebaseAuth,
  realtimeDatabase
};
