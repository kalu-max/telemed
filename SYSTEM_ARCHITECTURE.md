# 🏥 Telemedicine Video Conferencing Platform - System Architecture

## 📊 Complete System Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER MOBILE APP                           │
│ ┌─────────────┬────────────────────────────────────────────────────┐   │
│ │   UI Layer  │  Video Call Screen | Doctor List | Appointments   │   │
│ ├─────────────┴────────────────────────────────────────────────────┤   │
│ │                        Provider Services                         │   │
│ │  ┌──────────────────┬──────────────────┬─────────────────────┐  │   │
│ │  │ Enhanced Video   │ Network Monitor  │ Adaptive Bitrate    │  │   │
│ │  │ Service          │ Controller       │ Controller          │  │   │
│ │  │ ┌──────────────┐ │ ┌──────────────┐ │ ┌────────────────┐  │  │   │
│ │  │ │ WebRTC Setup │ │ │ Real-time    │ │ │ Auto Quality   │  │  │   │
│ │  │ │ Call State   │ │ │ Bandwidth    │ │ │ Adjustment     │  │  │   │
│ │  │ │ Metrics      │ │ │ Latency      │ │ │ Resolution/FPS │  │  │   │
│ │  │ │ Recording    │ │ │ Signal Str.  │ │ │ Bitrate        │  │  │   │
│ │  │ └──────────────┘ │ └──────────────┘ │ └────────────────┘  │  │   │
│ │  └──────────────────┴──────────────────┴─────────────────────┘  │   │
│ │                                                                    │   │
│ │  ┌────────────────────────────────────────────────────────────┐  │   │
│ │  │              API Client (Dio HTTP)                         │  │   │
│ │  │  Auth | Calls | Users | Appointments | Metrics            │  │   │
│ │  └────────────────────────────────────────────────────────────┘  │   │
│ └────────────────────────────────────────────────────────────────────┘   │
│                    │                          │                           │
│                    │ HTTPS / JWT Token        │ WebSocket (Socket.io)     │
│                    │                          │                           │
└────────────────────┼──────────────────────────┼──────────────────────────┘
                     │                          │
                     ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         NODE.JS BACKEND SERVER                          │
