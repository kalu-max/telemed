# Telemedicine Platform - Complete Setup Guide

## Overview
This project consists of:
- **Backend**: Node.js/Express server (telemedicine_backend)
- **Patient App**: Flutter application (telemedicine_app)
- **Doctor App**: Flutter application (telemedicine_app/doctor_app)

Both Flutter apps connect to the same backend via HTTP and WebSocket for seamless teleconsultation.

---

## Setup Instructions

### 1. Start the Backend Server

Open a terminal and navigate to the backend directory:

```bash
cd telemedicine_backend
npm install      # First time only
npm start        # Starts server on http://localhost:3000
```

The backend will be listening on `http://localhost:3000` by default. Check `.env` for port configuration.

---

### 2. Run the Patient App

Open a new terminal:

```bash
cd telemedicine_app
flutter pub get
flutter run -d chrome   # Opens in browser; use -d edge, or emulator/device
```

**Alternative**: Build as web:
```bash
flutter build web
# Serve the build/web folder with any web server
```

---

### 3. Run the Doctor App

Open another terminal:

```bash
cd telemedicine_app/doctor_app
flutter pub get
flutter run -d chrome   # Opens in browser
```

---

## Testing the System

### Scenario 1: Two Browser Tabs (Patient + Doctor Web)

1. **Start backend**: `npm start` in `telemedicine_backend`
2. **Tab 1 (Patient)**: Run patient app with `flutter run -d chrome`
3. **Tab 2 (Doctor)**: Run doctor app with `flutter run -d chrome` (or second VS Code instance)

### Scenario 2: Mobile + Browser

1. **Start backend**: Same as above
2. **Browser (Doctor)**: Run doctor app as web
3. **Device/Emulator (Patient)**: Run patient app on Android/iOS device or emulator

### Scenario 3: Two Mobile Devices

1. **Start backend**: Same as above
2. **Device 1 (Patient)**: Connect to backend IP, log in as patient
3. **Device 2 (Doctor)**: Connect to backend IP, log in as doctor

---

## Key Features

### Patient App
- User authentication (email/password)
- View available doctors
- Book/manage appointments
- Initiate video consultations
- Adaptive video quality (low bandwidth support)
- View medical reports

### Doctor App
- Doctor authentication
- Dashboard with appointments list
- Accept/decline consultations
- Video call with patients
- View patient details & history
- Manage schedule

### Backend
- RESTful API for user, appointment, and call management
- WebSocket for real-time signaling
- WebRTC video/audio conferencing
- JWT authentication
- Stateless, scalable architecture

---

## Configuration

### Backend (.env file)
Create `telemedicine_backend/.env` with:
```
PORT=3000
NODE_ENV=development
JWT_SECRET=your_secret_key
MONGODB_URI=mongodb://localhost:27017/telemedicine
TURN_URLS=your_turn_server_url
```

### Flutter Apps
API endpoint is configured in the code (default: `http://localhost:3000`)

---

## Troubleshooting

### "Connection refused" error
- Ensure backend is running: `npm start` in `telemedicine_backend`
- Check that port 3000 is not in use

### CORS errors
- Backend has CORS enabled by default
- Check `server.js` for CORS configuration

### Video not working
- Ensure cameras/microphones are permitted
- Check console for WebRTC errors
- Verify STUN/TURN server configuration

### Flutter build issues
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

---

## Project Structure

```
telemedicine_backend/
├── server.js          # Main server entry
├── server/
│   ├── api/           # REST endpoints
│   ├── middleware/    # Auth, error handling
│   ├── websocket/     # WebRTC signaling
│   └── utils/         # Helpers, logging
└── public/
    └── doctor-portal.html  # Legacy web UI (optional)

telemedicine_app/
├── lib/
│   ├── main.dart      # Patient app entry
│   ├── paitent/       # Patient screens
│   └── services/      # API, WebRTC
└── doctor_app/        # Doctor app (separate)
    ├── lib/
    │   └── main.dart  # Doctor app entry
    └── pubspec.yaml
```

---

## Next Steps

1. **Backend**: Configure database (MongoDB), TURN servers, HTTPS/TLS
2. **Patient App**: Implement report uploading, appointment history filtering
3. **Doctor App**: Add schedule management, patient history view
4. **Both**: Implement offline mode, push notifications, call history

---

For detailed API documentation, see `INTEGRATION_GUIDE.md` and `SYSTEM_ARCHITECTURE.md` in the root.
