import 'package:hive/hive.dart';

// Note: Hive generation removed - use manual serialization

/// Enumeration for message types
enum MessageType {
  text,
  voice,
  image,
  video,
  file,
  system
}

/// Enumeration for message delivery status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed
}

/// Enumeration for message encryption status
enum EncryptionStatus {
  encrypted,
  decrypted,
  unencrypted,
  failed
}

/// Hive model for chat messages
@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String conversationId;

  @HiveField(2)
  late String senderId;

  @HiveField(3)
  late String senderName;

  @HiveField(4)
  late String receiverId;

  @HiveField(5)
  late String content;

  @HiveField(6)
  late MessageType messageType;

  @HiveField(7)
  late MessageStatus status;

  @HiveField(8)
  late DateTime timestamp;

  @HiveField(9)
  late DateTime? readAt;

  @HiveField(10)
  late DateTime? deliveredAt;

  @HiveField(11)
  late Map<String, dynamic>? metadata;

  @HiveField(12)
  late String? encryptionKey;

  @HiveField(13)
  late EncryptionStatus encryptionStatus;

  @HiveField(14)
  late bool isSynced;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.content,
    this.messageType = MessageType.text,
    this.status = MessageStatus.sending,
    required this.timestamp,
    this.readAt,
    this.deliveredAt,
    this.metadata,
    this.encryptionKey,
    this.encryptionStatus = EncryptionStatus.unencrypted,
    this.isSynced = false,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'content': content,
        'messageType': messageType.toString().split('.').last,
        'status': status.toString().split('.').last,
        'timestamp': timestamp.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
        'metadata': metadata,
        'encryptionStatus': encryptionStatus.toString().split('.').last,
      };

  /// Create from JSON response
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        conversationId: json['conversationId'] ?? '',
        senderId: json['senderId'] ?? '',
        senderName: json['senderName'] ?? '',
        receiverId: json['receiverId'] ?? '',
        content: json['content'] ?? '',
        messageType: _parseMessageType(json['messageType'] ?? 'text'),
        status: _parseMessageStatus(json['status'] ?? 'sending'),
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
        deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
        metadata: json['metadata'],
        encryptionStatus: _parseEncryptionStatus(json['encryptionStatus'] ?? 'unencrypted'),
      );

  static MessageType _parseMessageType(String type) {
    switch (type) {
      case 'voice':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sending;
    }
  }

  static EncryptionStatus _parseEncryptionStatus(String status) {
    switch (status) {
      case 'encrypted':
        return EncryptionStatus.encrypted;
      case 'decrypted':
        return EncryptionStatus.decrypted;
      case 'failed':
        return EncryptionStatus.failed;
      default:
        return EncryptionStatus.unencrypted;
    }
  }
}

/// Model for voice messages
@HiveType(typeId: 1)
class VoiceMessage extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String messageId;

  @HiveField(2)
  late String audioPath;

  @HiveField(3)
  late Duration duration;

  @HiveField(4)
  late int fileSize;

  @HiveField(5)
  late String codec; // 'opus' recommended

  @HiveField(6)
  late int bitrate; // e.g., 24000

  @HiveField(7)
  late String waveformData; // serialized waveform for visualization

  VoiceMessage({
    required this.id,
    required this.messageId,
    required this.audioPath,
    required this.duration,
    required this.fileSize,
    this.codec = 'opus',
    this.bitrate = 24000,
    this.waveformData = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'messageId': messageId,
        'audioPath': audioPath,
        'duration': duration.inMilliseconds,
        'fileSize': fileSize,
        'codec': codec,
        'bitrate': bitrate,
        'waveformData': waveformData,
      };

  factory VoiceMessage.fromJson(Map<String, dynamic> json) => VoiceMessage(
        id: json['id'] ?? '',
        messageId: json['messageId'] ?? '',
        audioPath: json['audioPath'] ?? '',
        duration: Duration(milliseconds: json['duration'] ?? 0),
        fileSize: json['fileSize'] ?? 0,
        codec: json['codec'] ?? 'opus',
        bitrate: json['bitrate'] ?? 24000,
        waveformData: json['waveformData'] ?? '',
      );
}

/// Model for conversations
@HiveType(typeId: 2)
class Conversation extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String participantId;

  @HiveField(2)
  late String participantName;

  @HiveField(3)
  late String? participantAvatarUrl;

  @HiveField(4)
  late DateTime lastMessageTime;

  @HiveField(5)
  late String lastMessage;

  @HiveField(6)
  late int unreadCount;

  @HiveField(7)
  late bool isMuted;

  @HiveField(8)
  late bool isArchived;

  @HiveField(9)
  late List<String> participantIds; // For group conversations

  Conversation({
    required this.id,
    required this.participantId,
    required this.participantName,
    this.participantAvatarUrl,
    required this.lastMessageTime,
    this.lastMessage = '',
    this.unreadCount = 0,
    this.isMuted = false,
    this.isArchived = false,
    List<String>? participantIds,
  }) : participantIds = participantIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'participantId': participantId,
        'participantName': participantName,
        'participantAvatarUrl': participantAvatarUrl,
        'lastMessageTime': lastMessageTime.toIso8601String(),
        'lastMessage': lastMessage,
        'unreadCount': unreadCount,
        'isMuted': isMuted,
        'isArchived': isArchived,
        'participantIds': participantIds,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] ?? '',
        participantId: json['participantId'] ?? '',
        participantName: json['participantName'] ?? '',
        participantAvatarUrl: json['participantAvatarUrl'],
        lastMessageTime: DateTime.parse(json['lastMessageTime'] ?? DateTime.now().toIso8601String()),
        lastMessage: json['lastMessage'] ?? '',
        unreadCount: json['unreadCount'] ?? 0,
        isMuted: json['isMuted'] ?? false,
        isArchived: json['isArchived'] ?? false,
        participantIds: List<String>.from(json['participantIds'] ?? []),
      );
}
