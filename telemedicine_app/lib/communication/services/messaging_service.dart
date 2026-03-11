import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../utils/encryption_service.dart';
import 'offline_queue_service.dart';

/// Core service for text messaging with delivery receipts and typing indicators
class MessagingService {
  final String serverUrl;
  String userId;
  String userName;
  String role;

  late io.Socket socket;
  late EncryptionService _encryptionService;
  late OfflineMessageQueueService _offlineQueue;
  late MessageRetryService _retryService;

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<String> _typingIndicatorController =
      StreamController<String>.broadcast();
  final StreamController<TypingStatus> _typingStatusController =
      StreamController<TypingStatus>.broadcast();
  final StreamController<DeliveryReceipt> _deliveryReceiptController =
      StreamController<DeliveryReceipt>.broadcast();
  final StreamController<ReadReceipt> _readReceiptController =
      StreamController<ReadReceipt>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;
  bool _isInitialized = false;
  final Map<String, String> _encryptionKeys = {};
  final Map<String, DateTime> _typingTimestamps = {};

  final uuid = const Uuid();

  MessagingService({
    required this.serverUrl,
    required this.userId,
    required this.userName,
    this.role = 'patient',
  }) {
    _encryptionService = EncryptionService();
    _offlineQueue = OfflineMessageQueueService();
    _retryService = MessageRetryService();
  }

  /// Initialize messaging service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      await _offlineQueue.initialize();

      _createSocket();

