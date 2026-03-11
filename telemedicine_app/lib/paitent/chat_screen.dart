import 'package:flutter/material.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
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
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final resp = await widget.api.sendChatMessage(widget.chatId, text);
    if (!mounted) return;
    if (resp.success) {
      _controller.clear();
      _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error?.toString() ?? 'Send failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: false,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      return ListTile(
                        title: Text(m['text'] ?? ''),
                        subtitle: Text(m['senderId'] ?? ''),
                        dense: true,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Type a message'),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send))
              ],
            ),
          )
        ],
      ),
    );
  }
}
