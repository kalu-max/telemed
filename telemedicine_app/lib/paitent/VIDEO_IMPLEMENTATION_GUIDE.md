# Low Bandwidth Video Conferencing Implementation Guide

## Overview
This guide explains how to implement low-bandwidth, high-resolution video conferencing for your telemedicine app with multi-network support (WiFi + Cellular).

## Architecture Components

### 1. **MultiNetworkController** (network_controller.dart)
- **Purpose**: Monitor and manage network connectivity
- **Features**:
  - Detects WiFi, cellular (4G/5G), and no connection
  - Measures network quality (latency, bandwidth, signal strength)
  - Classifies network as: Excellent, Good, Fair, Poor, Very Poor
  - Supports dual-network detection for hybrid connectivity
  - Tracks network metrics history

- **Key Methods**:
  ```dart
  getAverageBandwidth()      // Get average available bandwidth
  getAverageLatency()        // Get average network latency
  isDualNetworkAvailable()   // Check if WiFi+cellular both available
  ```

### 2. **AdaptiveBitrateController** (adaptive_bitrate_controller.dart)
- **Purpose**: Dynamically adjust video quality based on network conditions
- **Features**:
  - Real-time quality adjustment
  - Supports 5 preset configurations:
    - 1080p @ 30fps (4.5 Mbps) - Excellent networks
    - 720p @ 30fps (2.5 Mbps) - Good networks
    - 480p @ 24fps (800 kbps) - Fair networks
    - 360p @ 15fps (250 kbps) - Poor networks
    - 360p @ 15fps (250 kbps) - Very Poor networks

- **Key Methods**:
  ```dart
  getRecommendedQuality()    // Automatic quality adjustment
  setVideoQuality()          // Manual quality override
  getAvailableQualityOptions()  // List all quality options
  ```

### 3. **VideoCallService** (video_call_service.dart)
- **Purpose**: Manage video call lifecycle
- **Features**:
  - Initiates and accepts calls
  - Manages audio/video toggling
  - Handles speaker/microphone control
  - Tracks call status and duration

### 4. **VideoCallScreen** (video_call_screen.dart)
- **Purpose**: UI for video conferencing
- **Features**:
  - Real-time network quality indicator
  - Expandable quality panel with network stats
  - Call controls (mute, video toggle, speaker, etc.)
  - Dynamic video quality display
  - Responsive layout

## Integration Steps

### Step 1: Add Dependencies to pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  connectivity_plus: ^5.0.0          # Network detection
  flutter_webrtc: ^0.9.0             # WebRTC for video
  agora_uikit: ^1.0.0                # Alternative: Agora SDK
  # OR
  twilio_flutter: ^1.0.0             # Alternative: Twilio SDK
  provider: ^6.0.0                   # State management
```

### Step 2: Initialize Controllers in Main App
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
        home: const LoginScreen(),
      ),
    );
  }
}
```

### Step 3: Add to Dashboard for Quick Access
In `paitentdashboard.dart`, add a "Start Video Call" button:

```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          remoteUserId: 'doctor-123',
          remoteUserName: 'Dr. James Wilson',
          remoteUserAvatar: 'https://example.com/avatar.jpg',
          callService: VideoCallService(
            networkController: context.read<MultiNetworkController>(),
            adaptiveBitrate: context.read<AdaptiveBitrateController>(),
          ),
        ),
      ),
    );
  },
  icon: const Icon(Icons.videocam),
  label: const Text('Start Video Call'),
)
```

## Technology Implementation Details

### WebRTC Implementation (Recommended)
```dart
// Connect to signaling server
// Set up peer connection with constraints
RTCPeerConnection peerConnection = await createPeerConnection(
  {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302'],
      }
    ]
  },
  {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
  },
);

// Apply adaptive bitrate settings
await peerConnection.addTrack(
  localVideoTrack,
  MediaStreamConstraints(
    video: VideoConstraints(
      width: VideoConstants.resolution,
      height: VideoConstants.resolution,
      frameRate: VideoConstants.fps,
    ),
    audio: true,
  ),
);
```

### Network Selection Strategy
1. **Primary Network**: WiFi (if available)
2. **Fallback**: Cellular
3. **Hybrid**: Use both simultaneously for:
   - Load balancing
   - Redundancy
   - Higher combined bandwidth

