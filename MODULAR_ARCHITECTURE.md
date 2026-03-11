# Modular Architecture Guide - Telemedicine Platform

## Overview
This document outlines the modular structure for the telemedicine application, ensuring clean separation of concerns, reusability, and scalability.

---

## 🏗️ **Backend Architecture** (`telemedicine_backend/`)

### Directory Structure
```
telemedicine_backend/
├── server.js                        # Main server entry point
├── package.json                     # Dependencies
├── .env.example                     # Environment variables template
├── server/
│   ├── api/                        # REST API routes (Modular Controllers)
│   │   ├── auth.js                # Authentication endpoints
│   │   │   - POST /api/auth/register
│   │   │   - POST /api/auth/login
│   │   │   - POST /api/auth/refresh
│   │   │   - POST /api/auth/logout
│   │   ├── callManagement.js       # Call management endpoints
│   │   │   - POST /api/calls/initiate
│   │   │   - POST /api/calls/answer
│   │   │   - POST /api/calls/reject
│   │   │   - POST /api/calls/end
│   │   │   - GET /api/calls/history
│   │   │   - POST /api/calls/{id}/metrics
│   │   ├── users.js                # User management endpoints
│   │   │   - GET /api/users/doctors/available
│   │   │   - GET /api/users/doctors/{id}
│   │   │   - POST /api/users/appointments/book
│   │   │   - GET /api/users/appointments
│   │   ├── metrics.js              # Metrics & analytics endpoints
│   │   │   - GET /api/metrics/call/{id}
│   │   │   - GET /api/metrics/user/stats
│   │   │   - GET /api/metrics/network/performance
│   │   └── videoSignaling.js       # WebRTC signaling events (old location)
│   │
│   ├── websocket/                  # WebSocket/Socket.io (Real-time signaling)
│   │   ├── videoSignaling.js       # WebRTC peer-to-peer signaling
│   │   │   - Event: registerPeer
│   │   │   - Event: call:initiate
│   │   │   - Event: call:answer
│   │   │   - Event: call:reject
│   │   │   - Event: ice:candidate
│   │   │   - Event: sdp:offer
│   │   │   - Event: sdp:answer
│   │   │   - Event: call:quality
│   │   ├── roomManager.js          # Room & peer management (recommended)
│   │   └── eventHandlers.js        # Centralized event handlers (recommended)
│   │
│   ├── middleware/                 # Express middleware (Cross-cutting concerns)
│   │   ├── auth.js                # JWT authentication & authorization
│   │   │   - verifyToken()
│   │   │   - verifyRole()
│   │   └── errorHandler.js         # Global error handling
│   │       - errorHandler middleware
│   │       - asyncHandler wrapper
│   │
│   ├── models/                     # Database models (recommended)
│   │   ├── User.js
│   │   ├── Doctor.js
│   │   ├── Call.js
│   │   ├── Appointment.js
│   │   └── Metrics.js
│   │
│   ├── database/                   # Database configuration (recommended)
│   │   ├── mongo.js               # MongoDB connection
│   │   └── seed.js                # Sample data seeding
│   │
│   ├── utils/                      # Utility functions
│   │   ├── logger.js              # Winston logging
│   │   ├── validators.js          # Input validation (recommended)
│   │   ├── formatters.js          # Data formatting (recommended)
│   │   └── helpers.js             # Helper functions
│   │
│   ├── constants/                  # Constants (recommended)
│   │   ├── roles.js               # User roles
│   │   ├── statusCodes.js         # API status codes
│   │   └── messages.js            # Response messages
│   │
│   └── config/                     # Configuration files (recommended)
│       ├── database.js            # DB config
│       ├── socket.js              # Socket.io config
│       └── jwt.js                 # JWT secrets & options
```

---

## 📱 **Frontend Architecture** (`telemedicine_app/lib/`)

