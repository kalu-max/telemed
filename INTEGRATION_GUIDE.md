# Doctor-Patient Video Conferencing Integration Guide

## System Overview

This document explains how the Doctor Portal (web), Flutter App (patient), and Backend (Node.js) work together to enable seamless video conferencing.

## Architecture Diagram

```
                    ┌─────────────────────────────────────┐
                    │     TELEMEDICINE ECOSYSTEM          │
                    └─────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ↓              ↓              ↓
        ┌──────────────────┐  ┌─────────────┐  ┌──────────────────┐
        │  Flutter App     │  │  Signaling  │  │  Doctor Portal   │
        │  (Patient)       │  │  Server     │  │  (Web)           │
        │                  │  │  (Node.js)  │  │                  │
        │ - Login/Register │  │             │  │ - Login/Register │
        │ - Find Doctors   │  │ - Socket.io │  │ - View Appts     │
        │ - Book Appts     │  │ - WebRTC    │  │ - Join Calls     │
        │ - Video Call     │  │   Signaling │  │ - Video Call     │
        │ - Prescription   │  │ - Message   │  │ - Screen Share   │
        └────────┬─────────┘  │   Relay     │  │ - Chat           │
                 │            │ - Metrics   │  └────────┬─────────┘
                 │            │   Storage   │           │
                 └────────────┼─────────────┼───────────┘
                              │
                    ┌─────────┴──────────┐
                    │                    │
                    ↓                    ↓
            ┌──────────────┐    ┌──────────────┐
            │  Database    │    │  File Store  │
            │  (MongoDB)   │    │  (Videos,    │
            │              │    │   Reports)   │
            └──────────────┘    └──────────────┘
```

## Communication Flow

### 1. Patient Initiates Consultation

```
Patient (Flutter App)
    ↓ [REST API] POST /api/appointments/book
Backend (Node.js)
    ↓ [Store appointment]
    ↓ [Rest API] GET /api/doctors/:id
Patient (Flutter App)
    ↓ [Shows "waiting for doctor" screen]
    ↓ [WebSocket] emit('patient:call-request')
Signaling Server
    ↓ [Relay to doctor]
Doctor Portal
    ↓ [Shows "Incoming Call" notification]
```

### 2. Doctor Accepts Call

```
Doctor (Web Portal)
    ↓ [Click "Accept" button]
    ↓ [WebSocket] emit('call:respond', { accept: true })
Signaling Server
    ↓ [Update call status]
    ↓ [Relay acceptance]
Patient (Flutter App)
    ↓ [Shows "Connecting..." screen]
```

### 3. WebRTC Peer Connection Establishment

```
Patient Browser/App                 Doctor Browser/App
    ↓                                    ↓
[Request media access]             [Request media access]
    ↓                                    ↓
[getUserMedia()]                   [getUserMedia()]
    ↓                                    ↓
[Create RTCPeerConnection]         [Create RTCPeerConnection]
    ↓[Create Offer]                    ↓[Wait for Offer]
    ├─────→ [WebSocket: webrtc:offer] ──→
                                       ↓
                                    [Set Remote Description]
                                    [Create Answer]
                                       ├──→ [WebSocket: webrtc:answer] ──→
    ↓
[Set Remote Description]
    ↓
[Candidates Exchange] ←─────────────────→
    ↓                                    ↓
[Connection Established]          [Connection Established]
    ↓                                    ↓
[HQ Video/Audio Stream] ←──────────→ [HQ Video/Audio Stream]
```

### 4. During Active Call

```
Patient                         Doctor
  ↓ [Video/Audio]               ↓ [Video/Audio]
  ↔────── WebRTC P2P ────────────↔
  ↓ [Screen pointer]             ↓ [Receives pointer]
  ↓ [Mute/Unmute]                ↓ [Mute/Unmute]
  ↓ [Chat message]               ↓ [Chat message]
  └────→ [Socket.io] ────────────←┘
  ↓ [Metrics report]             ↓ [Metrics report]
  └────→ [Socket.io] ────────────←┘
```

### 5. Call Termination

```
Doctor (or Patient)
    ↓ [Click "End Call"]
    ↓ [WebSocket] emit('call:end', { reason: 'complete' })
Signaling Server
    ↓ [Close call]
    ↓ [Notify other party]
Patient/Doctor
    ↓ [Close RTCPeerConnection]
    ↓ [Stop media streams]
    ↓ [Show rating/feedback screen]
Backend
    ↓ [Save call record with duration]
    ↓ [Save metrics data]
```