│                                                                          │
│ ┌──────────────────┬────────────────────┬──────────────────────────┐   │
│ │   REST APIs      │  Socket.io (WebRTC)│  Database & Storage      │   │
│ │ ┌──────────────┐ │ ┌────────────────┐ │ ┌────────────────────┐  │   │
│ │ │ Auth Endpoints│ │ │ Signaling      │ │ │ Call Records       │  │   │
│ │ │ - Register   │ │ │ - Call Routing │ │ │ Metrics Data       │  │   │
│ │ │ - Login      │ │ │ - ICE Exchange │ │ │ User Profiles      │  │   │
│ │ │ - Logout     │ │ │ - SDP Handling │ │ │ Appointments       │  │   │
│ │ └──────────────┘ │ │ - Quality Data │ │ │ Medical Records    │  │   │
│ │                  │ │ - Peer Routing │ │ │ Prescriptions      │  │   │
│ │ ┌──────────────┐ │ └────────────────┘ │ └────────────────────┘  │   │
│ │ │ Call APIs    │ │                    │                          │   │
│ │ │ - Initiate   │ │ Active Connections:│ Optional Services:       │   │
│ │ │ - Answer     │ │ ┌────────────────┐ │ ┌────────────────────┐  │   │
│ │ │ - End        │ │ │ User Sockets   │ │ │ MongoDB Database   │  │   │
│ │ │ - History    │ │ │ Active Calls   │ │ │ Redis Cache        │  │   │
│ │ │ - Metrics    │ │ │ Metrics Stream │ │ │ S3 Recordings      │  │   │
│ │ └──────────────┘ │ └────────────────┘ │ │ Email Notifications│  │   │
│ │                  │                    │ └────────────────────┘  │   │
│ │ ┌──────────────┐ │                    │                          │   │
│ │ │ User APIs    │ │                    │                          │   │
│ │ │ - Doctors    │ │       Event Flow   │   Security Layer:        │   │
│ │ │ - Patients   │ │    ┌────────────┐  │  ┌────────────────────┐ │   │
│ │ │ - Appts      │ │    │ Initiate   │  │  │ JWT Authentication │ │   │
│ │ │ - Profiles   │ │    └───┬────────┘  │  │ Rate Limiting      │ │   │
│ │ └──────────────┘ │        │           │  │ Input Validation   │ │   │
│ │                  │        ▼           │  │ CORS Protected     │ │   │
│ │ ┌──────────────┐ │   ┌────────────┐  │  │ Helmet.js Headers  │ │   │
│ │ │ Metrics APIs │ │   │ Answer     │  │  │ Error Handling     │ │   │
│ │ │ - Record     │ │   └───┬────────┘  │  └────────────────────┘ │   │
│ │ │ - Retrieve   │ │       │           │                          │   │
│ │ │ - Analytics  │ │       ▼           │                          │   │
│ │ │ - Stats      │ │   ┌────────────┐  │                          │   │
│ │ └──────────────┘ │   │ Connected  │  │   Logging & Monitoring:  │   │
│ │                  │   └───┬────────┘  │  ┌────────────────────┐ │   │
│ │ Middleware:      │       │           │  │ Winston Logger     │ │   │
│ │ • JWT Verify     │       ▼           │  │ Combined Logs      │ │   │
│ │ • Error Handler  │   ┌────────────┐  │  │ Error Logs         │ │   │
│ │ • Validation     │   │ Metrics    │  │  │ Performance Stats  │ │   │
│ │ • Rate Limiting  │   └────────────┘  │  └────────────────────┘ │   │
│ │                  │        │           │                          │   │
│ │ Utilities:       │        ▼           │                          │   │
│ │ • Logger         │   ┌────────────┐  │                          │   │
│ │ • Validation     │   │ End Call   │  │                          │   │
│ │ • Error Handler  │   └────────────┘  │                          │   │
│ └──────────────────┴────────────────────┴──────────────────────────┘   │
│                                                                          │
│                        Health Check: GET /health                        │
└──────────────────────────┬─────────────────────────────────────────────┘
                           │
                           │ P2P WebRTC
                           │ (STUN/TURN)
                           │
            ┌──────────────┴──────────────┐
            │                             │
            ▼                             ▼
    ┌──────────────┐            ┌──────────────┐
    │   Patient    │            │    Doctor    │
    │   Device     │            │    Device    │
    │              │            │              │
    │ Microphone   │◄──Audio────│ Microphone   │
    │ Camera       │◄──Video────│ Camera       │
    │ Speaker      │─Audio────►│ Speaker      │
    │ Display      │─Video────►│ Display      │
    └──────────────┘            └──────────────┘
         (Mobile)                   (Mobile/Desktop)
