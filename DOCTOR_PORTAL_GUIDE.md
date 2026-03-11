# Doctor Portal - Separate Web Interface for Video Conferencing

## Overview
The Doctor Portal is a standalone web application that allows doctors to:
- Accept incoming consultation requests from patients
- Conduct HD video consultations
- Monitor network quality and call statistics
- Share screens with patients
- Exchange messages in real-time during calls
- Manage their appointment schedule

## Architecture

### Technology Stack
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **WebRTC**: Peer-to-peer video communication
- **Signaling**: Socket.io for WebRTC offer/answer/ICE candidate exchange
- **Backend**: Node.js Express with Socket.io server

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                 Doctor Portal (Web App)                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Browser (HTML5 + WebRTC)                            │   │
│  │ - User Interface                                    │   │
│  │ - Local Media Stream Management                     │   │
│  │ - RTCPeerConnection                                 │   │
│  └──────────────────────┬──────────────────────────────┘   │
└─────────────────────────┼──────────────────────────────────┘
                          │ WebSocket (Socket.io)
                          ↓
┌─────────────────────────────────────────────────────────────┐
│            Signaling Server (Backend)                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Node.js + Socket.io                                 │   │
│  │ - Relay WebRTC Offers/Answers                       │   │
│  │ - Distribute ICE Candidates                         │   │
│  │ - Manage Call State                                 │   │
│  │ - Forward Chat Messages                             │   │
│  │ - Record Call Metrics                               │   │
│  └──────────────────────┬──────────────────────────────┘   │
└─────────────────────────┼──────────────────────────────────┘
                          │ WebSocket
                          ↓
                    Flutter Patient App
                    (Identical WebRTC Flow)
```

## Setup Instructions

### 1. Backend Setup

#### Prerequisites
- Node.js 14+ 
- npm or yarn
- MongoDB (optional, for persistent storage)

#### Installation

```bash
cd telemedicine_backend
npm install
cp .env.example .env
# Edit .env with your configuration
npm start
```

#### Environment Variables (`.env`)

```env
# Server
PORT=5000
NODE_ENV=development

# CORS Configuration
FRONTEND_URL=http://localhost:3000
DOCTOR_PORTAL_URL=http://localhost:5000

# JWT Secret (for authentication)
JWT_SECRET=your_super_secret_jwt_key_change_this

# Database (optional)
MONGODB_URI=mongodb://localhost:27017/telemedicine

# Socket.io Configuration
SOCKET_IO_PORT=5000
SOCKET_IO_CORS_ORIGIN=http://localhost:5000,http://localhost:3000
```

### 2. Access Doctor Portal

Once the backend is running:

```
http://localhost:5000/doctor
```

### 3. Doctor Registration & Login

1. Click "Register" on the login modal
2. Enter your details:
   - Full Name (e.g., "Dr. John Smith")
   - Specialty (e.g., "Cardiologist")
   - Email (e.g., "doctor@example.com")
   - Password
3. Click "Register"
4. Your profile appears in the sidebar

## Features

### 1. Video Consultation

**Starting a Call:**
- View upcoming appointments in the sidebar
- Click on a patient's appointment to initiate call
- OR wait for incoming call request from patient

**During Call:**
- Real-time HD video stream from both doctor and patient
- Synchronized audio
- Low-latency communication (~50-100ms typical)

**Call Controls:**
- 🎤 **Microphone**: Toggle audio mute/unmute
- 📹 **Camera**: Toggle video on/off
- 🖥️ **Screen Share**: Share your screen with patient
- 💬 **Chat**: Open real-time chat panel
- 📊 **Stats**: Display call quality metrics

### 2. Screen Sharing

Share your screen to show:
- Medical reports and images
- Test results and diagnostics
- Prescriptions
- Educational materials

```javascript
// Automatic handling in UI
- Click screen share button
- Grant permission to share display
- Switch back to camera when done
```

### 3. Call Quality Monitoring

Real-time metrics display:
- **Resolution**: Current video resolution (e.g., 720p, 1080p)
- **FPS**: Frame rate (15-30 FPS)
- **Bitrate**: Data rate in KB/s
- **Latency**: Round-trip time in milliseconds
- **Network Quality**: Excellent/Good/Fair/Poor indicator

### 4. Chat System

Exchange messages during consultation:
- Type messages while video is active
- Message history maintained during call
- Timestamps for each message
- Automatic scrolling to latest messages

### 5. Appointment Management

**Sidebar Features:**
- List of upcoming appointments
- Patient names and scheduled times
- Quick access to start calls
- Status badges (pending, active, etc.)

## WebRTC Flow Diagram

```
┌──────────┐                        ┌──────────┐
│  Doctor  │                        │ Patient  │
│ (Portal) │                        │  (App)   │
└────┬─────┘                        └────┬─────┘
     │                                    │
     │     1. Call Request (Socket.io)    │
     ├───────────────────────────────────→│
     │                                    │
     │     2. Offer (WebRTC)              │
     ├───────────────────────────────────→│
     │                                    │
     │   3. Answer (WebRTC)               │
     │←───────────────────────────────────┤
     │                                    │
     │   4. ICE Candidates (multiple)     │
     │←──────────────────────────────────→│
     │                                    │
     │   5. Peer Connection Established   │
     │↔━━━━━━━━━━━ Video/Audio ━━━━━━━━━━↔
     │                                    │
     │   6. Chat Messages (Real-time)     │
     │←──────────────────────────────────→│
     │                                    │
     │   7. Call Metrics (Periodic)       │
     │←──────────────────────────────────│
     │                                    │
     │   8. End Call (Socket.io)          │
     ├───────────────────────────────────→│
     │                                    │
