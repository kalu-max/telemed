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

// Database imports
const { sequelize, syncDatabase } = require('./server/config/database');
const { firestore, firebaseAuth } = require('./server/config/firebase');

const videoSignalingServer = require('./server/websocket/videoSignaling');
const doctorVideoSignalingServer = require('./server/websocket/doctorVideoSignaling');
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

// Build allowed-origins list from env var (comma-separated) plus always allow localhost
const _extraOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

function isOriginAllowed(origin) {
  if (!origin) return true; // same-origin / non-browser
  if (origin.includes('localhost') || origin.includes('127.0.0.1')) return true;
  return _extraOrigins.some((o) => origin === o);
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
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
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

// Initialize video signaling with Socket.io
videoSignalingServer(io);
doctorVideoSignalingServer(io);
initializeCommunicationSocket(io);

// Error handling middleware
app.use(errorHandler);

// Initialize databases and start server
const initializeApp = async () => {
  try {
    // Sync PostgreSQL database
    logger.info('🔄 Synchronizing PostgreSQL database...');
    await syncDatabase();
    logger.info('✅ PostgreSQL ready');

    // Verify Firebase (optional - if not initialized, warning already logged)
    logger.info('✅ Firebase utilities loaded');

    // Start server
    const PORT = process.env.PORT || 5000;
    server.listen(PORT, () => {
      logger.info(`🎥 Telemedicine Video Backend running on port ${PORT}`);
      logger.info(`📊 PostgreSQL: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
      logger.info(`🔥 Firebase: ${process.env.FIREBASE_PROJECT_ID || 'Not configured'}`);
      logger.info(`📡 WebRTC Signaling Server active`);
      logger.info(`🔒 CORS enabled for ${process.env.FRONTEND_URL}`);
    });
  } catch (error) {
    logger.error('❌ Failed to initialize application:', error.message);
    process.exit(1);
  }
};

// Start the application
initializeApp();

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

module.exports = { app, server, io };
