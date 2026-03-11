# Telemedicine Video Conferencing Backend

A robust, production-ready Node.js backend for high-quality, low-bandwidth video conferencing in telemedicine applications. Supports both WiFi and cellular networks with adaptive quality streaming, real-time signaling using WebRTC, and comprehensive call management.

## 🎯 Features

### Video Conferencing
- **WebRTC-based Video Calls** - Peer-to-peer video and audio using WebRTC
- **Adaptive Bitrate Streaming** - Automatically adjusts quality based on network conditions
- **Dual Network Support** - Seamless handoff between WiFi and cellular networks
- **Low Bandwidth Mode** - Optimized streaming for 2G/3G connections
- **ICE Candidate Management** - Efficient NAT traversal with STUN/TURN servers

### Call Management
- **Call Initiation & Acceptance** - WebSocket-based signaling
- **Call History Tracking** - Store and retrieve call records
- **Call Quality Metrics** - Real-time quality monitoring and analytics
- **Call Recording** - Optional recording with secure storage
- **Prescription Integration** - Share prescriptions during/after calls

### Network Features
- **Real-time Network Monitoring** - Detect network type and quality changes
- **Bandwidth Detection** - Measure available bandwidth
- **Latency Monitoring** - Track network latency
- **Multi-Network Handoff** - Switch between networks without dropping calls

### Telemedicine Features
- **Doctor-Patient Scheduling** - Appointment booking and management
- **Doctor Profiles** - Specialization, ratings, availability
- **Patient Records** - Medical history and consultation records
- **HIPAA-Ready** - Designed for healthcare compliance
- **End-to-End Encryption** - Secure communication (optional)

### Analytics & Monitoring
- **Call Quality Scoring** - Metrics based on resolution, FPS, latency
- **Network Performance Analytics** - Historical trend analysis
- **User Statistics** - Total calls, average quality, trends
- **Real-time Dashboards** - Monitor system health

## 📋 Prerequisites

- Node.js 16.x or higher
- npm 8.x or higher
- WebRTC capable browser/device
- (Optional) MongoDB for production data storage
- (Optional) Redis for caching and sessions

## 🚀 Installation

### 1. Clone & Setup

```bash
git clone <repository-url>
cd telemedicine_backend
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your configuration
```

Key environment variables:
```
NODE_ENV=development
PORT=5000
JWT_SECRET=your-secret-key
FRONTEND_URL=http://localhost:3000
```

### 3. Start Server

Development mode:
```bash
npm run dev
```

Production mode:
```bash
npm start
```

Server will start on `http://localhost:5000`

## 🏗️ Architecture

### API Endpoints

#### Authentication
```
POST   /api/auth/register        - User registration
POST   /api/auth/login           - User login
POST   /api/auth/refresh         - Refresh token
POST   /api/auth/logout          - User logout
```

#### Calls
```
POST   /api/calls/initiate       - Initiate a call
POST   /api/calls/answer         - Answer a call
POST   /api/calls/reject         - Reject a call
POST   /api/calls/end            - End a call
GET    /api/calls/history        - Get call history
GET    /api/calls/ongoing        - Get ongoing calls
GET    /api/calls/:callId        - Get call details
POST   /api/calls/:callId/metrics - Update call metrics
```

#### Users
```
GET    /api/users/doctors/available    - List available doctors
GET    /api/users/doctors/:doctorId    - Get doctor profile
PUT    /api/users/doctors/:doctorId    - Update doctor profile
DELETE /api/users/doctors/:doctorId    - Delete doctor account (doctors only)

// notifications
GET    /api/users/notifications        - Get notifications for current user

// admin
GET    /api/users/admin/users         - List all registered users (admin only)
DELETE /api/users/admin/users/:id     - Remove a user (admin only)
POST   /api/users/admin/notify        - Send notification (admin only)

GET    /api/users/appointments         - Get user appointments
POST   /api/users/appointments/book    - Book appointment
```

#### Metrics
```
POST   /api/metrics/call/:callId           - Record call metrics
GET    /api/metrics/call/:callId           - Get call metrics
GET    /api/metrics/user/stats             - Get user statistics
GET    /api/metrics/network/performance    - Get network analytics
```

### WebSocket Events (Socket.io /video namespace)

#### Client -> Server
```
call:initiate              - Start a call
call:answer                - Accept incoming call
call:reject                - Reject call
call:end                   - End call
ice:candidate              - Send ICE candidate
sdp:offer                  - Send SDP offer
call:quality               - Report call quality metrics
network:quality-changed    - Report network quality change
user:available             - Set user availability status
```

#### Server -> Client
```
call:incoming              - Incoming call notification
call:answered              - Call accepted by recipient
call:rejected              - Call declined by recipient
call:ended                 - Call ended by peer
call:timeout               - Call timeout (no response)
call:peer-disconnected     - Peer unexpectedly disconnected
ice:candidate              - ICE candidate from peer
sdp:offer                  - SDP offer from peer
call:quality-update        - Remote peer quality update
user:status-changed        - User status changed
user:disconnected          - User went offline
network:peer-quality-changed - Peer network quality changed
```

## 📊 Network Quality Scoring

Quality score (0-100) calculated based on:
- **Video Resolution** (1080p: 0pts, 360p: 25pts reduction)
- **Frame Rate** (30fps: 0pts, 15fps: 15pts reduction)
- **Latency** (>400ms: 25pts reduction)
- **Packet Loss** (>5%: 25pts reduction)
- **Bandwidth** (<0.5Mbps: 30pts reduction)

### Quality Tiers
- **90-100**: Excellent (HD, 30fps, <50ms latency)
- **70-89**: Good (480p+, 24fps, <100ms latency)
- **50-69**: Fair (480p, 15fps, <150ms latency)
- **20-49**: Poor (360p, 15fps, <250ms latency)
- **<20**: Very Poor (Audio focus, minimal video)