### Directory Structure
```
telemedicine_app/lib/
│
├── main.dart                        # App entry point
│
├── config/                          # App configuration
│   ├── app_config.dart            # API endpoints, constants
│   ├── theme_config.dart          # Colors, typography, themes
│   └── routes.dart                # Route configuration
│
├── constants/                       # Application constants
│   ├── app_constants.dart         # App-wide constants
│   ├── error_messages.dart        # Error & success messages
│   ├── api_endpoints.dart         # API endpoint constants
│   └── asset_paths.dart           # Image, font paths
│
├── models/                          # Data models
│   ├── user_model.dart            # User data model
│   ├── doctor_model.dart          # Doctor data model
│   ├── call_model.dart            # Call session model
│   ├── appointment_model.dart     # Appointment model
│   ├── metrics_model.dart         # Network & call metrics
│   └── network_info_model.dart    # Network information
│
├── services/                        # Business logic & API calls
│   ├── api/
│   │   ├── api_client.dart        # HTTP client (Dio-based)
│   │   ├── auth_api.dart          # Authentication API calls
│   │   ├── call_api.dart          # Call management API
│   │   ├── user_api.dart          # User API calls
│   │   └── metrics_api.dart       # Metrics API calls
│   │
│   ├── video/
│   │   ├── enhanced_video_service.dart    # WebRTC call management
│   │   ├── webrtc_manager.dart            # WebRTC peer management (recommended)
│   │   ├── signaling_service.dart         # Socket.io signaling (recommended)
│   │   └── video_config.dart              # Video settings (recommended)
│   │
│   ├── network/
│   │   ├── realtime_network_controller.dart  # Network monitoring
│   │   ├── connectivity_service.dart         # Connectivity checks (recommended)
│   │   └── network_utils.dart                # Network utilities (recommended)
│   │
│   ├── storage/
│   │   ├── local_storage_service.dart   # SharedPreferences wrapper
│   │   ├── token_storage.dart           # Auth token storage (recommended)
│   │   └── cache_service.dart           # Data caching (recommended)
│   │
│   └── audio/
│       ├── audio_service.dart           # Audio handling (recommended)
│       └── notification_service.dart    # Push notifications (recommended)
│
├── providers/                       # State Management (Provider pattern)
│   ├── auth_provider.dart          # Authentication state
│   ├── user_provider.dart          # User data state
│   ├── call_provider.dart          # Call session state
│   ├── network_provider.dart       # Network state
│   └── ui_provider.dart            # UI state (theme, navigation)
│
├── screens/                         # UI Screens
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── splash_screen.dart
│   │
│   ├── patient/
│   │   ├── patient_dashboard.dart
│   │   ├── find_specialist_screen.dart
│   │   ├── appointments_screen.dart
│   │   ├── prescription_screen.dart
│   │   └── profile_screen.dart
│   │
│   ├── doctor/
│   │   ├── doctor_dashboard.dart
│   │   ├── doctor_appointments_screen.dart
│   │   └── doctor_profile_screen.dart
│   │
│   └── call/
│       ├── video_call_screen.dart
│       ├── active_consultation_screen.dart
│       └── call_history_screen.dart
│
├── widgets/                         # Reusable UI components
│   ├── common/
│   │   ├── custom_button.dart
│   │   ├── custom_text_field.dart
│   │   ├── loading_widget.dart
│   │   ├── error_widget.dart
│   │   └── custom_app_bar.dart
│   │
│   ├── video/
│   │   ├── video_preview.dart
│   │   ├── remote_video_widget.dart
│   │   ├── call_controls.dart
│   │   └── network_quality_indicator.dart
│   │
│   └── cards/
│       ├── doctor_card.dart
│       ├── appointment_card.dart
│       └── metric_card.dart
│
├── utils/                           # Utility functions
│   ├── validators.dart             # Input validation
│   ├── formatters.dart             # Date/time formatters
│   ├── logger.dart                 # Logging utility
│   ├── dialog_utils.dart           # Dialog helper functions
│   └── extensions.dart             # Dart extensions
│
└── paitent/                         # Legacy code (To be refactored)
    └── [Existing files for backward compatibility]
```

---

## 🔄 **Data Flow Architecture**

### Request/Response Flow
```
User Interaction (UI)
        ↓
    Provider (State Management)
        ↓
    Service Layer (Business Logic)
        ↓
    API Client (HTTP/WebSocket)
        ↓
    Backend (Express.js)
        ↓
    API Route Handler
        ↓
    Middleware (Auth, Validation, Error Handling)
        ↓
    Database/Cache
        ↓
    Response (JSON)
        ↓
    Back to UI
```