```

---

## 🔄 Call Flow Sequence Diagram

```
       Patient                    Server                    Doctor
         │                         │                         │
         │                         │                         │
    Login & Get Token              │                         │
         │──POST /auth/login      │                         │
         │────────────────────────│                         │
         │◄─────JWT Token─────────│                         │
         │                         │                         │
    Find Doctors & Book             │                         │
         │──GET /users/doctors    │                         │
         │────────────────────────│                         │
         │◄─────Doctor List───────│                         │
         │                         │                         │
         │──POST /appts/book      │                         │
         │────────────────────────│                         │
         │◄─────Confirmed─────────│                         │
         │                         │                         │
    At Appointment Time:            │                         │
         │                         │                         │
         │──POST /calls/initiate  │                         │
         │────────────────────────│                         │
         │                    🔔 call:incoming────────────►│
         │                         │◄─POST /calls/answer────│
         │                         │                         │
    Get WebSocket Connection        │                         │
         │                         │                         │
    socket.emit('call:initiate')   │                         │
         │────────────────────────│                         │
    Get Local Media Stream          │    socket connected    │
         │              ┌──────────────────────────┐        │
         │              │ User Sockets Registered │        │
         │              └──────────────────────────┘        │
         │                         │                         │
    WebSocket Connected  ◄─────────┴──────────────► WebSocket Connected
         │                         │                         │
    stream:local setup             │        stream:setup    │
         │                         │                         │
         │                         ◄────────── SDPoffer ─────│
         │◄─────────────── SDPanswer ──────────────│
         │                         │                         │
         │────────── ICEcandidates ───────────────►│
         │◄────────── ICEcandidates ───────────────│
         │                         │                         │
    stream:remote active           │      stream:remote active
         │                         │                         │
    ═════════════════════════════════════════════════════════
           P2P WebRTC Connection Established
    ═════════════════════════════════════════════════════════
         │◄──────────────AUDIO────────────────────►│
         │◄──────────────VIDEO────────────────────►│
         │                         │                         │
    Emit Quality Metrics           │                         │
         │─── emit('call:quality') ───────────────│
         │                         │                         │
    (Call continues with metrics  │   (Quality adapts)      │
         │ Send every 1 second)    │                         │
         │                         │                         │
    Doctor Ends Call               │                         │
         │                         │                         │
         │◄──────emit('call:ended')──────────────┤
         │                         │                         │
    Close Connections              │                         │
    Stop Streams                   │   Stop Streams          │
    Cleanup Resources              │   Cleanup Resources     │
         │                         │                         │
         │──POST /calls/end ──────│                         │
         │────────────────────────│                         │
         │◄────Saved to History───│                         │
         │                         │                         │
```

---

## 🎯 Network Adaptation Flow

```
    Network
    Monitoring
         │
         ▼
    ┌─────────────────────────────────────┐
    │  Detect Current Network Status      │
    │ • Type (WiFi/4G/5G/3G)              │
    │ • Bandwidth (Mbps)                  │
    │ • Latency (ms)                      │
    │ • Signal Strength (%)               │
    └────────────┬────────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────────┐
    │  Calculate Quality Score (0-100)    │
    │ • Resolution impact (-0 to -40)     │
    │ • Latency impact (-0 to -35)        │
    │ • Bandwidth impact (-0 to -30)      │
    │ • Packet loss impact (-0 to -25)    │
    └────────────┬────────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────────┐
    │  Select Optimal Video Settings      │
    │                                     │
    │  if bandwidth >= 3.5 Mbps:          │
    │    → 1080p @ 30 FPS (4500 kbps)    │
    │                                     │
    │  else if bandwidth >= 2.0 Mbps:     │
    │    → 720p @ 30 FPS (2500 kbps)     │
    │                                     │
    │  else if bandwidth >= 1.2 Mbps:     │
    │    → 480p @ 24 FPS (1200 kbps)     │
    │                                     │
    │  else if bandwidth >= 0.6 Mbps:     │
    │    → 360p @ 15 FPS (500 kbps)      │
    │                                     │
    │  else:                              │
    │    → 360p @ 15 FPS (250 kbps)      │
    │       Audio focus mode              │
    └────────────┬────────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────────┐
    │  Apply Settings to Call             │
    │ • Update encoder resolution         │
    │ • Adjust frame rate                 │
    │ • Modify bitrate limit              │
    │ • Notify remote peer                │
    └────────────┬────────────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────────┐
    │  Continue Monitoring                │
    │ • Every 1-2 seconds                 │
    │ • Detect network changes            │
    │ • Readjust if needed                │
    │ • Minimize interruption             │
    └─────────────────────────────────────┘
```

---

## 📱 Component Dependencies

```
Flutter App Dependencies:
├── Core
│   ├── provider (^6.0.0)
│   ├── dio (^5.3.1)
│   └── socket_io_client (^2.0.0)
├── Media
│   ├── camera (^0.10.5)
│   ├── flutter_webrtc (^0.9.43)
│   └── audio_session (^0.1.16)
├── Network
│   ├── connectivity_plus (^5.0.0)
│   └── network_info_plus (^4.0.0)
├── Storage
│   ├── shared_preferences (^2.2.0)
│   └── get_storage (^2.1.1)
└── UI
    ├── intl (^0.19.0)
    ├── uuid (^4.0.0)
    └── flutter_local_notifications (^16.1.0)

