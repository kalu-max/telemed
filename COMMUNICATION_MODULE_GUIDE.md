# Real-Time Communication Module - Integration Guide

## Overview

This comprehensive real-time communication module integrates text chat, voice messaging, video calling with adaptive bitrate streaming, bandwidth optimization, and end-to-end encryption into the telemedicine app. The module is designed with WhatsApp-like simplicity and HIPAA/GDPR compliance.

## Architecture

### Frontend (Flutter)
```
lib/communication/
├── models/
│   ├── message_model.dart       # ChatMessage, VoiceMessage, Conversation
│   ├── call_model.dart          # CallSession, CallStatistics, VideoQuality
│   └── network_model.dart       # NetworkMetrics, NetworkHistory
├── services/
│   ├── messaging_service.dart   # Text messaging with receipts
│   ├── voice_messaging_service.dart  # Voice recording/playback with Opus
│   ├── video_calling_service.dart    # WebRTC video calling
│   └── bandwidth_optimization_service.dart  # Network monitoring
├── providers/
│   └── communication_providers.dart  # State management (ChangeNotifier)
└── widgets/
    ├── chat_widgets.dart        # Chat UI components
    └── call_widgets.dart        # Voice/Video call UI
```

### Backend (Node.js)
```
server/
├── api/
│   └── communications.js        # REST endpoints for messaging
├── websocket/
│   └── communicationHandler.js  # Socket.IO event handlers
└── models/
    ├── ChatMessage.js
    ├── Conversation.js
    ├── VoiceMessage.js
    ├── CallSession.js
    └── CallStatistics.js
```

## Features Implementation

### 1. Text Chat with Delivery/Read Receipts

**Status Lifecycle:**
- `sending` → `sent` → `delivered` → `read`

**Implementation:**
```dart
// Send message with encryption
final message = await messagingProvider.sendTextMessage(
  conversationId: 'conv_123',
  receiverId: 'user_456',
  receiverName: 'Dr. Smith',
  content: 'How are you feeling?',
);

// Listen to delivery/read receipts
messagingProvider.messagingService.deliveryReceiptStream.listen((receipt) {
  print('Message ${receipt.messageId} delivered');
});

messagingProvider.messagingService.readReceiptStream.listen((receipt) {
  print('Message ${receipt.messageId} read');
});
```

**Typing Indicators:**
```dart
// Send typing indicator
messagingProvider.messagingService.sendTypingIndicator(
  conversationId,
  recipientId,
);

// Listen to typing status
messagingProvider.messagingService.typingStatusStream.listen((status) {
  if (provider.isUserTyping(status.senderId)) {
    print('${status.senderName} is typing...');
  }
});
```

### 2. Voice Messaging with Opus Codec

**Recording Voice Message:**
```dart
final voiceProvider = context.read<VoiceMessagingProvider>();

// Start recording
await voiceProvider.startRecording();

// Listen to recording state
context.watch<VoiceMessagingProvider>().isRecording; // true

// Stop and send
await voiceProvider.stopRecording();
final file = File(voiceProvider.recordingPath);

// Send voice message
final voiceMessage = await voiceMessagingService.sendVoiceMessage(
  conversationId: 'conv_123',
  receiverId: 'user_456',
  receiverName: 'Dr. Smith',
  audioFile: file,
);
```

**Compression Specifications:**
- **Codec**: Opus (RFC 6176)
- **Bitrate**: 24 kbps (default, adaptive)
- **Sample Rate**: 16 kHz (wideband audio)
- **Channels**: Mono (1)
- **Frame Duration**: 20ms

**Playback:**
```dart
// Play voice message
await voiceProvider.playVoiceMessage(audioPath);

// Monitor playback
context.watch<VoiceMessagingProvider>().isPlaying;
context.watch<VoiceMessagingProvider>().currentPosition;
```

### 3. Adaptive Bitrate Video Calling

**Video Quality Levels:**
```dart
enum VideoQuality {
  low(bitrate: 500000, width: 320, height: 240, fps: 15),    // 500 kbps
  medium(bitrate: 1500000, width: 640, height: 480, fps: 24), // 1.5 Mbps
  high(bitrate: 2500000, width: 1280, height: 720, fps: 30);  // 2.5 Mbps
}
```

**Initiate Video Call:**
```dart
final videoProvider = context.read<VideoCallingProvider>();

// Initiate call
await videoProvider.initiateVideoCall(
  receiverId: 'user_456',
  receiverName: 'Dr. Smith',
);

// Listen to call state changes
videoProvider.callStateStream.listen((call) {
  print('Call status: ${call.status}');
});

// Monitor network quality
videoProvider.statsStream.listen((stats) {
  print('Bitrate: ${stats.avgBitrate} kbps');
  print('Latency: ${stats.avgLatency} ms');
  print('Video Quality: ${stats.currentVideoQuality}');
});
```

**Adaptive Quality Management:**
```dart
// Automatically adjusts quality based on bandwidth
// High bandwidth (>2.5 Mbps) → HD (1280x720@30fps)
// Medium bandwidth (1-2 Mbps) → SD (640x480@24fps)
// Low bandwidth (<1 Mbps) → LD (320x240@15fps)
```