### Real-time Communication Flow (Video Calls)
```
Client 1 (Flutter)
        ↓
    WebRTC Service
        ↓
    Socket.io Client
        ↓
    Signaling Server (Node.js)
        ↓
    Socket.io Server
        ↓
    WebRTC Handler
        ↓
    Client 2 (Flutter)
        ↓
    Direct P2P Connection (Media Streams)
```

---

## 📋 **Module Dependencies**

### Backend Module Dependencies
```
Express App
├── Middleware Layer
│   ├── Authentication (JWT)
│   ├── Authorization (Roles)
│   ├── Error Handling
│   └── CORS & Security
├── API Routes
│   ├── Auth Module
│   │   └── Depends on: Utils (Logger), Middleware
│   ├── Call Management
│   │   └── Depends on: DB Models, Utils
│   ├── User Management
│   │   └── Depends on: DB Models, Utils
│   └── Metrics
│       └── Depends on: DB Models, Utils
├── WebSocket Layer (Socket.io)
│   ├── Video Signaling
│   │   └── Depends on: Room Manager, Event Handlers
│   └── Connection Management
└── Utilities
    ├── Logger
    ├── Validators
    └── Helpers
```

### Frontend Module Dependencies
```
Main App
├── Config Layer
│   ├── App Config
│   ├── Theme Config
│   └── Routes
├── Provider Layer
│   ├── Auth Provider
│   ├── User Provider
│   ├── Call Provider
│   ├── Network Provider
│   └── UI Provider
├── Service Layer
│   ├── API Services
│   │   ├── Auth API
│   │   ├── Call API
│   │   ├── User API
│   │   └── Metrics API
│   ├── Video Services
│   │   ├── WebRTC Manager
│   │   └── Signaling Service
│   ├── Network Services
│   │   └── Connectivity Service
│   └── Storage Services
│       ├── Local Storage
│       └── Token Storage
├── Screen Layer
│   ├── Auth Screens
│   ├── Patient Screens
│   ├── Doctor Screens
│   └── Call Screens
└── Widget Layer
    ├── Common Widgets
    ├── Video Widgets
    └── Card Widgets
```

---

## ✨ **Implementation Guidelines**

### Backend Best Practices
1. **Separation of Concerns**: Each module handles one responsibility
2. **Error Handling**: Centralized error handling middleware
3. **Logging**: All operations logged with Winston
4. **Validation**: Input validation at API entry points
5. **Security**: JWT for auth, rate limiting, CORS configuration
6. **Documentation**: API documentation with examples

### Frontend Best Practices
1. **State Management**: Provider pattern for consistent state
2. **Layered Architecture**: Services → Providers → Screens → Widgets
3. **Reusability**: Common widgets extracted to `widgets/`
4. **Constants**: Magic strings/numbers defined in `constants/`
5. **Error Handling**: Consistent error dialogs and messages
6. **Performance**: Lazy loading, caching, efficient rebuilds

---

## 🚀 **Setup Instructions**

### Backend Setup
```bash
# Navigate to backend
cd telemedicine_backend

# Install dependencies
npm install

# Create .env file from example
cp .env.example .env

# Update .env with your configuration
# Start server
npm start
```

### Frontend Setup
```bash
# Navigate to frontend
cd telemedicine_app

# Install dependencies
flutter pub get

# Run on web/mobile
flutter run
```

---

## 📦 **Adding New Features (Modular Approach)**

### Example: Adding a New API Endpoint

1. **Backend**:
   ```
   server/api/newFeature.js → Create endpoint
   server/middleware/ → Add validation if needed
   server/models/ → Create data model
   server/utils/ → Add helper functions
   ```

2. **Frontend**:
   ```
   lib/services/api/new_feature_api.dart → Create API calls
   lib/providers/new_feature_provider.dart → Create state management
   lib/screens/new_feature_screen.dart → Create UI
   lib/widgets/ → Add reusable components
   ```

---

## 🎯 **Current Status**

✅ **Backend**: Fully modular with API routes, middleware, and WebSocket
✅ **Frontend**: Services created, beginning modular reorganization
📋 **Next Steps**: Reorganize frontend into clean modular structure

---

## 📞 **Support**

For more information on each module, refer to inline code comments and individual README files within each section.
