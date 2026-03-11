# Telemedicine Platform - Complete Setup & Deployment Guide

## Table of Contents
1. [Backend Setup](#backend-setup)
2. [Flutter App Setup](#flutter-app-setup)
3. [Local Development](#local-development)
4. [Production Deployment](#production-deployment)
5. [Testing & Validation](#testing--validation)
6. [Troubleshooting](#troubleshooting)

---

## Backend Setup

### Prerequisites
- **Node.js**: v16.x or higher
- **npm**: v8.x or higher
- **git**: Latest version
- **curl** or **Postman**: For API testing

### Step 1: Clone & Install Dependencies

```bash
cd telemedicine_backend
npm install
```

### Step 2: Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` with your settings:

**Minimum Configuration (Development)**:
```env
NODE_ENV=development
PORT=5000
JWT_SECRET=dev-secret-key-change-in-production
FRONTEND_URL=http://localhost:3000
```

**Recommended Configuration**:
```env
NODE_ENV=development
PORT=5000
LOG_LEVEL=debug
JWT_SECRET=dev-secret-key-min-32-characters-long
FRONTEND_URL=http://localhost:3000
ENABLE_CALL_RECORDING=true
ENABLE_SCREEN_SHARING=true
DEFAULT_VIDEO_RESOLUTION=720p
MIN_BANDWIDTH_MOBILE=0.5
MIN_BANDWIDTH_WIFI=1.0
```

### Step 3: Create Logs Directory

```bash
mkdir -p logs
```

### Step 4: Start Development Server

```bash
npm run dev
```

Expected output:
```
🎥 Telemedicine Video Backend running on port 5000
📡 WebRTC Signaling Server active
🔒 CORS enabled for http://localhost:3000
```

### Step 5: Verify Server

```bash
curl http://localhost:5000/health
```

Response:
```json
{
  "status": "OK",
  "timestamp": "2024-02-27T10:30:00.000Z",
  "uptime": 5.432
}
```

---

## Flutter App Setup

### Prerequisites
- **Flutter**: v3.10.x or higher
- **Dart**: v3.10.x or higher
- **Android SDK**: API 21+ (for Android development)
- **Xcode**: v14+ (for iOS development)
- **Git**

### Step 1: Verify Flutter Installation

```bash
flutter --version
dart --version
```

### Step 2: Install Dependencies

```bash
cd telemedicine_app
flutter clean
flutter pub get
```

### Step 3: Configure Backend URL

Create `lib/config/constants.dart`:

```dart
class ApiConstants {
  static const String baseUrl = 'http://localhost:5000';
  static const String wsUrl = 'ws://localhost:5000';
  static const String apiTimeout = Duration(seconds: 30);
}
```

Update `api_client.dart`:

```dart
TeleMedicineApiClient(ApiConstants.baseUrl);
```

### Step 4: Update main.dart

Replace the initialization in `main.dart`:

```dart
import 'package:provider/provider.dart';
import 'paitent/enhanced_video_service.dart';
import 'paitent/realtime_network_controller.dart';
import 'paitent/adaptive_bitrate_controller.dart';
import 'paitent/api_client.dart';
import 'config/constants.dart';

void main() {
  runApp(const MediCareApp());
}

class MediCareApp extends StatelessWidget {
  const MediCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RealTimeNetworkController(),
        ),
        ChangeNotifierProxyProvider<RealTimeNetworkController, AdaptiveBitrateController>(
          create: (context) => AdaptiveBitrateController(
            networkController: context.read<RealTimeNetworkController>(),
          ),
          update: (context, networkController, previous) =>
              previous ?? AdaptiveBitrateController(networkController: networkController),
        ),
        ChangeNotifierProxyProvider2<RealTimeNetworkController, AdaptiveBitrateController, EnhancedVideoCallService>(
          create: (_) => EnhancedVideoCallService(
            networkController: _.read<RealTimeNetworkController>(),
            bitrateController: _.read<AdaptiveBitrateController>(),
            serverUrl: ApiConstants.baseUrl,
            authToken: 'temp-token', // Set after login
          ),
          update: (_, networkController, bitrateController, previous) =>
              previous ?? EnhancedVideoCallService(
                networkController: networkController,
                bitrateController: bitrateController,
                serverUrl: ApiConstants.baseUrl,
                authToken: 'temp-token',
              ),
        ),
        Provider(
          create: (_) => TeleMedicineApiClient(ApiConstants.baseUrl),
        ),
      ],
      child: MaterialApp(
        title: 'MediCare Connect',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const LoginScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      primaryColor: Colors.teal[700],
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        primary: Colors.teal[700]!,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
    );
  }
}
```

### Step 5: Run on Device/Emulator

**Android**:
```bash
flutter pub get
flutter run -d android
```

**iOS**:
```bash
cd ios
pod install
cd ..
flutter run -d ios
```

**Web** (Chrome):
```bash
flutter run -d chrome
```

---

## Local Development

### Full Stack Development Setup

**Terminal 1: Backend**
```bash
cd telemedicine_backend
npm run dev
```

**Terminal 2: Flutter App**
```bash
cd telemedicine_app
flutter run
```

### Testing Workflow

1. **Register a User** (Backend):
   ```bash
   curl -X POST http://localhost:5000/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{
       "email": "doctor@test.com",
       "password": "password123",
       "name": "Dr. John",
       "role": "doctor",
       "specialization": "Cardiology"
     }'
   ```

2. **Login User**:
   ```bash
   curl -X POST http://localhost:5000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{
       "email": "doctor@test.com",
       "password": "password123"
     }'
   ```

   Copy the returned token.

3. **Get Available Doctors**:
   ```bash
   curl -X GET "http://localhost:5000/api/users/doctors/available?specialization=Cardiology" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

4. **Test WebSocket Connection**:
   Use Socket.io test client or WebSocket tool to test `/video` namespace.

### Recommended Development Tools

- **Postman** - API testing
- **Chrome DevTools** - Debug Flutter Web
- **VS Code Extensions**:
  - Dart
  - Flutter
  - Thunder Client (REST testing)
  - WebSocket King (WebSocket testing)

---

## Production Deployment

### Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Environment variables configured
- [ ] HTTPS/TLS certificates obtained
- [ ] Database migrations completed
- [ ] Redis configured (if using)
- [ ] Email service configured
- [ ] Cloud storage configured (for recordings)
- [ ] Monitoring setup complete
- [ ] Backups configured

### Docker Deployment

**Create Dockerfile**:

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application
COPY . .

# Create logs directory
RUN mkdir -p logs

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD npm run healthcheck

# Start application
CMD ["npm", "start"]
```

**Build and Run**:

```bash
# Build
docker build -t telemedicine-backend:1.0.0 .

# Run
docker run -d \
  --name telemedicine-backend \
  -p 5000:5000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=your-production-secret \
  -e MONGODB_URI=mongodb://... \
  telemedicine-backend:1.0.0
```

### AWS Deployment (Elastic Beanstalk)

```bash
# Install EB CLI
pip install awsebcli --upgrade --user

# Initialize
eb init -p node.js-18 telemedicine-backend

# Create environment
eb create telemedicine-prod

# Deploy
eb deploy
```

### Heroku Deployment

```bash
# Login
heroku login

# Create app
heroku create telemedicine-backend

# Set environment variables
heroku config:set NODE_ENV=production
heroku config:set JWT_SECRET=your-production-secret

# Deploy
git push heroku main

# View logs
heroku logs --tail
```

### Kubernetes Deployment

See `k8s/deployment.yaml` for Kubernetes manifest.

```bash
# Deploy
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check status
kubectl get pods
kubectl get svc
```

---

## Testing & Validation

### Backend Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test
npm test -- auth.test.js
```

### API Integration Test

**Test Script** (`tests/integration.js`):

```javascript
const axios = require('axios');
const BASE_URL = 'http://localhost:5000';

async function testIntegration() {
  try {
    // Test health
    const health = await axios.get(`${BASE_URL}/health`);
    console.log('✓ Health check:', health.data);

    // Register user
    const register = await axios.post(`${BASE_URL}/api/auth/register`, {
      email: 'test@example.com',
      password: 'test123',
      name: 'Test User',
      role: 'patient'
    });
    console.log('✓ Registration:', register.data);

    // Login
    const login = await axios.post(`${BASE_URL}/api/auth/login`, {
      email: 'test@example.com',
      password: 'test123'
    });
    const token = login.data.token;
    console.log('✓ Login successful, token:', token.substring(0, 20) + '...');

    // Get doctors
    const doctors = await axios.get(`${BASE_URL}/api/users/doctors/available`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✓ Available doctors:', doctors.data.count);

  } catch (error) {
    console.error('✗ Test failed:', error.response?.data || error.message);
  }
}

testIntegration();
```

Run:
```bash
node tests/integration.js
```

### Mobile App Testing

1. **Login Flow**:
   - Register new account
   - Login with credentials
   - Verify token persistence
   - Test logout

2. **Network Monitoring**:
   - Switch between WiFi and cellular
   - Verify quality changes
   - Check adaptive bitrate adjustments

3. **Video Call**:
   - Initiate call
   - Accept/Reject call
   - Monitor call metrics
   - End call gracefully

4. **Stress Testing**:
   - Multiple concurrent calls
   - Long duration calls (30+ minutes)
   - Network switching during call

---

## Troubleshooting

### Backend Issues

**Issue**: Port 5000 already in use
```bash
# Find process using port
lsof -i :5000

# Kill process
kill -9 <PID>
```

**Issue**: JWT errors
- Verify JWT_SECRET is set in .env
- Check token expiration
- Ensure auth header format: `Authorization: Bearer <token>`

**Issue**: WebSocket connection fails
- Check CORS settings
- Verify frontend URL in .env
- Check firewall/proxy settings

**Issue**: Database connection errors
- Verify MongoDB URI in .env
- Check network access in MongoDB Atlas
- Verify credentials

### Flutter App Issues

**Issue**: "Cannot connect to backend"
- Check backend is running: `curl http://localhost:5000/health`
- Update API_BASE_URL to correct IP (not localhost for devices)
- Check firewall allows port 5000

**Issue**: "Camera permission denied"
```bash
# Android
adb shell pm grant com.example.telemedicine_app android.permission.CAMERA

# iOS
Settings > Privacy > Camera > Enable app
```

**Issue**: WebRTC connection fails
- Check STUN servers are accessible
- Verify network connectivity
- Check browser WebRTC support (caniuse.com)

### Network Monitoring Issues

**Issue**: Network quality not updating
- Check `connectivity_plus` plugin initialized
- Verify permissions granted (Location, Network State)
- Check for errors in logs

**Issue**: High latency detected incorrectly
- Calibrate latency measurement
- Check system clock sync
- Verify network path to STUN servers

### General Issues

**Issue**: High CPU usage
- Check if background timers running
- Verify media stream cleanup
- Profile with DevTools

**Issue**: Memory leaks
- Ensure all listeners disposed
- Check Timer cancellation
- Verify stream cleanup

**Issue**: Audio/Video not syncing
- Update Flutter WebRTC to latest
- Check codec compatibility
- Verify frame rate settings

---

## Performance Optimization

### Backend Optimization

1. **Enable Redis Caching**:
   ```env
   REDIS_URL=redis://localhost:6379
   ```

2. **Enable gzip Compression**:
   ```javascript
   const compression = require('compression');
   app.use(compression());
   ```

3. **Connection Pooling**:
   ```javascript
   mongoose.connect(mongoUri, {
     maxPoolSize: 10,
     minPoolSize: 5
   });
   ```

### Mobile App Optimization

1. **Reduce Frame Rate for Low Bandwidth**:
   ```dart
   if (bandwidth < 1.0) {
     frameRate = 15; // Instead of 30
   }
   ```

2. **Enable Hardware Acceleration**:
   ```yaml
   # android/app/build.gradle
   android {
     buildTypes {
       release {
         signingConfig signingConfigs.release
       }
     }
   }
   ```

3. **Lazy Load Screens**:
   ```dart
   // Use PageView with lazy loading
   PageView.builder()
   ```

---

## Monitoring & Logs

### View Backend Logs

```bash
# Real-time logs
tail -f logs/combined.log

# Error logs only
tail -f logs/error.log

# Search logs
grep "ERROR" logs/combined.log
grep "callId" logs/combined.log
```

### Set Up Monitoring

Tools:
- **PM2**: Process manager for Node.js
- **New Relic**: Application performance monitoring
- **Sentry**: Error tracking
- **ELK Stack**: Log aggregation (Elasticsearch, Logstash, Kibana)

---

## Security Hardening

### Production Checklist

```bash
# Update packages
npm audit fix
npm update

# Enable HTTPS
# - Obtain SSL certificate (Let's Encrypt)
# - Configure in Node.js or reverse proxy (Nginx)

# Set secure headers
# - Already enabled via helmet.js
# - Customize in errorHandler.js

# Configure CORS properly
CORS_ORIGIN=https://yourdomain.com

# Use strong JWT secret
JWT_SECRET=$(openssl rand -base64 32)

# Enable call encryption
ENABLE_CALL_ENCRYPTION=true

# Set secure environment
NODE_ENV=production
```

---

**Congratulations!** Your telemedicine platform is now deployed and ready for production use.

For more help, check the main [README.md](./README.md) or contact support.