### Codec Selection for Low Bandwidth
- **Recommended**: VP9 or H.265 (HEVC)
  - 40-50% better compression than H.264
  - Better quality at lower bitrates
  
- **Fallback**: H.264 or VP8
  - Wider device support
  - Proven reliability

### Bandwidth Optimization Techniques
1. **Simulcast**: Send multiple quality streams simultaneously
2. **Temporal Scaling**: Drop frames on poor networks
3. **Spatial Scaling**: Reduce resolution dynamically
4. **Content Recognition**: Lower quality for screen share
5. **Circuit Breaker**: Switch to audio-only below 0.5 Mbps

## Network Quality Thresholds

| Bandwidth | Latency | Recommendation |
|-----------|---------|-----------------|
| ≥3.5 Mbps | ≤50ms   | 1080p @ 30fps - Full HD |
| 2-3.5 Mbps | ≤100ms  | 720p @ 30fps - HD |
| 1.2-2 Mbps | ≤150ms  | 480p @ 24fps - Standard |
| 0.6-1.2 Mbps | ≤250ms | 360p @ 15fps - Low quality |
| <0.6 Mbps | >250ms  | Audio only + Low-res fallback |

## Testing Checklist

- [ ] Test on WiFi network
- [ ] Test on 4G/LTE network
- [ ] Test on 5G network
- [ ] Simulate poor WiFi (2.4GHz congestion)
- [ ] Simulate poor cellular (3G fallback)
- [ ] Test network switching during call
- [ ] Test WiFi to cellular failover
- [ ] Monitor battery consumption
- [ ] Check for artifacts/flickering
- [ ] Verify audio sync
- [ ] Test on different devices
- [ ] Test with VPN enabled

## Production Considerations

### Server Requirements
1. **STUN Servers**: For NAT traversal
   ```
   stun:stun.l.google.com:19302
   stun:stun1.l.google.com:19302
   ```

2. **TURN Servers**: For relay (required for restrictive networks)
   ```
   turn:turn.example.com:3478
   ```

3. **Signaling Server**: For call setup
   - Send offer/answer
   - Exchange ICE candidates
   - Handle call rejection
   - Track call duration

### Security
- Use DTLS-SRTP for encrypted media
- Validate certificate pinning
- Implement rate limiting
- Add DDoS protection
- Encrypt signaling channel (WSS)

### Monitoring & Analytics
- Track connection quality metrics
- Log network failures
- Monitor call quality complaints
- Analyze codec usage
- Track average call duration
- Monitor battery drain

### Error Handling
```dart
try {
  await callService.initiateCall(...);
} on NetworkException {
  // Handle network unavailable
  showSnackBar('No network connection');
} on DeviceException {
  // Handle camera/microphone issues
  showSnackBar('Camera or microphone not available');
} on TimeoutException {
  // Handle call timeout
  showSnackBar('Call request timed out');
} catch (e) {
  showSnackBar('Call failed: $e');
}
```

## Performance Tips

1. **Reduce CPU Usage**:
   - Use hardware encoding/decoding
   - Disable simulcast for low-end devices
   - Reduce frame rate on older devices

2. **Reduce Memory**:
   - Use object pooling for video frames
   - Release resources immediately
   - Limit history buffers

3. **Reduce Bandwidth**:
   - Aggressive SVC (spatial/temporal)
   - Increase I-frame interval
   - Use perceptual video coding

4. **Reduce Latency**:
   - Minimize buffering
   - Use P2P when possible
   - Optimize relay server locations

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No Video | Check permissions, STUN/TURN servers |
| Frozen Video | Increase bitrate, reduce resolution |
| No Audio | Check microphone permissions, audio routing |
| High Latency | Use TURN relay, check device load |
| Call Drops | Increase reconnection timeout, add redundancy |
| Poor Quality | Enable adaptive bitrate, reduce framerate |
| Battery Drain | Reduce frame rate, disable video when not needed |

## References

- WebRTC: https://webrtc.org/
- Flutter WebRTC: https://github.com/flutter-webrtc/flutter-webrtc
- Agora: https://www.agora.io/
- Twilio: https://www.twilio.com/
- RFC 3550 (RTP): https://tools.ietf.org/html/rfc3550
- VP9 Codec: https://developers.google.com/media/vp9
- H.264 Standard: https://www.itu.int/rec/T-REC-H.264/

