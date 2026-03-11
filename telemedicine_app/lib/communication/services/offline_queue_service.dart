import 'package:hive/hive.dart';
import 'dart:async';
import '../models/message_model.dart';

/// Service for managing offline message queue
/// Ensures messages are sent when connectivity is restored
class OfflineMessageQueueService {
  static const String _queueBoxName = 'messageQueue';
  late Box<ChatMessage> _queueBox;
  
  final StreamController<ChatMessage> _queuedMessageController = StreamController<ChatMessage>.broadcast();
  final StreamController<int> _queueSizeController = StreamController<int>.broadcast();
  
  bool _isInitialized = false;

  /// Initialize the offline queue service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      if (!Hive.isBoxOpen(_queueBoxName)) {
        _queueBox = await Hive.openBox<ChatMessage>(_queueBoxName);
      } else {
        _queueBox = Hive.box<ChatMessage>(_queueBoxName);
      }
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize offline queue: $e');
    }
  }

  /// Add a message to the offline queue
  Future<void> queueMessage(ChatMessage message) async {
    await initialize();
    
    try {
      final messageWithQueue = message
        ..status = MessageStatus.sending
        ..isSynced = false;
      
      await _queueBox.add(messageWithQueue);
      _queuedMessageController.add(messageWithQueue);
      _updateQueueSize();
    } catch (e) {
      throw Exception('Failed to queue message: $e');
    }
  }

  /// Get all queued messages
  Future<List<ChatMessage>> getQueuedMessages() async {
    await initialize();
    return _queueBox.values.toList();
  }

  /// Get queued messages for a specific conversation
  Future<List<ChatMessage>> getQueuedByConversation(String conversationId) async {
    await initialize();
    return _queueBox.values.where((msg) => msg.conversationId == conversationId).toList();
  }

  /// Remove message from queue (after successful send)
  Future<void> removeFromQueue(String messageId) async {
    await initialize();
    
    try {
      final index = _queueBox.values.toList().indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        await _queueBox.deleteAt(index);
        _updateQueueSize();
      }
    } catch (e) {
      throw Exception('Failed to remove message from queue: $e');
    }
  }

  /// Mark message as synced
  Future<void> markAsSynced(String messageId) async {
    await initialize();
    
    try {
      final messages = _queueBox.values.toList();
      final index = messages.indexWhere((msg) => msg.id == messageId);
      
      if (index != -1) {
        final message = messages[index];
        message.isSynced = true;
        message.status = MessageStatus.sent;
        await _queueBox.putAt(index, message);
        _updateQueueSize();
      }
    } catch (e) {
      throw Exception('Failed to mark message as synced: $e');
    }
  }

  /// Clear entire queue (use with caution)
  Future<void> clearQueue() async {
    await initialize();
    
    try {
      await _queueBox.clear();
      _updateQueueSize();
    } catch (e) {
      throw Exception('Failed to clear queue: $e');
    }
  }

  /// Get queue size
  Future<int> getQueueSize() async {
    await initialize();
    return _queueBox.length;
  }

  /// Check if queue is empty
  Future<bool> isQueueEmpty() async {
    final size = await getQueueSize();
    return size == 0;
  }

  /// Sync queue with server
  /// This should be called when connectivity is restored
  Future<List<ChatMessage>> syncQueue() async {
    await initialize();
    
    final queuedMessages = _queueBox.values.toList();
    return queuedMessages.where((msg) => !msg.isSynced).toList();
  }

  /// Update queue after successful sync
  Future<void> updateQueueAfterSync(List<String> successfulIds) async {
    await initialize();
    
    for (final id in successfulIds) {
      await markAsSynced(id);
    }
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getQueueStats() async {
    await initialize();
    
    final messages = _queueBox.values.toList();
    final totalSize = messages.fold<int>(0, (sum, msg) => sum + msg.content.length);
    
    return {
      'queuedMessageCount': messages.length,
      'unSyncedCount': messages.where((m) => !m.isSynced).length,
      'totalContentSize': totalSize,
      'oldestMessage': messages.isNotEmpty ? messages.first.timestamp : null,
      'newestMessage': messages.isNotEmpty ? messages.last.timestamp : null,
    };
  }

  /// Stream of queued messages
  Stream<ChatMessage> get queuedMessageStream => _queuedMessageController.stream;

  /// Stream of queue size changes
  Stream<int> get queueSizeStream => _queueSizeController.stream;

  /// Update queue size stream
  void _updateQueueSize() {
    _queueSizeController.add(_queueBox.length);
  }

  /// Cleanup resources
  void dispose() {
    _queuedMessageController.close();
    _queueSizeController.close();
  }
}

/// Service for handling message retry with exponential backoff
class MessageRetryService {
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);
  
  final Map<String, RetryState> _retryStates = {};
  final StreamController<String> _successController = StreamController<String>.broadcast();
  final StreamController<String> _failureController = StreamController<String>.broadcast();

  /// Add message for retry
  void addForRetry(String messageId, Future<bool> Function() sendFunction) {
    _retryStates[messageId] = RetryState(
      messageId: messageId,
      retryCount: 0,
      sendFunction: sendFunction,
      lastRetryTime: DateTime.now(),
    );
  }

  /// Process retry queue
  Future<void> processRetries() async {
    final entriesToRemove = <String>[];
    
    for (final entry in _retryStates.entries) {
      final state = entry.value;
      
      if (state.retryCount >= 3) {
        _failureController.add(entry.key);
        entriesToRemove.add(entry.key);
        continue;
      }

      final retryDelay = _calculateBackoffDelay(state.retryCount);
      final timeSinceLastRetry = DateTime.now().difference(state.lastRetryTime);

      if (timeSinceLastRetry.compareTo(retryDelay) >= 0) {
        try {
          final success = await state.sendFunction();
          
          if (success) {
            _successController.add(entry.key);
            entriesToRemove.add(entry.key);
          } else {
            state.retryCount++;
            state.lastRetryTime = DateTime.now();
          }
        } catch (e) {
          state.retryCount++;
          state.lastRetryTime = DateTime.now();
        }
      }
    }

    for (final id in entriesToRemove) {
      _retryStates.remove(id);
    }
  }

  /// Calculate exponential backoff delay
  Duration _calculateBackoffDelay(int retryCount) {
    return Duration(
      seconds: (initialRetryDelay.inSeconds * (2 ^ retryCount)).toInt(),
    );
  }

  /// Stream of successful message sends
  Stream<String> get successStream => _successController.stream;

  /// Stream of failed message sends
  Stream<String> get failureStream => _failureController.stream;

  /// Cleanup
  void dispose() {
    _successController.close();
    _failureController.close();
  }
}

/// State holder for retry tracking
class RetryState {
  final String messageId;
  int retryCount;
  final Future<bool> Function() sendFunction;
  DateTime lastRetryTime;

  RetryState({
    required this.messageId,
    required this.retryCount,
    required this.sendFunction,
    required this.lastRetryTime,
  });
}
