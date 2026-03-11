import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import '../services/messaging_service.dart';
import '../services/voice_messaging_service.dart';
import '../services/video_calling_service.dart';
import '../services/bandwidth_optimization_service.dart';
import '../models/message_model.dart';
import '../models/call_model.dart';
import '../models/network_model.dart';
import 'dart:async';

/// Provider for managing messaging state
class MessagingProvider extends ChangeNotifier {
  final MessagingService messagingService;

  final List<ChatMessage> _messages = [];
  final Map<String, Conversation> _conversations = {};
  final Map<String, TypingStatus> _typingStatuses = {};
  final Map<String, DeliveryReceipt> _deliveryReceipts = {};
  final Map<String, ReadReceipt> _readReceipts = {};

  bool _isConnected = false;
  late StreamSubscription _messageSubscription;
  late StreamSubscription _typingSubscription;
  late StreamSubscription _deliverySubscription;
  late StreamSubscription _readSubscription;
  late StreamSubscription _connectionSubscription;

  MessagingProvider({required this.messagingService}) {
    _initializeListeners();
  }

  /// Initialize stream listeners
  void _initializeListeners() {
    _messageSubscription = messagingService.messageStream.listen((message) {
      addMessage(message);
    });

    _typingSubscription = messagingService.typingStatusStream.listen((status) {
      _typingStatuses[status.senderId] = status;
      notifyListeners();
    });

    _deliverySubscription = messagingService.deliveryReceiptStream.listen((
      receipt,
    ) {
      _deliveryReceipts[receipt.messageId] = receipt;
      _updateMessageStatus(receipt.messageId, MessageStatus.delivered);
    });

    _readSubscription = messagingService.readReceiptStream.listen((receipt) {
      _readReceipts[receipt.messageId] = receipt;
      _updateMessageStatus(receipt.messageId, MessageStatus.read);
    });

    _connectionSubscription = messagingService.connectionStatusStream.listen((
      isConnected,
    ) {
      _isConnected = isConnected;
      notifyListeners();
    });
  }

  /// Add message to state
  void addMessage(ChatMessage message) {
    _messages.add(message);

    // Update or create conversation
    if (!_conversations.containsKey(message.conversationId)) {
      _conversations[message.conversationId] = Conversation(
        id: message.conversationId,
        participantId: message.senderId == messagingService.userId
            ? message.receiverId
            : message.senderId,
        participantName: message.senderName,
        lastMessageTime: message.timestamp,
        lastMessage: message.content,
      );
    } else {
      final conversation = _conversations[message.conversationId]!;
      conversation.lastMessageTime = message.timestamp;
      conversation.lastMessage = message.content;
    }

    notifyListeners();
  }

  /// Send text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required String content,
  }) async {
    try {
      final message = await messagingService.sendMessage(
        conversationId: conversationId,
        receiverId: receiverId,
        receiverName: receiverName,
        content: content,
      );
      addMessage(message);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Update message status
  void _updateMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      _messages[messageIndex].status = status;
      notifyListeners();
    }
  }

  /// Get messages for conversation
  List<ChatMessage> getConversationMessages(String conversationId) {
    return _messages.where((m) => m.conversationId == conversationId).toList();
  }

  /// Get all conversations sorted by recent
  List<Conversation> getAllConversations() {
    final conversations = _conversations.values.toList();
    conversations.sort(
      (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
    );
    return conversations;
  }

  /// Check if user is typing
  bool isUserTyping(String userId) {
    final status = _typingStatuses[userId];
    if (status == null) return false;

    // Consider typing status expired after 3 seconds
    final ageSinceLastTyping = DateTime.now().difference(status.timestamp);
    return ageSinceLastTyping.inSeconds < 3;
  }

  /// Get unread count for conversation
  int getUnreadCount(String conversationId) {
    return _messages
        .where(
          (m) =>
              m.conversationId == conversationId &&
              m.status != MessageStatus.read,
        )
        .length;
  }

  /// Clear conversation
  void clearConversation(String conversationId) {
    _messages.removeWhere((m) => m.conversationId == conversationId);
    _conversations.remove(conversationId);
    notifyListeners();
  }

  bool get isConnected => _isConnected;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, Conversation> get conversations =>
      Map.unmodifiable(_conversations);

  @override
  void dispose() {
    _messageSubscription.cancel();
    _typingSubscription.cancel();
    _deliverySubscription.cancel();
    _readSubscription.cancel();
    _connectionSubscription.cancel();
    super.dispose();
  }
}

/// Provider for managing voice messaging
class VoiceMessagingProvider extends ChangeNotifier {
  final VoiceMessagingService voiceMessagingService;

  bool _isRecording = false;
  String? _recordingPath;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  final Duration _totalDuration = Duration.zero;
  late StreamSubscription _playerStateSubscription;
  late StreamSubscription _positionSubscription;

  VoiceMessagingProvider({required this.voiceMessagingService}) {
    _initializeListeners();
  }

