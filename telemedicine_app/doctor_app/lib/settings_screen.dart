import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'user_storage_service.dart';
import 'config/app_config.dart';
import 'config/server_config.dart';

class SettingsScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  final VoidCallback onLogout;

  const SettingsScreen({super.key, required this.api, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _serverUrl = AppConfig.apiBaseUrl;
  final _urlController = TextEditingController();
  List<Map<String, dynamic>> _availabilitySlots = [];
  bool _loadingSlots = false;

  static const _dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final doctorId = widget.api.currentUserId;
    if (doctorId == null) return;
    setState(() => _loadingSlots = true);
    final resp = await widget.api.getDoctorAvailability(doctorId);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      final slots = (resp.data!['slots'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() { _availabilitySlots = slots; _loadingSlots = false; });
    } else {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _addSlot() async {
    int? dayOfWeek;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Availability Slot'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  initialValue: dayOfWeek,
                  items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_dayNames[i]))),
                  onChanged: (v) => setDialogState(() => dayOfWeek = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Start: ${startTime.format(ctx)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: startTime);
                    if (t != null) setDialogState(() => startTime = t);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('End: ${endTime.format(ctx)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: endTime);
                    if (t != null) setDialogState(() => endTime = t);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: dayOfWeek != null ? () {
                  Navigator.pop(ctx, {
                    'dayOfWeek': dayOfWeek,
                    'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                    'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                    'slotDurationMinutes': 30,
                  });
                } : null,
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );

    if (result != null) {
      final newSlots = [..._availabilitySlots.map((s) => {
        'dayOfWeek': s['dayOfWeek'],
        'startTime': s['startTime'],
        'endTime': s['endTime'],
        'slotDurationMinutes': s['slotDurationMinutes'] ?? 30,
      }), result];
      
      final doctorId = widget.api.currentUserId;
      if (doctorId == null) return;
      final resp = await widget.api.updateDoctorAvailability(doctorId, newSlots);
      if (!mounted) return;
      if (resp.success) {
        _loadAvailability();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error?.toString() ?? 'Failed to update')));
      }
    }
  }

  Future<void> _removeSlot(int index) async {
    final newSlots = _availabilitySlots.asMap().entries
        .where((e) => e.key != index)
        .map((e) => {
          'dayOfWeek': e.value['dayOfWeek'],
          'startTime': e.value['startTime'],
          'endTime': e.value['endTime'],
          'slotDurationMinutes': e.value['slotDurationMinutes'] ?? 30,
        })
        .toList();

    final doctorId = widget.api.currentUserId;
    if (doctorId == null) return;
    final resp = await widget.api.updateDoctorAvailability(doctorId, newSlots);
    if (!mounted) return;
    if (resp.success) {
      _loadAvailability();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _serverUrl = prefs.getString('server_url') ?? AppConfig.apiBaseUrl;
      _urlController.text = _serverUrl;
    });
  }

  Future<void> _saveNotificationPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _saveServerUrl() async {
    final normalizedUrl = ServerConfig.normalizeUrl(_urlController.text);
    await ServerConfig.saveApiBaseUrl(normalizedUrl);
    if (!mounted) {
      return;
    }

    setState(() => _serverUrl = normalizedUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server URL saved. Sign out and sign in again to apply it everywhere.'),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account section
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text('Profile'),
                  subtitle: const Text('Edit your profile information'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to profile edit - handled by parent
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: const Text('Logout'),
                  subtitle: const Text('Sign out of your account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await UserStorageService.clearUserData();
                      widget.onLogout();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Availability section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Availability Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _addSlot,
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: 'Add time slot',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: _loadingSlots
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _availabilitySlots.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.schedule, color: Colors.grey[400], size: 40),
                              const SizedBox(height: 8),
                              Text('No availability set', style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text('Tap + to add your available hours', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _availabilitySlots.asMap().entries.map((entry) {
                          final i = entry.key;
                          final slot = entry.value;
                          final dayIdx = slot['dayOfWeek'] is int ? slot['dayOfWeek'] as int : 0;
                          final dayName = dayIdx >= 0 && dayIdx < 7 ? _dayNames[dayIdx] : 'Unknown';
                          return ListTile(
                            leading: const Icon(Icons.access_time, color: Colors.blue),
                            title: Text(dayName),
                            subtitle: Text('${slot['startTime']} - ${slot['endTime']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeSlot(i),
                            ),
                          );
                        }).toList(),
                      ),
          ),

          const SizedBox(height: 24),

          // Notifications section
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications, color: Colors.blue),
              title: const Text('Push Notifications'),
              subtitle: const Text('Get notified about new appointments'),
              value: _notificationsEnabled,
              onChanged: _saveNotificationPref,
            ),
          ),

          const SizedBox(height: 24),

          // Server section
          const Text(
            'Connection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Server URL', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: AppConfig.apiBaseUrl,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Change this to your backend server address for mobile use',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _saveServerUrl,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Danger zone
          const Text(
            'Danger Zone',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.red, width: 0.5),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently delete your account and data'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text(
                      'This action is irreversible. All your data, appointments, and patient records will be permanently deleted.',
                    ),
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
                );
                if (confirm == true) {
                  final resp = await widget.api.deleteDoctorAccount(widget.api.currentUserId ?? '');
                  if (!context.mounted) return;
                  if (resp.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(resp.message ?? 'Account deleted')),
                    );
                    await UserStorageService.clearUserData();
                    widget.onLogout();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(resp.error?.toString() ?? 'Deletion failed')),
                    );
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Column(
              children: [
                Text(
                  'Doctor Telemedicine v1.0.0',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  'MediCare Connect',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
