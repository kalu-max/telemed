import 'package:flutter/material.dart';
import 'api_client.dart';

class AdminDashboard extends StatefulWidget {
  final TeleMedicineApiClient api;

  const AdminDashboard({super.key, required this.api});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;
  String? _error;

  final TextEditingController _messageController = TextEditingController();
  String _target = 'all';
  final List<String> _targets = ['all', 'doctors', 'patients'];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _error = null;
    });
    final resp = await widget.api.getAllUsers();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _users = resp.data!;
        _loadingUsers = false;
      });
    } else {
      setState(() {
        _error = resp.error?.toString() ?? 'Failed to load users';
        _loadingUsers = false;
      });
    }
  }

  Future<void> _deleteUser(String userId) async {
    final resp = await widget.api.adminDeleteUser(userId);
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User removed')),
      );
      _loadUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error?.toString() ?? 'Deletion failed')),
      );
    }
  }

  Future<void> _sendNotification() async {
    if (_messageController.text.isEmpty) return;
    setState(() => _sending = true);
    final resp = await widget.api.adminSendNotification(
      target: _target,
      message: _messageController.text.trim(),
    );
    setState(() => _sending = false);
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent')),
      );
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error?.toString() ?? 'Send failed')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel'), actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadUsers,
        ),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send Notification', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _target,
                      items: _targets
                          .map((t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          ))
                          .toList(),
                      onChanged: (v) => setState(() => _target = v ?? 'all'),
                      decoration: const InputDecoration(labelText: 'Target'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(labelText: 'Message'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _sending ? null : _sendNotification,
                      child: _sending ? const CircularProgressIndicator() : const Text('Send'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            return Card(
                              child: ListTile(
                                title: Text(u['email'] ?? ''),
                                subtitle: Text(u['role'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Remove user?'),
                                        content: Text('Delete ${u['email']}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    ).then((confirmed) {
                                      if (confirmed == true) _deleteUser(u['userId']);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