### 4. Bandwidth Optimization

**Network Monitoring:**
```dart
final networkProvider = context.read<NetworkProvider>();

// Get current network metrics
final metrics = networkProvider.currentMetrics;
print('Network Type: ${networkProvider.currentNetworkType}');
print('Download: ${metrics?.downstreamBandwidth} Mbps');
print('Upload: ${metrics?.upstreamBandwidth} Mbps');
print('Latency: ${metrics?.latency} ms');
print('Quality: ${networkProvider.networkQualityLabel}'); // Excellent/Good/Fair/Poor
```

**Network Type Support:**
- Wi-Fi
- 5G (100+ Mbps)
- 4G/LTE (10-30 Mbps)
- 3G (1-5 Mbps)
- 2G EDGE (<1 Mbps)

**Capability Detection:**
```dart
if (networkProvider.canSupportHDVideo) {
  // Use high quality video
} else if (networkProvider.canSupportVideo) {
  // Use medium quality
} else if (networkProvider.canSupportVoice) {
  // Audio only
}

// Get recommended audio bitrate
final recommendedBitrate = bandwidthService
    .getRecommendedAudioBitrate(metrics);
// Returns: 128, 64, 32, or 16 kbps based on bandwidth
```

### 5. Offline Message Queuing

**Automatic Queue Management:**
```dart
final offlineQueue = OfflineMessageQueueService();
await offlineQueue.initialize();

// Messages are automatically queued when offline
final queuedMessages = await offlineQueue.getQueuedMessages();

// Automatically synced when back online
offlineQueue.queuedMessageStream.listen((message) {
  print('Message queued: ${message.id}');
});

// Get queue stats
final stats = await offlineQueue.getQueueStats();
print('Queued: ${stats['queuedMessageCount']}');
print('Unsynced: ${stats['unSyncedCount']}');
print('Total Size: ${stats['totalContentSize']} bytes');
```

**Retry Logic:**
```dart
// Exponential backoff: 1s, 2s, 4s (max 3 retries)
// Automatic retry on connection restored
```

### 6. End-to-End Encryption

**AES-256-GCM Encryption:**
```dart
final encryptionService = EncryptionService();

// Generate encryption key for participant
final keyBytes = await encryptionService.generateKey();
await messagingService.setEncryptionKeyForParticipant(
  participantId,
  keyBytes,
);

// Encrypt message
final encrypted = await encryptionService.encryptMessage(
  'Secret message',
  keyBytes,
);

// Decrypt message
final decrypted = await encryptionService.decryptMessage(
  encrypted,
  keyBytes,
);

// Verify data integrity
final isValid = await encryptionService.verifyIntegrity(
  data,
  signature,
  keyBytes,
);

// Anonymize metadata for HIPAA/GDPR
final anonymized = encryptionService.anonymizeMetadata(metadata);
// Hashes all PII fields
```

### 7. HIPAA/GDPR Compliance

**Data Handling:**
- End-to-end encryption for all communications
- Soft-delete for compliance audit trails
- Anonymized metadata for analytics
- Audit logging of all events
- Data retention policies enforced

**Soft Delete Implementation:**
```dart
// Messages are soft-deleted (not permanently removed)
// Preserves audit trails for compliance
message.deletedAt = DateTime.now();
message.content = '[DELETED]';
await message.save();
```

**Audit Hash Generation:**
```dart
final auditHash = await encryptionService.generateAuditHash({
  'action': 'message_sent',
  'userId': 'user_123',
  'timestamp': DateTime.now().toIso8601String(),
});
```

## Integration Steps

### Step 1: Update pubspec.yaml
Dependencies have been added for:
- `socket_io_client` - WebSocket communication
- `flutter_webrtc` - Video calling
- `cryptography` - Encryption
- `record` & `audioplayers` - Voice messaging
- `connectivity_plus` - Network monitoring
- `hive` & `sqflite` - Offline storage

```bash
flutter pub get
```

### Step 2: Initialize Services in main.dart

```dart
import 'package:provider/provider.dart';
import 'lib/communication/services/messaging_service.dart';
import 'lib/communication/services/voice_messaging_service.dart';
import 'lib/communication/services/video_calling_service.dart';
import 'lib/communication/services/bandwidth_optimization_service.dart';
import 'lib/communication/providers/communication_providers.dart';

void main() async {
  // Initialize Hive for offline storage
  await Hive.initFlutter();
  
  runApp(const MediCareApp());
}

class MediCareApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Messaging
        ChangeNotifierProvider(
          create: (_) async {
            final messagingService = MessagingService(
              serverUrl: 'http://localhost:5000',
              userId: 'currentUserId',
              userName: 'Current User',
            );
            await messagingService.initialize();
            return MessagingProvider(messagingService: messagingService);
          },
        ),
        // Voice Messaging
        ChangeNotifierProvider(
          create: (context) => VoiceMessagingProvider(
            voiceMessagingService: context.read<VoiceMessagingService>(),
          ),
        ),
        // Video Calling
        ChangeNotifierProvider(
          create: (context) => VideoCallingProvider(
            videoCallingService: context.read<VideoCallingService>(),
          ),
        ),
        // Network Monitoring
        ChangeNotifierProvider(
          create: (_) => NetworkProvider(
            bandwidthService: BandwidthOptimizationService(),
          ),
        ),
      ],
      child: MaterialApp(
        // ... app configuration
      ),
    );
  }
}
```