  void _initializeListeners() {
    _playerStateSubscription = voiceMessagingService.playerStateStream.listen((
      state,
    ) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _positionSubscription = voiceMessagingService.positionStream.listen((
      position,
    ) {
      _currentPosition = position;
      notifyListeners();
    });
  }

  Future<void> startRecording() async {
    try {
      _recordingPath = await voiceMessagingService.startRecording();
      _isRecording = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  Future<String> stopRecording() async {
    try {
      final audioFile = await voiceMessagingService.stopRecording();
      _recordingPath = audioFile.path;
      _isRecording = false;
      notifyListeners();
      return audioFile.path;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  Future<ChatMessage> sendVoiceMessage({
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required String audioPath,
  }) async {
    try {
      final voiceMessage = await voiceMessagingService.sendVoiceMessage(
        conversationId: conversationId,
        receiverId: receiverId,
        receiverName: receiverName,
        audioFile: File(audioPath),
      );

      final message = ChatMessage(
        id: voiceMessage.messageId,
        conversationId: conversationId,
        senderId: voiceMessagingService.messagingService.userId,
        senderName: voiceMessagingService.messagingService.userName,
        receiverId: receiverId,
        content: 'Voice message',
        messageType: MessageType.voice,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        metadata: {
          'messageType': 'voice',
          'voiceMessageId': voiceMessage.id,
          'audioPath': voiceMessage.audioPath,
          'duration': voiceMessage.duration.inMilliseconds,
          'fileSize': voiceMessage.fileSize,
          'codec': voiceMessage.codec,
          'bitrate': voiceMessage.bitrate,
        },
      );

      _recordingPath = null;
      notifyListeners();
      return message;
    } catch (e) {
      throw Exception('Failed to send voice message: $e');
    }
  }

  Future<void> playVoiceMessage(String audioPath) async {
    try {
      await voiceMessagingService.playVoiceMessage(audioPath);
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to play voice message: $e');
    }
  }

  Future<void> pausePlayback() async {
    await voiceMessagingService.pauseVoiceMessage();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resumePlayback() async {
    await voiceMessagingService.resumeVoiceMessage();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    await voiceMessagingService.stopVoiceMessage();
    _isPlaying = false;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get recordingPath => _recordingPath;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _positionSubscription.cancel();
    super.dispose();
  }
}

/// Provider for managing video calls
class VideoCallingProvider extends ChangeNotifier {
  final VideoCallingService videoCallingService;

  CallSession? _currentCall;
  VideoQuality _currentVideoQuality = VideoQuality.medium;
  CallStatistics? _lastStats;
  late StreamSubscription _callStateSubscription;
  late StreamSubscription _statsSubscription;
  late StreamSubscription _qualitySubscription;

  VideoCallingProvider({required this.videoCallingService}) {
    _initializeListeners();
  }

  void _initializeListeners() {
    _callStateSubscription = videoCallingService.callStateStream.listen((call) {
      _currentCall = call;
      notifyListeners();
    });

    _statsSubscription = videoCallingService.statsStream.listen((stats) {
      _lastStats = stats;
      notifyListeners();
    });

    _qualitySubscription = videoCallingService.qualityChangeStream.listen((
      quality,
    ) {
      _currentVideoQuality = quality;
      notifyListeners();
    });
  }

  Future<void> initiateVideoCall({
    required String receiverId,
    required String receiverName,
  }) async {
    try {
      await videoCallingService.initiateVideoCall(
        receiverId: receiverId,
        receiverName: receiverName,
        callType: CallType.video,
      );
    } catch (e) {
      throw Exception('Failed to initiate call: $e');
    }
  }

  Future<void> acceptCall() async {
    try {
      await videoCallingService.acceptCall();
    } catch (e) {
      throw Exception('Failed to accept call: $e');
    }
  }

  Future<void> rejectCall() async {
    try {
      await videoCallingService.rejectCall();
    } catch (e) {
      throw Exception('Failed to reject call: $e');
    }
  }

  Future<void> endCall() async {
    try {
      await videoCallingService.endCall();
      _currentCall = null;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to end call: $e');
    }
  }

  CallSession? get currentCall => _currentCall;
  VideoQuality get currentVideoQuality => _currentVideoQuality;
  CallStatistics? get lastStats => _lastStats;

  @override
  void dispose() {
    _callStateSubscription.cancel();
    _statsSubscription.cancel();
    _qualitySubscription.cancel();
    super.dispose();
  }
}

/// Provider for managing network bandwidth
class NetworkProvider extends ChangeNotifier {
  final BandwidthOptimizationService bandwidthService;

  NetworkMetrics? _currentMetrics;
  NetworkType _currentNetworkType = NetworkType.unknown;
  late StreamSubscription _metricsSubscription;
  late StreamSubscription _networkTypeSubscription;

  NetworkProvider({required this.bandwidthService}) {
    _initializeListeners();
  }

  void _initializeListeners() {
    _metricsSubscription = bandwidthService.metricsStream.listen((metrics) {
      _currentMetrics = metrics;
      notifyListeners();
    });

    _networkTypeSubscription = bandwidthService.networkTypeStream.listen((
      type,
    ) {
      _currentNetworkType = type;
      notifyListeners();
    });

    // Start monitoring
    bandwidthService.startBandwidthMonitoring();
  }

  NetworkMetrics? get currentMetrics => _currentMetrics;
  NetworkType get currentNetworkType => _currentNetworkType;

  bool get canSupportHDVideo => _currentMetrics?.canSupportHDVideo() ?? false;
  bool get canSupportVideo => _currentMetrics?.canSupportVideo() ?? false;
  bool get canSupportVoice => _currentMetrics?.canSupportVoice() ?? false;

  int get networkQualityScore => _currentMetrics?.getQualityScore() ?? 0;
  String get networkQualityLabel {
    final score = networkQualityScore;
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  @override
  void dispose() {
    _metricsSubscription.cancel();
    _networkTypeSubscription.cancel();
    bandwidthService.stopBandwidthMonitoring();
    super.dispose();
  }
}
