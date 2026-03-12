import 'package:flutter/material.dart';
import 'api_client.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final TeleMedicineApiClient api;

  const ChatListScreen({super.key, required this.api});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    final resp = await widget.api.getMyChats();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _chats = resp.data!;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('No chats yet'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final c = _chats[index];
                    final chatId = c['chatId'] ?? c['id'] ?? '';
                    final participants = (c['participants'] as List?)?.cast<String>() ?? [];
                    final nameMap = (c['participantNames'] as Map?)?.cast<String, dynamic>() ?? {};
                    final otherIds = participants.where((p) => p != widget.api.currentUserId).toList();
                    final otherNames = otherIds.map((id) {
                      final n = nameMap[id]?.toString() ?? '';
                      return n.isNotEmpty && n != id ? n : 'User';
                    }).join(', ');
                    final msgs = c['messages'] as List?;
                    final lastMsg = (msgs?.isNotEmpty == true) ? (msgs!.last['text'] ?? '') : '';
                    return ListTile(
                      title: Text(otherNames.isNotEmpty ? otherNames : 'Conversation'),
                      subtitle: Text(lastMsg ?? ''),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(api: widget.api, chatId: chatId),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
