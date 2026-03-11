import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';
import '../services/chat_encryption_service.dart';

class ChatScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  final String chatId;

  const ChatScreen({super.key, required this.api, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _otherTyping = false;
  Timer? _typingDebounce;
  io.Socket? _socket;
  String get _myId => widget.api.currentUserId ?? '';
  late final ChatEncryptionService _encryption;

  @override
  void initState() {
    super.initState();
    _encryption = ChatEncryptionService.fromSharedSecret(widget.chatId);
    _loadMessages();
    _connectSocket();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _socket?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _connectSocket() {
    try {
      final baseUrl = widget.api.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      _socket = io.io(baseUrl, io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': _myId, 'role': 'patient'})
          .enableAutoConnect()
          .build());

      _socket!.on('newMessage', (data) {
        if (!mounted) return;
        if (data is Map && data['chatId'] == widget.chatId) {
          final msg = Map<String, dynamic>.from(data);
          // Avoid duplicate if we sent it
          if (msg['senderId'] != _myId) {
            // Decrypt incoming text messages
            if (msg['messageType'] == 'text' && msg['text'] != null) {
              try {
                msg['text'] = _encryption.decrypt(msg['text']);
              } catch (_) {
                // Message may be unencrypted (legacy) — show as-is
              }
            }
            setState(() {
              _messages.add(msg);
            });
            _scrollToBottom();
          }
        }
      });

      _socket!.on('typing', (data) {
        if (!mounted) return;
        if (data is Map && data['chatId'] == widget.chatId && data['userId'] != _myId) {
          setState(() => _otherTyping = true);
          _typingDebounce?.cancel();
          _typingDebounce = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _otherTyping = false);
          });
        }
      });

      _socket!.on('stopTyping', (data) {
        if (!mounted) return;
        if (data is Map && data['chatId'] == widget.chatId) {
          setState(() => _otherTyping = false);
        }
      });
    } catch (_) {
      // Socket connection optional — REST fallback works
    }
  }

  void _emitTyping() {
    _socket?.emit('typing', {'chatId': widget.chatId, 'userId': _myId});
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final resp = await widget.api.getChatMessages(widget.chatId);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      // Decrypt text messages loaded from server
      final decrypted = resp.data!.map((msg) {
        if (msg['messageType'] == 'text' && msg['text'] != null) {
          try {
            msg['text'] = _encryption.decrypt(msg['text']);
          } catch (_) {
            // Message may be unencrypted (legacy) — show as-is
          }
        }
        return msg;
      }).toList();
      setState(() {
        _messages = decrypted;
        _loading = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    // Optimistic local add (show plaintext locally)
    final optimistic = {'senderId': _myId, 'text': text, 'messageType': 'text', 'timestamp': DateTime.now().toIso8601String()};
    setState(() => _messages.add(optimistic));
    _scrollToBottom();
    _socket?.emit('stopTyping', {'chatId': widget.chatId, 'userId': _myId});

    // Encrypt before sending to server
    final encrypted = _encryption.encrypt(text);
    final resp = await widget.api.sendChatMessage(widget.chatId, encrypted);
    if (!mounted) return;
    if (!resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error?.toString() ?? 'Send failed')));
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 75);
      if (picked == null || !mounted) return;
      final resp = await widget.api.sendChatMedia(widget.chatId, picked.path);
      if (!mounted) return;
      if (resp.success) {
        _loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error?.toString() ?? 'Upload failed')));
      }
    } catch (_) {}
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      if (file.path == null) return;
      final resp = await widget.api.sendChatFile(widget.chatId, file.path!);
      if (!mounted) return;
      if (resp.success) {
        _loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error?.toString() ?? 'Upload failed')));
      }
    } catch (_) {}
  }

  String _formatFileSize(dynamic bytes) {
    final size = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _searchResults = [];
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searchLoading = true);
    final resp = await widget.api.searchChatMessages(widget.chatId, query);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(resp.data!['messages'] ?? []);
        _searchLoading = false;
      });
    } else {
      setState(() => _searchLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _performSearch,
              )
            : const Text('Chat'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search results overlay
          if (_searching && _searchController.text.length >= 2)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              color: Colors.grey[100],
              child: _searchLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                  : _searchResults.isEmpty
                      ? const Padding(padding: EdgeInsets.all(12), child: Text('No results found'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) {
                            final r = _searchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(r['text']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(r['senderName']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                              leading: const Icon(Icons.message, size: 18),
                            );
                          },
                        ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isMe = m['senderId'] == _myId;
                      final isImage = m['messageType'] == 'image';
                      final isFile = m['messageType'] == 'file';
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: isImage && m['imageUrl'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network('${widget.api.baseUrl}${m['imageUrl']}', width: 200, fit: BoxFit.cover,
                                    errorBuilder: (_, e, s) => const Icon(Icons.broken_image)),
                                )
                              : isFile
                                ? InkWell(
                                    onTap: () {
                                      // Could open URL in browser/viewer
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.insert_drive_file, color: isMe ? Colors.white70 : Colors.grey[600], size: 20),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m['fileName'] ?? 'File',
                                                style: TextStyle(
                                                  color: isMe ? Colors.white : theme.colorScheme.onSurface,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (m['size'] != null)
                                                Text(
                                                  _formatFileSize(m['size']),
                                                  style: TextStyle(
                                                    color: isMe ? Colors.white60 : Colors.grey[500],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                  m['text'] ?? '',
                                  style: TextStyle(color: isMe ? Colors.white : theme.colorScheme.onSurface),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          if (_otherTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Align(alignment: Alignment.centerLeft, child: Text('typing...', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(onPressed: _pickAndSendImage, icon: const Icon(Icons.image_outlined)),
                IconButton(onPressed: _pickAndSendFile, icon: const Icon(Icons.attach_file)),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onChanged: (_) => _emitTyping(),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
