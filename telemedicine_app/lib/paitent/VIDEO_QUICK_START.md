# Video Conferencing Integration - Quick Start Checklist

## Overview
Your telemedicine app now has a complete architecture for low-bandwidth, high-resolution video conferencing with adaptive quality based on network conditions. This checklist will guide you through the final integration steps.

## Files Created
- ✅ `network_controller.dart` - Network monitoring and quality classification
- ✅ `adaptive_bitrate_controller.dart` - Quality adaptation based on bandwidth  
- ✅ `video_call_service.dart` - Call state management
- ✅ `video_call_screen.dart` - Basic video call UI
- ✅ `webrtc_peer_connection.dart` - WebRTC peer connection implementation
- ✅ `integrated_video_call_screen.dart` - Complete integration example
- ✅ `VIDEO_IMPLEMENTATION_GUIDE.md` - Comprehensive implementation guide
- ✅ This checklist file

## Phase 1: Dependencies Setup
- [ ] Open `pubspec.yaml`
- [ ] Add these dependencies:
```yaml
dependencies:
  flutter:
    sdk: flutter
  connectivity_plus: ^5.0.0        # Network detection
  flutter_webrtc: ^0.9.0           # WebRTC for video conferencing
  provider: ^6.0.0                 # State management
  web_socket_channel: ^2.4.0       # WebSocket for signaling
```
- [ ] Run `flutter pub get`
- [ ] Confirm no errors in the pub output

## Phase 2: Update Main App
- [ ] Wrap your MaterialApp with MultiProvider in `main.dart`:
```dart
void main() {
  runApp(const MediCareApp());
}

class MediCareApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MultiNetworkController>(
          create: (_) => MultiNetworkController(),
        ),
        ChangeNotifierProxyProvider<MultiNetworkController, AdaptiveBitrateController>(
          create: (context) => AdaptiveBitrateController(
            networkController: context.read<MultiNetworkController>(),
          ),
          update: (context, networkCtrl, previous) {
            previous?.dispose();
            return AdaptiveBitrateController(
              networkController: networkCtrl,
            );
          },
        ),
      ],
      child: MaterialApp(
        title: 'MediCare Telemedicine',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const LoginScreen(),
      ),
    );
  }
}
```

## Phase 3: Update Dashboard
- [ ] Add import to `paitentdashboard.dart`:
```dart
import 'integrated_video_call_screen.dart';
```

- [ ] Add a "Start Video Call" button in `_buildActionsSection()` or similar:
```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntegratedVideoCallScreen(
          remoteUserId: 'doctor-123', // Get from API in real app
          remoteUserName: 'Dr. James Wilson',
          remoteUserAvatar: 'https://example.com/avatar.jpg',
          userProfile: widget.userProfile,
        ),
      ),
    );
  },
  icon: const Icon(Icons.videocam),
  label: const Text('Start Video Call'),
)
```

## Phase 4: Setup Backend (WebSocket Signaling)
You'll need a backend server that handles:

### API Endpoints Needed:
1. **GET /api/doctors** - List available doctors
2. **POST /api/calls** - Initiate a call
3. **GET /api/calls/{callId}** - Get call status
4. **PUT /api/calls/{callId}/status** - Update call status (connect/end)
5. **WebSocket /ws/signaling** - Real-time signaling for SDP/ICE exchange

### Basic WebSocket Server Example (Node.js/Express):
```javascript
const WebSocket = require('ws');
const express = require('express');
const app = express();

const wss = new WebSocket.Server({ port: 8080 });
const clients = new Map();

wss.on('connection', (ws) => {
  let userId = null;

  ws.on('message', (message) => {
    const data = JSON.parse(message);
    
    if (data.type === 'register') {
      userId = data.userId;
      clients.set(userId, ws);
      console.log(`User ${userId} registered`);
    } 
    else if (data.type === 'offer' || data.type === 'answer' || data.type === 'ice-candidate') {
      // Forward to remote peer
      const remotePeer = clients.get(data.to);
      if (remotePeer && remotePeer.readyState === WebSocket.OPEN) {
        remotePeer.send(JSON.stringify(data));
      }
    }
  });

  ws.on('close', () => {
    if (userId) {
      clients.delete(userId);
      console.log(`User ${userId} disconnected`);
    }
  });
});

app.listen(3000, () => {
  console.log('Signaling server running on port 3000');
});
```

### STUN/TURN Server Configuration:
For production, set up proper STUN/TURN servers:
- **STUN** (free): `stun.l.google.com:19302`
- **TURN** (commercial):
  - Twilio TURN: https://www.twilio.com/docs/stun-turn
  - Agora: https://www.agora.io/
  - AWS AppRTC: https://WebRTC.ventures/

## Phase 5: Handle Permissions
Update your `AndroidManifest.xml` and `Info.plist`:

