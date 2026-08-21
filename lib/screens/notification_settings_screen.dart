import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  bool _enabled = true;
  bool _communityAlerts = true;
  bool _marketplace = true;
  bool _providerUpdates = true;
  bool _messages = true;
  bool _deviceEnabled = true;
  bool _checkingDevice = true;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshDeviceStatus();
  }

  Future<void> _load() async {
    try {
      final settings = await NotificationService.instance
          .loadNotificationSettings();
      if (!mounted) return;
      setState(() {
        _enabled = settings['enabled'] ?? true;
        _communityAlerts = settings['communityAlerts'] ?? true;
        _marketplace = settings['marketplace'] ?? true;
        _providerUpdates = settings['providerUpdates'] ?? true;
        _messages = settings['messages'] ?? true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load notification settings: $e')),
      );
    }
  }

  Future<void> _refreshDeviceStatus() async {
    final enabled = await NotificationService.instance
        .areDeviceNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _deviceEnabled = enabled;
      _checkingDevice = false;
    });
  }

  Future<void> _enableDeviceNotifications() async {
    setState(() => _checkingDevice = true);
    try {
      final enabled = await NotificationService.instance
          .enableDeviceNotifications();
      if (!mounted) return;
      setState(() => _deviceEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Device notifications are enabled.'
                : 'Notifications are blocked. Open your phone Settings > Apps > Mataheko > Notifications and turn them on.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingDevice = false);
    }
  }

  Future<void> _save(String key, bool value) async {
    setState(() => _saving = true);
    try {
      await NotificationService.instance.saveNotificationSettings({
        key: value,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save notification setting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAll(bool value) async {
    setState(() {
      _enabled = value;
      if (value) {
        _communityAlerts = true;
        _marketplace = true;
        _providerUpdates = true;
        _messages = true;
      } else {
        _communityAlerts = false;
        _marketplace = false;
        _providerUpdates = false;
        _messages = false;
      }
      _saving = true;
    });
    try {
      await NotificationService.instance.saveNotificationSettings({
        'enabled': _enabled,
        'communityAlerts': _communityAlerts,
        'marketplace': _marketplace,
        'providerUpdates': _providerUpdates,
        'messages': _messages,
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: _enabled,
              onChanged: _saving ? null : _setAll,
              title: const Text(
                'Allow notifications',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Turn Mataheko notifications on or off.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SettingTile(
            icon: Icons.campaign_outlined,
            title: 'Community alerts',
            subtitle: 'Safety, power, water, traffic and local alerts.',
            value: _communityAlerts,
            enabled: _enabled && !_saving,
            onChanged: (v) {
              setState(() => _communityAlerts = v);
              _save('communityAlerts', v);
            },
          ),
          _SettingTile(
            icon: Icons.storefront_outlined,
            title: 'Marketplace',
            subtitle: 'Marketplace updates and listing activity.',
            value: _marketplace,
            enabled: _enabled && !_saving,
            onChanged: (v) {
              setState(() => _marketplace = v);
              _save('marketplace', v);
            },
          ),
          _SettingTile(
            icon: Icons.verified_user_outlined,
            title: 'Provider updates',
            subtitle: 'Provider registration and verification updates.',
            value: _providerUpdates,
            enabled: _enabled && !_saving,
            onChanged: (v) {
              setState(() => _providerUpdates = v);
              _save('providerUpdates', v);
            },
          ),
          _SettingTile(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: 'Messages and conversation notifications.',
            value: _messages,
            enabled: _enabled && !_saving,
            onChanged: (v) {
              setState(() => _messages = v);
              _save('messages', v);
            },
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: Icon(
                _deviceEnabled ? Icons.notifications_active : Icons.notifications_off,
              ),
              title: const Text(
                'Device notifications',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _checkingDevice
                    ? 'Checking device permission…'
                    : (_deviceEnabled
                        ? 'Enabled on this device'
                        : 'Blocked by device settings'),
              ),
              trailing: OutlinedButton(
                onPressed: (_saving || _checkingDevice)
                    ? null
                    : _enableDeviceNotifications,
                child: Text(_deviceEnabled ? 'Check' : 'Enable'),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Your phone may still show a system notification when a message is delivered directly by Android/iOS. For complete server-side suppression, the FCM sender must also honor these preferences.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
