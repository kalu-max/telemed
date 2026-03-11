import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  int _lastKnownCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await widget.api.getNotifications();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      final newNotes = resp.data!;
      // Show local notification for each new item
      if (newNotes.length > _lastKnownCount && _lastKnownCount > 0) {
        final newCount = newNotes.length - _lastKnownCount;
        for (var i = 0; i < newCount; i++) {
          final n = newNotes[i];
          NotificationService.instance.show(
            title: 'New Notification',
            body: n['message'] as String? ?? 'You have a new notification',
            id: DateTime.now().millisecondsSinceEpoch % 100000 + i,
          );
        }
      }
      _lastKnownCount = newNotes.length;
      setState(() {
        _notes = newNotes;
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _loading = false;
        _error = resp.error ?? 'Failed to load notifications';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notes.isEmpty
                  ? const Center(child: Text('No notifications'))
                  : ListView.separated(
                      itemCount: _notes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = _notes[index];
                        final message = n['message'] as String? ?? 'No message';
                        final timestamp = n['timestamp'];
                        final displayTime = timestamp != null ? timestamp.toString() : 'Unknown time';
                        return ListTile(
                          title: Text(message),
                          subtitle: Text(displayTime),
                        );
                      },
                    ),
    );
  }
}