```

## Network Requirements

### Minimum Requirements
- **Bandwidth**: 1 Mbps upload, 1 Mbps download (SD quality)
- **Latency**: <300ms (acceptable, >150ms may cause echoes)
- **Jitter**: <50ms
- **Packet Loss**: <1%

### Recommended Requirements
- **Bandwidth**: 2.5 Mbps upload, 2.5 Mbps download (HD quality)
- **Latency**: <100ms
- **Jitter**: <20ms
- **Packet Loss**: <0.5%

### Adaptive Quality

The app automatically adjusts:
- If bandwidth drops → resolution decreases, FPS reduced
- If bandwidth improves → resolution increases, better quality
- If latency increases → frame skipping to maintain responsiveness

## Security Features

### Authentication
- JWT token-based authentication
- Secure password storage (bcrypt)
- Token expiration and refresh
- Role-based access control

### Encryption
- TLS/SSL for WebSocket connections
- DTLS-SRTP for media encryption (built-in WebRTC)
- Signaling data encrypted over HTTPS

### Privacy
- User data isolated per session
- Call recordings (if enabled) encrypted
- Metrics data anonymized
- No data retention beyond call duration (unless configured)

## Performance Optimization

### Frontend
- Lazy loading of components
- Efficient DOM management
- Compressed video streams
- Hardware acceleration for video encoding/decoding

### Backend
- Connection pooling for databases
- Redis caching for session data
- Rate limiting on API endpoints
- Load balancing for multiple signaling servers

## Troubleshooting

### Issue: Camera/Microphone Access Denied
**Solution**: 
- Check browser permissions
- Reset camera/microphone permissions in OS settings
- Restart browser and website

### Issue: No Video From Patient
**Solution**:
- Check if patient's camera is enabled (green light off)
- Ask patient to check their camera permission
- Both need to click "Accept" on permission prompts
- Try using different network (WiFi vs Cellular)

### Issue: Audio Feedback/Echo
**Solution**:
- Mute doctor's microphone if both using same device
- Move microphone further from speaker
- Use headphones/earbuds
- Check audio settings in OS

### Issue: Connection Drops
**Solution**:
- Check internet connection stability
- Move closer to WiFi router
- Try disabling screen share
- Restart browser and reconnect

### Issue: High Latency (Slow Video)
**Solution**:
- Close other bandwidth-consuming applications
- Switch to 5GHz WiFi band
- Move to location with better signal
- Reduce screen resolution (Settings)

## API Reference

### Socket.io Events

#### Patient Initiating Call
```javascript
socket.emit('patient:call-request', {
  doctorId: 'doctor_123',
  patientId: 'patient_456',
  patientName: 'John Doe',
  patientAvatar: 'https://...'
});

socket.on('patient:call-request', (data) => {
  // Doctor receives incoming call
  console.log(`Call from ${data.patientName}`);
});
```

#### WebRTC Signaling
```javascript
// Send offer
socket.emit('webrtc:offer', {
  offer: rtcSessionDescription,
  recipientId: 'patient_456'
});

// Send answer
socket.emit('webrtc:answer', {
  answer: rtcSessionDescription,
  recipientId: 'doctor_123'
});

// Send ICE candidate
socket.emit('webrtc:ice-candidate', {
  candidate: rtcIceCandidate,
  recipientId: 'patient_456'
});
```

#### Chat Messages
```javascript
socket.emit('chat:message', {
  message: 'How are your symptoms?',
  recipientId: 'patient_456',
  sender: 'doctor'
});

socket.on('chat:message', (data) => {
  console.log(`Message from ${data.senderId}: ${data.message}`);
});
```

#### Metrics Reporting
```javascript
socket.emit('metrics:report', {
  callId: 'call_123',
  metrics: {
    resolution: '1280x720',
    fps: 30,
    bitrate: 2500,
    latency: 45,
    packetLoss: 0.1,
    quality: 'excellent'
  }
});
```

#### Call Termination
```javascript
socket.emit('call:end', {
  callId: 'call_123',
  recipientId: 'patient_456',
  reason: 'consultation_complete'
});

socket.on('call:ended', (data) => {
  console.log(`Call ended: ${data.reason}`);
});
```

## Deployment

### For Cloud Deployment (AWS, Google Cloud, Azure, etc.)

1. **Set up Node.js server** with auto-scaling
2. **Configure TLS/SSL** with valid certificates
3. **Use TURN servers** as fallback for NAT traversal
4. **Enable WebRTC stats collection** for monitoring
5. **Set up database** for persistent storage
6. **Configure CDN** for static files
7. **Set up logging and monitoring** (Cloudwatch, Stackdriver, etc.)

### Example TURN Server Configuration

```javascript
const rtcConfig = {
  iceServers: [
    { urls: ['stun:stun.l.google.com:19302'] },
    {
      urls: ['turn:your-turn-server.com:3478'],
      username: 'turnuser',
      credential: 'turnpass'
    }
  ]
};
```

## Future Enhancements

- [ ] Recording consultation sessions
- [ ] Prescription generation workflow
- [ ] Integration with EHR systems
- [ ] Multi-party conferencing
- [ ] Advanced scheduling and calendar integrations
- [ ] Payment processing
- [ ] Analytics and reporting dashboard
- [ ] Mobile-optimized doctor portal
- [ ] AI-powered diagnostics assistance
- [ ] Post-consultation follow-up system

## Support

For issues and questions:
1. Check the **Troubleshooting** section
2. Review **Browser Console** for JavaScript errors
3. Check **Network Tab** in DevTools for failed connections
4. Contact development team with error screenshots

## License

This project is licensed under the MIT License - see LICENSE file for details.

---

**Version**: 1.0.0  
**Last Updated**: February 2026  
**Status**: Production Ready ✅