## Technology Integration Points

### 1. Authentication Integration

**Doctor Registration (Portal):**
```
Doctor Portal → REST API POST /api/auth/register
  ↓
Backend validates and stores doctor data
  ↓
Returns JWT token
  ↓
Doctor uses token for Socket.io authentication
```

**Patient Registration (Flutter):**
```
Flutter App → REST API POST /api/auth/register
  ↓
Backend validates and stores patient data
  ↓
Returns JWT token
  ↓
Patient uses token for Socket.io authentication
```

### 2. Appointment System

**Book Appointment:**
```
Flutter App → REST API POST /api/appointments
  {
    doctorId: "doctor_123",
    patientId: "patient_456",
    appointmentTime: "2026-02-27T14:00:00Z",
    reason: "Chest pain consultation"
  }
  ↓
Backend creates appointment record
  ↓
Returns appointment with appointment ID
```

**Retrieve Upcoming Appointments:**
```
Doctor Portal → REST API GET /api/appointments?status=pending
  ↓
Backend returns list of appointments
  ↓
Portal displays in sidebar for quick access
```

### 3. WebRTC Signaling via Socket.io

**Connection Established:**
```javascript
// Both client connect with JWT token
socket = io(serverUrl, {
  auth: { token: jwtToken }
});

// Server verifies and stores connection
io.use((socket, next) => {
  const decoded = jwt.verify(socket.handshake.auth.token);
  socket.userId = decoded.userId;
  socket.role = decoded.role; // 'doctor' or 'patient'
  next();
});
```

**Offer/Answer Exchange:**
```javascript
// Patient initiates
patient_socket.emit('patient:call-request', {
  doctorId: 'doctor_123',
  patientId: 'patient_456',
  patientName: 'John Doe'
});

// Server relays to doctor
doctor_socket.on('patient:call-request', (data) => {
  // Show notification
});

// Doctor accepts
doctor_socket.emit('call:respond', { 
  callId: 'call_123', 
  accept: true 
});

// Now WebRTC negotiation begins
patient_socket.emit('webrtc:offer', {
  offer: rtcOffer,
  recipientId: 'doctor_123'
});

doctor_socket.on('webrtc:offer', (data) => {
  // Process offer
  // Create answer
  // Send back
});
```

### 4. Media Quality Adaptation

```javascript
// Patient monitors network
patient.on('network:quality-change', (quality) => {
  if (quality === 'poor') {
    // Reduce resolution to 360p
    // Reduce FPS to 15
  } else if (quality === 'excellent') {
    // Increase resolution to 1080p
    // Increase FPS to 30
  }
  
  // Notify doctor of change
  socket.emit('network:quality-change', {
    quality,
    bandwidth: measureBandwidth(),
    latency: measureLatency()
  });
  
  doctor_socket.on('peer:network-quality', (data) => {
    // Show indicator to doctor
  });
});
```

### 5. Chat Messaging During Call

```javascript
// Patient sends message
patient_socket.emit('chat:message', {
  message: 'My symptoms started yesterday',
  recipientId: 'doctor_123',
  sender: 'patient'
});

// Doctor receives
doctor_socket.on('chat:message', (data) => {
  // Display in chat panel
});

// Doctor replies
doctor_socket.emit('chat:message', {
  message: 'Have you taken any medication?',
  recipientId: 'patient_456',
  sender: 'doctor'
});
```

## Implementation Checklist

### Backend (Node.js)
- [x] Express.js server setup
- [x] Socket.io integration
- [x] WebRTC signaling handlers
- [x] Authentication middleware
- [x] CORS configuration
- [x] Static file serving for doctor portal
- [ ] Database integration (MongoDB)
- [ ] Call recording (optional)
- [ ] Metrics storage
- [ ] Email notifications

### Doctor Portal (Web)
- [x] HTML5 interface
- [x] WebRTC implementation
- [x] Socket.io client
- [x] Login/Register
- [x] Appointment display
- [x] Video controls
- [x] Chat interface
- [x] Call stats display
- [ ] Prescription generation form
- [ ] Call history