Backend Dependencies:
├── Server
│   ├── express (^4.18.2)
│   ├── socket.io (^4.6.1)
│   ├── cors (^2.8.5)
│   └── helmet (^7.1.0)
├── Database
│   ├── mongoose (^8.0.3)
│   ├── redis (^4.6.12)
│   └── multer (^1.4.5)
├── Auth & Security
│   ├── jsonwebtoken (^9.1.2)
│   ├── bcryptjs (^2.4.3)
│   └── express-rate-limit (^7.1.5)
├── Utilities
│   ├── dotenv (^16.3.1)
│   ├── morgan (^1.10.0)
│   ├── winston (^3.11.0)
│   └── validator (^13.11.0)
└── Processing
    ├── bull (^4.11.5)
    ├── sharp (^0.33.0)
    └── axios (^1.6.2)
```

---

## 🔐 Security Architecture

```
┌────────────────────────────────────────────────────────┐
│           Security Layers (Defense in Depth)           │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Layer 1: Network Layer                               │
│ ├─ HTTPS/TLS (encryption in transit)                 │
│ ├─ WSS (secure WebSocket)                            │
│ └─ DTLS-SRTP (media encryption optional)             │
│                                                        │
│ Layer 2: Application Layer                           │
│ ├─ CORS Protection (configured origin)               │
│ ├─ Rate Limiting (100 req/15min)                     │
│ ├─ Input Validation & Sanitization                   │
│ └─ Helmet.js Security Headers                        │
│                                                        │
│ Layer 3: Authentication & Authorization              │
│ ├─ JWT Tokens (stateless auth)                       │
│ ├─ Token Expiration (24h default)                    │
│ ├─ Role-Based Access Control (RBAC)                  │
│ └─ Secure Password Hashing (bcrypt)                  │
│                                                        │
│ Layer 4: Data Protection                             │
│ ├─ Encrypted Password Storage                        │
│ ├─ Audit Logging (Winston)                           │
│ ├─ Session Management                                │
│ └─ Secure Data Deletion                              │
│                                                        │
│ Layer 5: Healthcare Compliance                       │
│ ├─ HIPAA Compliance Framework                        │
│ ├─ Data Retention Policies                           │
│ ├─ Access Control Logs                               │
│ └─ Encryption at Rest (optional)                     │
│                                                        │
└────────────────────────────────────────────────────────┘

Authentication Flow:
  Credentials → Hash + Validate → JWT Token → Protected Routes
              ↓
    Stored in SharedPreferences → Auto-refresh → Secure Logout
```

---

## 📊 Database Schema (Optional)

```
Collections/Tables:
├── users
│   ├── userId (PK)
│   ├── email (UNIQUE)
│   ├── password (hashed)
│   ├── name
│   ├── role ('doctor' | 'patient')
│   ├── specialization (for doctors)
│   ├── rating
│   └── createdAt
│
├── calls
│   ├── callId (PK)
│   ├── initiatorId (FK)
│   ├── recipientId (FK)
│   ├── type ('audio' | 'video')
│   ├── status ('connected' | 'ended')
│   ├── startTime
│   ├── endTime
│   ├── duration (seconds)
│   ├── recordingUrl (optional)
│   ├── qualityMetrics (array)
│   └── notes (for prescriptions)
│
├── appointments
│   ├── appointmentId (PK)
│   ├── doctorId (FK)
│   ├── patientId (FK)
│   ├── slotTime
│   ├── reason
│   ├── status ('scheduled' | 'completed' | 'cancelled')
│   └── notes
│
├── metrics
│   ├── metricId (PK)
│   ├── callId (FK)
│   ├── timestamp
│   ├── bandwidth
│   ├── latency
│   ├── packetLoss
│   ├── qualityScore
│   └── videoResolution
│
└── prescriptions
    ├── prescriptionId (PK)
    ├── callId (FK)
    ├── doctorId (FK)
    ├── patientId (FK)
    ├── medications (array)
    ├── dosage
    ├── duration
    ├── instructions
    └── createdAt
