import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'user_storage_service.dart';
import 'config/app_config.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
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