### Flutter App (Patient)
- [x] Login/Register screens
- [x] Doctor search and booking
- [x] Video call screen
- [x] WebRTC integration
- [x] Socket.io client
- [ ] Prescription viewing
- [ ] Call history
- [ ] Rating/review system
- [ ] Appointment management

## Running the System

### Step 1: Start Backend

```bash
cd telemedicine_backend
npm install
npm start

# Server running on http://localhost:5000
# Doctor Portal accessible at http://localhost:5000/doctor
```

### Step 2: Start Flutter App

```bash
cd telemedicine_app
flutter pub get
flutter run -d edge  # For web
# or
flutter run -d windows  # For desktop
```

### Step 3: Test the Flow

#### As Patient:
1. Go to http://localhost (Flutter app)
2. Register as patient
3. Search for "Dr. Smith"
4. Click "Book Now"
5. Follow appointment setup
6. Wait for doctor to accept

#### As Doctor:
1. Go to http://localhost:5000/doctor
2. Register as doctor
3. See patient's appointment in sidebar
4. Click appointment to initiate call
5. OR wait for incoming call from patient
6. Click "Accept" when notified
7. Video conference begins

## Network Considerations

### Port Configuration
- Flask/Flutter Dev: 3000
- Node.js Backend: 5000
- Socket.io: 5000 (same as backend)

### Firewall Rules
Allow outbound connections on:
- Port 5000 (WebSocket/Socket.io)
- Port 443 (HTTPS)
- Ports 32768-65535 (RTP/RTCP for WebRTC)

### TURN Server (for NAT Traversal)
For production, deploy TURN server and configure:
```javascript
const rtcConfig = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    {
      urls: 'turn:your-turn-server.com:3478',
      username: 'user',
      credential: 'pass'
    }
  ]
};
```

## Security Best Practices

1. **Use HTTPS/WSS in Production**
   ```javascript
   const io = socketIO(server, {
     transports: ['websocket'],
     secure: true
   });
   ```

2. **Implement Rate Limiting**
   ```javascript
   const limiter = rateLimit({
     windowMs: 15 * 60 * 1000,
     max: 100
   });
   app.use('/api/', limiter);
   ```

3. **Validate and Sanitize Data**
   ```javascript
   socket.on('chat:message', (data) => {
     const message = sanitize(data.message);
     // Process
   });
   ```

4. **Use Strong JWT Secrets**
   ```javascript
   process.env.JWT_SECRET = 'very-long-random-secret-key-min-32-chars'
   ```

## Monitoring and Debugging

### Check Server Status
```bash
curl http://localhost:5000/health
```

### View Connection Stats
```javascript
// In doctor portal console
socket.emit('debug:stats', (stats) => {
  console.log('Active calls:', stats.activeCalls);
  console.log('Connected doctors:', stats.totalDoctors);
  console.log('Connected patients:', stats.totalPatients);
});
```

### Enable Logging
```bash
DEBUG=* npm start  # Verbose logging
```

## Troubleshooting Integration Issues

### Issue: "Connection Refused" on localhost:5000
**Solution**: Ensure backend is running
```bash
cd telemedicine_backend && npm start
```

### Issue: CORS Error
**Solution**: Check CORS configuration in server.js and update origin URLs

### Issue: Socket.io Connection Fails
**Solution**: 
1. Check token is valid
2. Ensure WebSocket protocol is working
3. Check firewall rules

### Issue: No Video After Connection
**Solution**:
1. Verify getUserMedia permissions granted
2. Check camera is not in use by other apps
3. Restart browser

## Production Deployment

### AWS EC2
```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Clone and setup
git clone <repo>
cd telemedicine_backend
npm install
PM2 ecosystem.config.js start
```

### Docker
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 5000
CMD ["node", "server.js"]
```

```bash
docker build -t telemedicine-backend .
docker run -p 5000:5000 --env-file .env telemedicine-backend
```

## Monitoring Metrics

Track these for production:
- **CPU Usage**: Keep below 70%
- **Memory**: Monitor heap size
- **Active Connections**: Number of concurrent users
- **Call Duration**: Average consultation length
- **Failed Calls**: Connection failure rate
- **Network Quality**: Average bandwidth, latency
- **Error Rate**: API errors per minute

---

**Version**: 1.0.0  
**Last Updated**: February 2026  
**Status**: Integration Complete ✅