      _setupSocketListeners();
      _isInitialized = true;
      await connect();
    } catch (e) {
      throw Exception('Failed to initialize messaging service: $e');
    }
  }

  Future<void> updateSession({
    required String userId,
    required String userName,
    String role = 'patient',
  }) async {
    final nextUserId = userId.trim().isEmpty ? 'guest' : userId.trim();
    final nextUserName = userName.trim().isEmpty ? 'Patient' : userName.trim();
    final nextRole = role.trim().isEmpty ? 'patient' : role.trim();

    final identityChanged =
        this.userId != nextUserId ||
        this.userName != nextUserName ||
        this.role != nextRole;

    this.userId = nextUserId;
    this.userName = nextUserName;
    this.role = nextRole;

    if (!_isInitialized) {
      await initialize();
      return;
    }

    if (!identityChanged) {
      return;
    }

    await disconnect();
    socket.dispose();
    _createSocket();
    _setupSocketListeners();
    await connect();
  }

  void _createSocket() {
    socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'userId': userId, 'role': role},
    });
  }

  /// Setup socket event listeners
  void _setupSocketListeners() {
    socket.on('connect', (_) {
      _isConnected = true;
      _connectionStatusController.add(true);
      socket.emit('user:online', {'userId': userId, 'role': role});
      _syncOfflineMessages();
    });

    socket.on('connect_error', (_) {
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    socket.on('disconnect', (_) {
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    socket.on('message', (data) {
      _handleIncomingMessage(data);
    });

    socket.on('voiceMessage', (data) {
      _handleIncomingVoiceMessage(data);
    });

    socket.on('typing', (data) {
      _handleTypingStatus(data);
    });

    socket.on('deliveryReceipt', (data) {
      _handleDeliveryReceipt(data);
    });

    socket.on('readReceipt', (data) {
      _handleReadReceipt(data);
    });

    socket.on('error', (error) {
      // Error logged via socket connection handler
    });
  }

  /// Connect to messaging server
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      socket.connect();
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      throw Exception('Failed to connect to messaging server: $e');
    }
  }

  /// Disconnect from server
  Future<void> disconnect() async {
    if (!_isInitialized) return;
    socket.disconnect();
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  /// Send a text message
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required String content,
    Map<String, dynamic>? metadata,
    bool encrypt = true,
  }) async {
    final messageId = uuid.v4();
    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderId: userId,
      senderName: userName,
      receiverId: receiverId,
      content: content,
      messageType: MessageType.text,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      metadata: metadata,
      encryptionKey: _encryptionKeys[receiverId],
      encryptionStatus: encrypt
          ? EncryptionStatus.encrypted
          : EncryptionStatus.unencrypted,
    );

    try {
      // Encrypt message if enabled
      String contentToSend = content;
      if (encrypt && _encryptionKeys.containsKey(receiverId)) {
        try {
          contentToSend = await _encryptionService.encryptMessage(
            content,
            _encryptionKeys[receiverId]!.codeUnits,
          );
          message.encryptionStatus = EncryptionStatus.encrypted;
        } catch (e) {
          message.encryptionStatus = EncryptionStatus.failed;
        }
      }

      // Emit via socket
      socket.emit('sendMessage', {
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': userId,
        'senderName': userName,
        'receiverId': receiverId,
        'content': contentToSend,
        'timestamp': message.timestamp.toIso8601String(),
        'metadata': metadata,
      });

      return message;
    } catch (e) {
      // Queue message for later sending
      await _offlineQueue.queueMessage(message);
      return message;
    }
  }

  /// Handle incoming messages
  void _handleIncomingMessage(dynamic data) {
    try {
      final message = ChatMessage.fromJson(data);

      // Decrypt if needed
      if (message.encryptionStatus == EncryptionStatus.encrypted &&
          _encryptionKeys.containsKey(message.senderId)) {
        _decryptMessageAsync(message);
      }

      _messageController.add(message);
    } catch (e) {
      // Error handled: failed to process incoming message
    }
  }

  /// Handle incoming voice messages
  void _handleIncomingVoiceMessage(dynamic data) async {
    try {
      final payload = Map<String, dynamic>.from(data as Map);
      final audioPath = await _persistIncomingVoiceMessage(
        messageId: payload['id']?.toString() ?? uuid.v4(),
        audioData: payload['audioData']?.toString() ?? '',
        codec: payload['codec']?.toString() ?? 'opus',
      );

      final message = ChatMessage(
        id: payload['id']?.toString() ?? uuid.v4(),
        conversationId: payload['conversationId']?.toString() ?? '',
        senderId: payload['senderId']?.toString() ?? '',
        senderName:
            payload['senderName']?.toString() ??
            payload['senderId']?.toString() ??
            'Unknown',
        receiverId: payload['receiverId']?.toString() ?? userId,
        content: 'Voice message',
        messageType: MessageType.voice,
        status: MessageStatus.delivered,
        timestamp:
            DateTime.tryParse(payload['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        metadata: {
          'messageType': 'voice',
          'audioPath': audioPath,
          'duration': payload['duration'],
          'fileSize': payload['fileSize'],
          'codec': payload['codec'],
          'bitrate': payload['bitrate'],
        },
      );

      _messageController.add(message);
      sendDeliveryReceipt(message.id, message.senderId);
    } catch (e) {
      // Error handled: failed to process incoming voice message
    }
  }

  Future<String> _persistIncomingVoiceMessage({
    required String messageId,
    required String audioData,
    required String codec,
  }) async {
    if (audioData.isEmpty) {
      throw Exception('Missing audio payload');
    }

    final bytes = base64Decode(audioData);
    final extension = codec == 'wav' ? 'wav' : 'opus';
    final file = File(
      '${Directory.systemTemp.path}/incoming_voice_$messageId.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Decrypt message asynchronously
  void _decryptMessageAsync(ChatMessage message) async {
    try {
      final decrypted = await _encryptionService.decryptMessage(
        message.content,
        _encryptionKeys[message.senderId]!.codeUnits,
      );
      message.content = decrypted;
      message.encryptionStatus = EncryptionStatus.decrypted;
    } catch (e) {
      message.encryptionStatus = EncryptionStatus.failed;
      // Decryption error handled
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String conversationId, String recipientId) {
    socket.emit('typing', {
      'conversationId': conversationId,
      'senderId': userId,
      'senderName': userName,
      'recipientId': recipientId,
    });
  }

  /// Handle typing status
  void _handleTypingStatus(dynamic data) {
    try {
      final status = TypingStatus.fromJson(data);
      _typingStatusController.add(status);
      _typingTimestamps[status.senderId] = DateTime.now();
    } catch (e) {
      // Error handled: failed to process typing status
    }
  }

  /// Stop typing indicator
  void stopTypingIndicator(String conversationId, String recipientId) {
    socket.emit('stopTyping', {
      'conversationId': conversationId,
      'senderId': userId,
      'recipientId': recipientId,
    });
  }

  /// Send delivery receipt
  void sendDeliveryReceipt(String messageId, String senderId) {
    socket.emit('deliveryReceipt', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle delivery receipt
  void _handleDeliveryReceipt(dynamic data) {
    try {
      final receipt = DeliveryReceipt.fromJson(data);
      _deliveryReceiptController.add(receipt);
    } catch (e) {
      // Error handled: failed to process delivery receipt
    }
  }

  /// Send read receipt
  void sendReadReceipt(String messageId, String senderId) {
    socket.emit('readReceipt', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle read receipt
  void _handleReadReceipt(dynamic data) {
    try {
      final receipt = ReadReceipt.fromJson(data);
      _readReceiptController.add(receipt);
    } catch (e) {
      // Error handled: failed to process read receipt
    }
  }

  /// Set encryption key for a participant
  Future<void> setEncryptionKeyForParticipant(
    String participantId,
    List<int> keyBytes,
  ) async {
    if (_encryptionService.isValidKey(keyBytes)) {
      _encryptionKeys[participantId] = String.fromCharCodes(keyBytes);
    }
  }

  /// Sync offline messages when connection is restored
  Future<void> _syncOfflineMessages() async {
    try {
      final queuedMessages = await _offlineQueue.syncQueue();

      for (final message in queuedMessages) {
        socket.emit('syncMessage', message.toJson());
      }
    } catch (e) {
      // Error handled: failed to sync offline messages
    }
  }

  /// Get message stream
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Get typing status stream
  Stream<TypingStatus> get typingStatusStream => _typingStatusController.stream;

  /// Get delivery receipt stream
  Stream<DeliveryReceipt> get deliveryReceiptStream =>
      _deliveryReceiptController.stream;

  /// Get read receipt stream
  Stream<ReadReceipt> get readReceiptStream => _readReceiptController.stream;

  /// Get connection status stream
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Cleanup
  Future<void> dispose() async {
    await disconnect();
    if (_isInitialized) {
      socket.dispose();
    }
    _messageController.close();
    _typingIndicatorController.close();
    _typingStatusController.close();
    _deliveryReceiptController.close();
    _readReceiptController.close();
    _connectionStatusController.close();
    _offlineQueue.dispose();
    _retryService.dispose();
  }
}

/// Model for typing status
class TypingStatus {
  final String conversationId;
  final String senderId;
  final String senderName;
  final String recipientId;
  final DateTime timestamp;

  TypingStatus({
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.timestamp,
  });

  factory TypingStatus.fromJson(Map<String, dynamic> json) => TypingStatus(
    conversationId: json['conversationId'] ?? '',
    senderId: json['senderId'] ?? '',
    senderName: json['senderName'] ?? '',
    recipientId: json['recipientId'] ?? '',
    timestamp: DateTime.parse(
      json['timestamp'] ?? DateTime.now().toIso8601String(),
    ),
  );
}

/// Model for delivery receipt
class DeliveryReceipt {
  final String messageId;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;

  DeliveryReceipt({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
  });

  factory DeliveryReceipt.fromJson(Map<String, dynamic> json) =>
      DeliveryReceipt(
        messageId: json['messageId'] ?? '',
        senderId: json['senderId'] ?? '',
        receiverId: json['receiverId'] ?? '',
        timestamp: DateTime.parse(
          json['timestamp'] ?? DateTime.now().toIso8601String(),
        ),
      );
}

/// Model for read receipt
class ReadReceipt {
  final String messageId;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;

  ReadReceipt({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) => ReadReceipt(
    messageId: json['messageId'] ?? '',
    senderId: json['senderId'] ?? '',
    receiverId: json['receiverId'] ?? '',
    timestamp: DateTime.parse(
      json['timestamp'] ?? DateTime.now().toIso8601String(),
    ),
  );
}