```

---

## 🎯 Quality Scoring Algorithm

```
QualityScore = 100
            - ResolutionPenalty(0-40)
            - LatencyPenalty(0-35)
            - BandwidthPenalty(0-30)
            - PacketLossPenalty(0-25)

Penalties:
┌─────────────────┬────────────┬────────────┐
│ Factor          │ Penalty    │ Threshold  │
├─────────────────┼────────────┼────────────┤
│ 1080p           │ 0 pts      │            │
│ 720p            │ 5 pts      │            │
│ 480p            │ 15 pts     │            │
│ 360p            │ 25 pts     │            │
│                 │            │            │
│ Latency < 50ms  │ 0 pts      │            │
│ Latency 50-100ms│ 10 pts     │            │
│ Latency 100-200 │ 20 pts     │            │
│ Latency > 200ms │ 35 pts     │            │
│                 │            │            │
│ BW > 2 Mbps     │ 0 pts      │            │
│ BW 1-2 Mbps     │ 10 pts     │            │
│ BW 0.5-1 Mbps   │ 20 pts     │            │
│ BW < 0.5 Mbps   │ 30 pts     │            │
│                 │            │            │
│ Loss < 0.5%     │ 0 pts      │            │
│ Loss 0.5-2%     │ 10 pts     │            │
│ Loss 2-5%       │ 15 pts     │            │
│ Loss > 5%       │ 25 pts     │            │
└─────────────────┴────────────┴────────────┘

Final Score: 0-100
├─ 90-100: Excellent   ████████████████████
├─ 70-89:  Good        ████████████░░░░░░░░
├─ 50-69:  Fair        ██████████░░░░░░░░░░
├─ 20-49:  Poor        ███░░░░░░░░░░░░░░░░░
└─ 0-19:   Very Poor   ░░░░░░░░░░░░░░░░░░░░
```

---

## 🚀 Deployment Architecture

```
┌─────────────────────────────────────────────────────┐
│              Production Environment                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Client Layer                                      │
│  ├─ Mobile App (iOS/Android via App Store)        │
│  ├─ Web Client (PWA or Flutter Web)               │
│  └─ Desktop (Win/Mac/Linux)                        │
│                                                     │
│  ↓ HTTPS + JWT                                     │
│                                                     │
│  CDN Layer (CloudFlare/CloudFront)                 │
│  ├─ Static content caching                         │
│  ├─ DDoS protection                               │
│  └─ Geographic optimization                        │
│                                                     │
│  ↓ HTTPS/WSS                                       │
│                                                     │
│  Load Balancer (ALB/NLB)                           │
│  ├─ HTTPS termination                             │
│  ├─ WebSocket support                             │
│  └─ Auto-scaling                                   │
│                                                     │
│  ↓                                                 │
│                                                     │
│  API Server Cluster                                │
│  ├─ Node.js Instance 1                            │
│  ├─ Node.js Instance 2                            │
│  ├─ Node.js Instance N                            │
│  └─ Health checks & Auto-recovery                  │
│                                                     │
│  ↓                                                 │
│                                                     │
│  Data Layer                                        │
│  ├─ MongoDB (Primary + Replica Sets)              │
│  ├─ Redis Cache Cluster                           │
│  ├─ S3/Cloud Storage (Recordings)                 │
│  └─ Backup (Daily, Encrypted)                      │
│                                                     │
│  ↓                                                 │
│                                                     │
│  WebRTC Infrastructure                             │
│  ├─ STUN Servers (Google, others)                 │
│  ├─ TURN Server (if needed)                       │
│  └─ Media Relay (optional)                         │
│                                                     │
│  Monitoring & Logging                              │
│  ├─ Application Monitoring (New Relic/DataDog)    │
│  ├─ Error Tracking (Sentry)                       │
│  ├─ Log Aggregation (ELK Stack)                   │
│  └─ Metrics (Prometheus/Grafana)                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

**This comprehensive system provides enterprise-grade telemedicine video conferencing with intelligent adaptation to network conditions.** 🏥❤️