## 🌐 Adaptive Bitrate Presets

```
360p: 250-500 kbps
480p: 500-1200 kbps
720p: 1000-2500 kbps
1080p: 1500-4500 kbps
```

Automatically adjusts based on network bandwidth:
- **3.5+ Mbps**: 1080p@30fps (4500 kbps max)
- **2.0+ Mbps**: 720p@30fps (2500 kbps max)
- **1.2+ Mbps**: 480p@24fps (1200 kbps max)
- **0.6+ Mbps**: 360p@15fps (500 kbps max)
- **<0.6 Mbps**: 360p@15fps with audio focus (250 kbps)

## 🔒 Security Features

- **JWT Authentication** - Stateless, token-based auth
- **CORS Protection** - Configurable cross-origin requests
- **Rate Limiting** - Prevent abuse (100 req/15min, 5 login/15min)
- **Helmet.js** - Security headers (HSTS, X-Frame-Options, etc.)
- **Input Validation** - Sanitize all user inputs
- **HTTPS Ready** - Production deployment over TLS
- **Token Expiration** - Automatic session timeout
- **Role-Based Access** - Doctor vs Patient permissions

## 📝 Database Schema (Optional)

### Users Collection
```javascript
{
  userId: String,
  email: String,
  password: String (hashed),
  name: String,
  role: String, // 'doctor' | 'patient'
  specialization: String, // For doctors
  rating: Number,
  callCount: Number,
  createdAt: Date
}
```

### Calls Collection
```javascript
{
  callId: String,
  initiatorId: String,
  recipientId: String,
  type: String, // 'audio' | 'video'
  status: String, // 'connected' | 'ended'
  startTime: Date,
  endTime: Date,
  duration: Number,
  recordingUrl: String,
  metrics: Array,
  notes: String
}
```

### Appointments Collection
```javascript
{
  appointmentId: String,
  doctorId: String,
  patientId: String,
  slotTime: Date,
  reason: String,
  status: String, // 'scheduled' | 'completed' | 'cancelled'
  notes: String
}
```

## 🔧 Configuration Examples

### Production Deployment
```env
NODE_ENV=production
JWT_SECRET=secure-production-secret-min-32-chars
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/telemedicine
REDIS_URL=redis://prod-redis-server:6379
FRONTEND_URL=https://telemedicine.example.com
ENABLE_CALL_ENCRYPTION=true
```

### Low Bandwidth Deployment
```env
DEFAULT_VIDEO_RESOLUTION=480p
MIN_VIDEO_RESOLUTION=240p
MIN_BANDWIDTH_MOBILE=0.3
MIN_BANDWIDTH_WIFI=0.5
DEFAULT_FRAME_RATE=15
```

### High Security
```env
HELMET_ENABLED=true
ENABLE_CALL_ENCRYPTION=true
JWT_EXPIRATION=8h
CORS_ORIGIN=https://telemedicine.example.com
RATE_LIMIT_MAX_REQUESTS=50
```

## 📱 Mobile Client Integration

### Flutter Client Setup
1. Update pubspec.yaml with Socket.io client
2. Configure API endpoint in TeleMedicineApiClient
3. Initialize EnhancedVideoCallService with WebRTC
4. Monitor network with RealTimeNetworkController
5. Build UI using adaptive quality settings

```dart
// Example initialization
final apiClient = TeleMedicineApiClient('http://localhost:5000');
final networkController = RealTimeNetworkController();
final bitrateController = AdaptiveBitrateController(
  networkController: networkController,
);
final videoService = EnhancedVideoCallService(
  networkController: networkController,
  bitrateController: bitrateController,
  serverUrl: 'http://localhost:5000',
  authToken: 'your-jwt-token',
);
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage

# Lint code
npm run lint
```

## 📊 Monitoring

### Log Files
- `logs/combined.log` - All logs
- `logs/error.log` - Error only

### Health Check
```bash
curl http://localhost:5000/health
# Response: { status: 'OK', timestamp: '...', uptime: 123.45 }
```

### WebSocket Status
Monitor active connections and call sessions via Socket.io dashboard or logs.

## 🚀 Deployment

### Docker Deployment
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 5000
CMD ["npm", "start"]
```

### Kubernetes Deployment
See `deployment/k8s/` directory for Helm charts and manifests.

### AWS/Cloud Deployment
Supports deployment on:
- AWS EC2 with ALB
- AWS Elastic Beanstalk
- Google Cloud Run
- Azure App Service
- Heroku
- Railway.app

## 🔑 API Examples

### Initiate Video Call
```bash
curl -X POST http://localhost:5000/api/calls/initiate \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipientId": "doctor_123",
    "type": "video",
    "initiatorName": "Patient Name"
  }'
```

### Get Call History
```bash
curl -X GET http://localhost:5000/api/calls/history \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Update Call Metrics
```bash
curl -X POST http://localhost:5000/api/calls/call_12345/metrics \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "networkQuality": "good",
    "videoResolution": "720p",
    "frameRate": 30,
    "bitrate": 2500,
    "latency": 50,
    "packetLoss": 0.1,
    "bandwidth": 5.0
  }'
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open Pull Request

## 📄 License

MIT License - See LICENSE file

## 📞 Support

For issues, questions, or contributions:
- GitHub Issues: Report bugs and feature requests
- Email: support@telemedicine.example.com
- Documentation: https://docs.telemedicine.example.com

## 🙏 Acknowledgments

- WebRTC for peer-to-peer communication
- Socket.io for real-time signaling
- STUN/TURN services for NAT traversal
- Healthcare IP providers for HIPAA compliance resources

---

**Built with ❤️ for Healthcare** | Last Updated: 2024
