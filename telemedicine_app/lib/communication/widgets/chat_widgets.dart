import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/message_model.dart';
import '../providers/communication_providers.dart';
import 'call_widgets.dart';
import 'audio_call_screen.dart';
import '../../paitent/doctor_service.dart';
import '../../paitent/doctor_model.dart';

/// Chat conversation screen with WhatsApp-like UI
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String participantId;
  final String participantName;
  final String? participantAvatarUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.participantId,
    required this.participantName,
    this.participantAvatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController _messageController;
  bool _isTyping = false;
  bool _isSendingAttachment = false;
  late MessagingProvider _messagingProvider;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messagingProvider = context.read<MessagingProvider>();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messagingProvider.sendTextMessage(
      conversationId: widget.conversationId,
      receiverId: widget.participantId,
      receiverName: widget.participantName,
      content: content,
    );

    _messageController.clear();
    _isTyping = false;
    setState(() {});
  }

  void _onMessageChanged(String text) {
    final wasTyping = _isTyping;
    _isTyping = text.isNotEmpty;

    if (_isTyping && !wasTyping) {
      _messagingProvider.messagingService.sendTypingIndicator(
        widget.conversationId,
        widget.participantId,
      );
    } else if (!_isTyping && wasTyping) {
      _messagingProvider.messagingService.stopTypingIndicator(
        widget.conversationId,
        widget.participantId,
      );
    }
  }

  void _startAudioCall() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioCallScreen(
            recipientId: widget.participantId,
            recipientName: widget.participantName,
            conversationId: widget.conversationId,
          ),
        ),
      );
    }
  }

  void _startVideoCall() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            recipientId: widget.participantId,
            recipientName: widget.participantName,
            conversationId: widget.conversationId,
          ),
        ),
      );
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[50],
                  child: Icon(Icons.photo_library, color: Colors.purple[700]),
                ),
                title: const Text('Photo from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.camera_alt, color: Colors.blue[700]),
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[50],
                  child: Icon(Icons.attach_file, color: Colors.orange[700]),
                ),
                title: const Text('Document / File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final ext = xfile.name.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      setState(() => _isSendingAttachment = true);
      _messagingProvider.messagingService.sendMessage(
        conversationId: widget.conversationId,
        receiverId: widget.participantId,
        receiverName: widget.participantName,
        content: dataUri,
        metadata: {'messageType': 'image', 'filename': xfile.name},
        encrypt: false,
      ).then((_) {
        if (mounted) setState(() => _isSendingAttachment = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;
      final ext = (file.extension ?? '').toLowerCase();
      final mime = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      setState(() => _isSendingAttachment = true);
      _messagingProvider.messagingService.sendMessage(
        conversationId: widget.conversationId,
        receiverId: widget.participantId,
        receiverName: widget.participantName,
        content: dataUri,
        metadata: {'messageType': 'file', 'filename': file.name, 'size': bytes.length},
        encrypt: false,
      ).then((_) {
        if (mounted) setState(() => _isSendingAttachment = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: SizedBox(
          width: MediaQuery.of(context).size.width - 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.participantName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Consumer<MessagingProvider>(
                builder: (context, provider, _) {
                  final isTyping = provider.isUserTyping(widget.participantId);
                  return Text(
                    isTyping ? 'typing...' : 'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Voice Call',
            onPressed: () => _startAudioCall(),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video Call',
            onPressed: () => _startVideoCall(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, _) {
                final messages = provider.getConversationMessages(widget.conversationId);
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          // Message input area with quick actions
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                // Quick action buttons (visible on long press or always on web)
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickActionButton(
                          Icons.videocam,
                          'Video Call',
                          Colors.teal,
                          _startVideoCall,
                        ),
                        _buildQuickActionButton(
                          Icons.call,
                          'Voice Call',
                          Colors.green,
                          _startAudioCall,
                        ),
                      ],
                    ),
                  ),
                // Message input
                Row(
                  children: [
                    _isSendingAttachment
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.attach_file),
                            tooltip: 'Attachments',
                            onPressed: _showAttachmentMenu,
                          ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: _onMessageChanged,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: _sendMessage,
                      tooltip: 'Send',
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat bubble widget for individual messages
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isOwn = message.senderId == context.read<MessagingProvider>().messagingService.userId;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOwn ? Colors.teal[600] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildMessageContent(isOwn),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    color: isOwn ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                if (isOwn) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(bool isOwn) {
    final meta = message.metadata;
    final metaType = meta?['messageType'] as String? ?? '';

    // Image message
    if (metaType == 'image' || message.content.startsWith('data:image/')) {
      try {
        final dataUri = message.content;
        final base64Data = dataUri.contains(',') ? dataUri.split(',')[1] : dataUri;
        final bytes = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
          ),
        );
      } catch (_) {
        return Text('[Image]', style: TextStyle(color: isOwn ? Colors.white : Colors.black87));
      }
    }

    // File message
    if (metaType == 'file' || message.content.startsWith('data:application/')) {
      final filename = meta?['filename'] as String? ?? 'File';
      final size = meta?['size'] as int?;
      final sizeLabel = size != null ? ' (${(size / 1024).toStringAsFixed(1)} KB)' : '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: isOwn ? Colors.white : Colors.grey[700], size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: TextStyle(
                    color: isOwn ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeLabel.isNotEmpty)
                  Text(
                    sizeLabel,
                    style: TextStyle(color: isOwn ? Colors.white70 : Colors.black54, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Default text message
    return Text(
      message.content,
      style: TextStyle(
        color: isOwn ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule;
        color = Colors.white70;
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = Colors.white70;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white70;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.lightBlue;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
        color = Colors.white70;
        break;
    }

    return Icon(icon, size: 12, color: color);
  }
}

/// Conversation list screen with messaging capabilities
class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  void _showNewConversationDialog() {
    final doctorService = context.read<DoctorService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a doctor to start messaging',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: FutureBuilder<List<DoctorProfile>>(
                  future: doctorService.fetchAvailableDoctors(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No doctors available right now'),
                      );
                    }
                    final doctors = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: doctors.length,
                      itemBuilder: (context, index) {
                        final doc = doctors[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(doc.name.isNotEmpty ? doc.name[0] : '?'),
                          ),
                          title: Text(doc.name),
                          subtitle: Text(doc.specialties.join(', ')),
                          trailing: Text('${doc.rating.toStringAsFixed(1)} ★'),
                          onTap: () {
                            Navigator.pop(context);
                            final conversationId = 'conv-${doc.id}-${DateTime.now().millisecondsSinceEpoch}';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  conversationId: conversationId,
                                  participantId: doc.id,
                                  participantName: doc.name,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search dialog
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show menu
            },
          ),
        ],
      ),
      body: Consumer<MessagingProvider>(
        builder: (context, provider, _) {
          final conversations = provider.getAllConversations();

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ConversationTile(conversation: conversation);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        tooltip: 'Start new conversation',
        child: const Icon(Icons.message),
      ),
    );
  }
}

/// Conversation list tile
class ConversationTile extends StatelessWidget {
  final Conversation conversation;

  const ConversationTile({
    super.key,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: conversation.participantAvatarUrl != null
            ? NetworkImage(conversation.participantAvatarUrl!)
            : null,
        child: conversation.participantAvatarUrl == null
            ? Text(conversation.participantName[0].toUpperCase())
            : null,
      ),
      title: Text(
        conversation.participantName,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('HH:mm').format(conversation.lastMessageTime),
              style: const TextStyle(fontSize: 12),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
      onTap: () {
        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              participantId: conversation.participantId,
              participantName: conversation.participantName,
              participantAvatarUrl: conversation.participantAvatarUrl,
            ),
          ),
        );
      },
    );
  }
}
