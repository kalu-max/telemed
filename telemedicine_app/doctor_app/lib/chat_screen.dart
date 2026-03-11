import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectSocket();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _socket?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _connectSocket() {
    try {
      final baseUrl = widget.api.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      _socket = io.io(baseUrl, io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': _myId, 'role': 'doctor'})
          .enableAutoConnect()
          .build());

      _socket!.on('newMessage', (data) {
        if (!mounted) return;
        if (data is Map && data['chatId'] == widget.chatId) {
          final msg = Map<String, dynamic>.from(data);
          if (msg['senderId'] != _myId) {
            setState(() => _messages.add(msg));
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
    } catch (_) {}
  }

  void _emitTyping() {
    _socket?.emit('typing', {'chatId': widget.chatId, 'userId': _myId});
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final resp = await widget.api.getChatMessages(widget.chatId);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _messages = resp.data!;
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
    final optimistic = {'senderId': _myId, 'text': text, 'messageType': 'text', 'timestamp': DateTime.now().toIso8601String()};
    setState(() => _messages.add(optimistic));
    _scrollToBottom();
    _socket?.emit('stopTyping', {'chatId': widget.chatId, 'userId': _myId});

    final resp = await widget.api.sendChatMessage(widget.chatId, text);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
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
                IconButton(onPressed: _pickAndSendImage, icon: const Icon(Icons.attach_file)),
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