### Android (android/app/src/main/AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS (ios/Runner/Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for video calls</string>
```

### Request permissions at runtime:
```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  await Permission.camera.request();
  await Permission.microphone.request();
}
```

## Phase 6: Test Basic Flow
- [ ] Run the app: `flutter run -d edge` (or your device)
- [ ] Login with a test account
- [ ] Navigate to dashboard
- [ ] Click "Start Video Call" button
- [ ] Should see video initialization screen
- [ ] Confirm network controller is initialized
- [ ] Verify adaptive bitrate controller responds to quality changes

## Phase 7: Integration Testing
- [ ] Test on WiFi network
  ```
  Expected: 1080p@30fps quality selected
  ```
  
- [ ] Test on cellular network
  ```
  Expected: Quality drops to 720p or 480p based on bandwidth
  ```
  
- [ ] Test with simulated poor connection (use DevTools)
  ```
  Expected: Quality adapts to 360p@15fps
  ```
  
- [ ] Test network switching
  ```
  Expected: Smooth transition between WiFi and cellular
  ```

- [ ] Monitor logs
  ```dart
  // In video_call_service.dart or where needed
  print('Network quality: ${_networkController.currentNetwork?.quality}');
  print('Video settings: ${_bitrateController.currentSettings}');
  ```

## Phase 8: Production Deployment Checklist
- [ ] Configure STUN/TURN servers with proper credentials
- [ ] Set up signaling WebSocket server with TLS (wss://)
- [ ] Implement proper error handling and fallbacks
- [ ] Add call history logging to backend
- [ ] Implement call recording (optional)
- [ ] Add end-to-end encryption (DTLS-SRTP)
- [ ] Test on 4G/LTE networks
- [ ] Test on 5G networks (if available)
- [ ] Test on poor WiFi networks
- [ ] Test battery impact
- [ ] Monitor data usage

## Phase 9: Optional Enhancements (After MVP)
- [ ] Screen sharing support
- [ ] Call recording for medical records
- [ ] Low-light enhancement for poor lighting
- [ ] Codec negotiation (VP9/H.265)
- [ ] Network monitoring dashboard
- [ ] Call quality analytics
- [ ] Bandwidth adaptation visualization
- [ ] AI-based background blur
- [ ] Virtual backgrounds

## Common Issues & Solutions

### Issue: Camera not working
**Solution**: Check permissions in AndroidManifest.xml and iOS Info.plist. Request permissions at runtime with `permission_handler` package.

### Issue: No audio
**Solution**: Verify microphone permissions. Check if audio is muted. Ensure audio routing is correct (speaker vs. handset).

### Issue: Blurry video
**Solution**: Compression artifacts. Increase bitrate or use different codec (VP9/H.265). Check network quality is sufficient.

### Issue: High latency
**Solution**: Use closer TURN servers. Check network path. Implement temporal scaling to reduce frame drops.

### Issue: Frequent disconnections
**Solution**: Implement reconnection logic. Check ICE candidate gathering. Verify STUN/TURN server configuration.

### Issue: High battery drain
**Solution**: Reduce frame rate and resolution. Disable video when not needed. Use hardware encoding.

## Debugging Tools

### Monitor Network:
```dart
context.read<MultiNetworkController>().addListener(() {
  final network = context.read<MultiNetworkController>().currentNetwork;
  print('Network: ${network?.type} - Quality: ${network?.quality}');
  print('Bandwidth: ${network?.bandwidth}Mbps');
  print('Latency: ${network?.latency}ms');
});
```

### Monitor Quality Adaptation:
```dart
context.read<AdaptiveBitrateController>().addListener(() {
  final settings = context.read<AdaptiveBitrateController>().currentSettings;
  print('Video: ${settings.resolution}p@${settings.frameRate}fps');
  print('Bitrate: ${settings.bitrate}kbps');
});
```

### WebRTC Stats (from within video_call_screen.dart):
```dart
// In a periodic timer:
final stats = await _peerConnection.getStats();
print('RTCStats: $stats');
```

## Implementation Progress Tracker

### Completed ✅
- [x] Network quality monitoring (MultiNetworkController)
- [x] Adaptive bitrate controller with 5-tier quality system
- [x] Video call service layer with state management
- [x] Comprehensive video call UI with quality indicators
- [x] WebRTC peer connection implementation example
- [x] Integrated example showing full usage

### In Progress 🟡
- [ ] Dependencies in pubspec.yaml
- [ ] Provider setup in main.dart
- [ ] Dashboard integration
- [ ] WebSocket signaling server

### Pending ⏳
- [ ] STUN/TURN server configuration
- [ ] Permission handling
- [ ] Real network statistics APIs (Android/iOS)
- [ ] Video codec negotiation (VP9/H.265)
- [ ] Dual-network failover testing
- [ ] Production server deployment

## Next Steps Priority

**IMMEDIATE (Day 1):**
1. Add pubspec.yaml dependencies
2. Update main.dart with MultiProvider
3. Test compilation on web
4. Test compilation on Android device

**SHORT-TERM (Week 1):**
1. Update dashboard with video call button
2. Set up basic WebSocket server locally
3. Test basic video connection flow
4. Verify network monitoring works

**MEDIUM-TERM (Week 2-3):**
1. Implement STUN/TURN configuration
2. Add permission handling
3. Test on various networks
4. Implement reconnection logic

**LONG-TERM (Post-MVP):**
1. Add codec negotiation
2. Implement screen sharing
3. Add call recording
4. Deploy to cloud servers

## Resources & Documentation

- **Flutter WebRTC**: https://github.com/flutter-webrtc/flutter-webrtc
- **Connectivity Plus**: https://pub.dev/packages/connectivity_plus
- **Provider**: https://pub.dev/packages/provider
- **WebRTC Standards**: https://w3c.github.io/webrtc-pc/
- **Agora SDK**: https://docs.agora.io/en/ (Alternative to WebRTC)
- **Twilio Video**: https://www.twilio.com/docs/video (Alternative to WebRTC)

## Support & Troubleshooting

For detailed troubleshooting:
1. Check `VIDEO_IMPLEMENTATION_GUIDE.md`
2. Review `webrtc_peer_connection.dart` comments
3. Check Flutter WebRTC documentation
4. Review integrated_video_call_screen.dart for examples

---

**Status**: Core architecture complete ✅ | Ready for backend integration 🔧
