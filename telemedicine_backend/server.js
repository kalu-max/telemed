const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const http = require('http');
const socketIO = require('socket.io');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config();

// Ensure JWT_SECRET is set — generate one if missing (dev convenience)
if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'your-secret-key') {
  const crypto = require('crypto');
  process.env.JWT_SECRET = crypto.randomBytes(32).toString('hex');
  console.warn('[SECURITY] JWT_SECRET was missing or default. Generated a random secret for this session. Set JWT_SECRET in .env for production.');
}

// Database imports
const { sequelize, syncDatabase } = require('./server/config/database');
const { firestore, firebaseAuth } = require('./server/config/firebase');

const { initializeCommunicationSocket } = require('./server/websocket/communicationHandler');
const callManagementAPI = require('./server/api/callManagement');
const authAPI = require('./server/api/auth');
const userAPI = require('./server/api/users');
const prescriptionsAPI = require('./server/api/prescriptions');
const metricsAPI = require('./server/api/metrics');
const { verifyToken } = require('./server/middleware/auth');
const { errorHandler } = require('./server/middleware/errorHandler');
const logger = require('./server/utils/logger');

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Required for correct HTTPS detection behind reverse proxies (Render, Heroku, etc.).
app.set('trust proxy', 1);

// Build allowed-origins list from env var (comma-separated) plus always allow localhost
const _rawAllowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
const _allowAnyOrigin = _rawAllowedOrigins.includes('*');
const _extraOrigins = _rawAllowedOrigins.filter((origin) => origin !== '*');

function isOriginAllowed(origin) {
  if (!origin) return true; // same-origin / non-browser
  if (_allowAnyOrigin) return true;
  if (origin.includes('localhost') || origin.includes('127.0.0.1')) return true;
  return _extraOrigins.some((o) => origin === o);
}

function getCorsModeDescription() {
  if (_allowAnyOrigin) {
    return 'all origins allowed (*), plus non-browser clients';
  }

  if (_extraOrigins.length > 0) {
    return `${_extraOrigins.join(', ')}, plus localhost and non-browser clients`;
  }

  return 'localhost and non-browser clients only';
}

const io = socketIO(server, {
  cors: {
    origin: (origin, callback) => {
      if (isOriginAllowed(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST'],
    credentials: true
  },
  pingInterval: 25000,
  pingTimeout: 60000
});

// Middleware
app.use(helmet());
app.use(morgan('combined'));

// HTTPS enforcement in production (behind reverse proxy like Render, Heroku, etc.)
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    // Keep health checks HTTP-friendly so platform probes don't fail deployment.
    if (req.path === '/health') {
      return next();
    }

    const forwardedProto = req.headers['x-forwarded-proto'];
    const isHttps = req.secure || forwardedProto === 'https';

    if (!isHttps) {
      const host = req.headers.host || '';
      return res.redirect(301, `https://${host}${req.url}`);
    }
    // Strict-Transport-Security (HSTS)
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
  });
}

app.use(cors({
  origin: (origin, callback) => {
    if (isOriginAllowed(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Serve static files from public directory (for doctor portal)
app.use(express.static(path.join(__dirname, 'public')));

// Swagger API documentation
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./server/config/swagger');
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Telemedicine API Docs',
}));
app.get('/api-docs.json', (req, res) => res.json(swaggerSpec));

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // limit login attempts
  message: 'Too many login attempts, please try again later.'
});

// Apply rate limits
app.use('/api/', apiLimiter);
app.use('/api/auth/login', authLimiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Serve doctor portal
app.get('/doctor', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'doctor-portal.html'));
});

// API Routes
app.use('/api/auth', authAPI);
app.use('/api/users', verifyToken, userAPI);
app.use('/api/calls', verifyToken, callManagementAPI);
app.use('/api/metrics', verifyToken, metricsAPI);
app.use('/api/prescriptions', verifyToken, prescriptionsAPI);

// Backward-compatible aliases used by current mobile clients.
app.use('/api', verifyToken, userAPI);

// WebSocket/Socket.io setup
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (token) {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.userId;
      socket.doctorId = decoded.doctorId;
      socket.role = decoded.role;
    } catch (err) {
      return next(new Error('Invalid token'));
    }
  } else {
    // Accept connections that identify via query params (WebRTC/mobile clients)
    const queryUserId = socket.handshake.query && socket.handshake.query.userId;
    if (queryUserId) {
      socket.userId = queryUserId;
      socket.role = (socket.handshake.query.role) || 'patient';
    } else {
      return next(new Error('Authentication required'));
    }
  }
  return next();
});

// Use a single Socket.IO signaling handler to avoid duplicate call events.
initializeCommunicationSocket(io);

// Error handling middleware
app.use(errorHandler);

let reminderSchedulerStarted = false;

function startReminderSchedulerSafely() {
  if (reminderSchedulerStarted) return;
  try {
    const { startReminderScheduler } = require('./server/services/reminderScheduler');
    const models = require('./server/models/index');
    const { pushNotification } = require('./server/api/users');
    startReminderScheduler(models, pushNotification || (() => {}));
    reminderSchedulerStarted = true;
  } catch (e) {
    logger.warn(`Reminder scheduler not started: ${e.message}`);
  }
}

async function seedApplicationState() {
  if (typeof authAPI.seedAdminUser === 'function') {
    await authAPI.seedAdminUser();
  }

  if (typeof userAPI.seedUsersCache === 'function') {
    await userAPI.seedUsersCache();
  }

  if (typeof prescriptionsAPI.seedPrescriptionsCache === 'function') {
    await prescriptionsAPI.seedPrescriptionsCache();
  }
}

async function syncDatabaseWithRetry() {
  const retryMs = 30000;
  while (true) {
    try {
      logger.info('🔄 Synchronizing PostgreSQL database...');
      await syncDatabase();
      await seedApplicationState();
      logger.info('✅ PostgreSQL ready');
      startReminderSchedulerSafely();
      return;
    } catch (error) {
      logger.error(`❌ Database initialization failed, retrying in ${retryMs / 1000}s: ${error.message}`);
      await new Promise((resolve) => setTimeout(resolve, retryMs));
    }
  }
}

// Initialize app: start HTTP server first (for health checks), then DB in background
const initializeApp = async () => {
  try {
    const PORT = process.env.PORT || 5000;
    server.listen(PORT, () => {
      logger.info(`🎥 Telemedicine Video Backend running on port ${PORT}`);
      logger.info(`📊 PostgreSQL: ${process.env.DB_HOST || 'via DATABASE_URL'}:${process.env.DB_PORT || ''}/${process.env.DB_NAME || ''}`);
      logger.info(`🔥 Firebase: ${process.env.FIREBASE_PROJECT_ID || 'Not configured'}`);
      logger.info(`📡 WebRTC Signaling Server active`);
      logger.info(`🔒 CORS mode: ${getCorsModeDescription()}`);
      logger.info('✅ Firebase utilities loaded');
      logger.info(`📖 API Docs available at /api-docs`);
    });

    // Do not block server startup on DB readiness (important for hosted health checks)
    syncDatabaseWithRetry().catch((error) => {
      logger.error(`❌ Background database sync crashed: ${error.message}`);
    });
  } catch (error) {
    logger.error('❌ Failed to initialize application:', error.message);
    process.exit(1);
  }
};

// Start the application (skip when running tests)
if (process.env.NODE_ENV !== 'test') {
  initializeApp();
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

module.exports = { app, server, io };