### Step 3: Backend Setup

**Install dependencies:**
```bash
npm install socket.io
```

**Register communication endpoints in server.js:**
```javascript
const communicationsAPI = require('./server/api/communications');
const { initializeCommunicationSocket } = require('./server/websocket/communicationHandler');

// REST endpoints
app.use('/api/communications', communicationsAPI);

// Socket.IO events
initializeCommunicationSocket(io);
```

**Add database models:**
```javascript
const ChatMessage = require('./server/models/ChatMessage')(sequelize);
const Conversation = require('./server/models/Conversation')(sequelize);
const VoiceMessage = require('./server/models/VoiceMessage')(sequelize);
const CallSession = require('./server/models/CallSession')(sequelize);
const CallStatistics = require('./server/models/CallStatistics')(sequelize);
```

### Step 4: Create Conversation Screen

```dart
import 'package:flutter/material.dart';
import 'lib/communication/widgets/chat_widgets.dart';

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      conversationId: 'conv_123',
      participantId: 'user_456',
      participantName: 'Dr. Smith',
      participantAvatarUrl: 'https://...',
    );
  }
}
```

## UI Components

### Chat Screen
- Message list with auto-scrolling
- WhatsApp-like message bubbles (left/right aligned)
- Typing indicators
- Delivery/read status icons
- Message input with attachments
- Emoji support (can be added)

### Voice Messaging Widget
- One-tap recording with visual feedback
- Duration display during recording
- Playback with progress bar
- Waveform visualization (optional)
- File size display

### Video Call Screen
- Local video preview (PiP)
- Remote video full-screen
- Network quality indicator
- Call controls (mute, camera, end)
- Call status display
- Duration timer

## Performance Optimization

### Message Batching
Messages are batched before sending to reduce network overhead:
```javascript
// Socket.IO automatically batches events within event loop
socket.emit('message', data); // Batched
```

### Bandwidth Adaptation
Real-time adjustments based on network conditions:
- Video quality adjusted every 1-2 seconds
- Audio bitrate adjusted dynamically
- Frame rate reduced on poor connections
- Automatic fallback to audio-only

### Storage Optimization
- Local message storage limited to recent 100 messages per conversation
- Voice files automatically compressed with Opus codec
- Video not stored locally (streamed only)
- Call statistics aggregated and archived

## Testing

### Unit Tests
```bash
flutter test test/communication/test_encryption.dart
flutter test test/communication/test_messaging.dart
flutter test test/communication/test_bandwidth.dart
```

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

### Backend Tests
```bash
npm test test/communications.test.js
```

## Troubleshooting

### Connection Issues
1. Check Socket.IO server is running
2. Verify CORS configuration
3. Check firewall settings
4. Enable WebSocket in browser

### Audio Quality Issues
1. Check microphone permissions
2. Verify audio device availability
3. Check bandwidth metrics
4. Reduce bitrate if needed

### Video Call Lag
1. Check network metrics
2. Reduce video quality manually
3. Close other network-heavy apps
4. Move closer to WiFi router

### Encryption Errors
1. Verify encryption keys are initialized
2. Check for key mismatch between participants
3. Ensure sufficient entropy for random key generation

## Future Enhancements

1. **Group Calling**: Support multiple participants in video calls
2. **Screen Sharing**: Allow doctors to share medical images
3. **Message Search**: Full-text search across conversations
4. **Call Recording**: HIPAA-compliant recording with consent
5. **File Sharing**: Share medical documents securely
6. **Reactions**: Message reactions and emoji support
7. **Message Editing**: Edit sent messages with audit trail
8. **Typing Notifications**: Per-user typing indicators
9. **Message Reactions**: Emoji reactions to messages
10. **AI Transcription**: Automatic voice-to-text with HIPAA compliance

## Security Checklist

- [x] End-to-end encryption implemented
- [x] HIPAA-compliant audit logging
- [x] Soft delete for GDPR compliance
- [x] Input validation on all endpoints
- [x] Rate limiting for API calls
- [x] CORS properly configured
- [x] JWT authentication required
- [x] Sensitive data anonymized
- [ ] Penetration testing completed
- [ ] Security audit scheduled

## Support & Documentation

For detailed API documentation, see:
- [Flutter WebRTC Documentation](https://pub.dev/packages/flutter_webrtc)
- [Socket.IO Documentation](https://socket.io/docs/)
- [HIPAA Guidelines](https://www.hhs.gov/hipaa/)
- [GDPR Compliance](https://gdpr-info.eu/)

## License

This communication module is part of the MediCare Connect telemedicine platform and is licensed under the MIT License.
