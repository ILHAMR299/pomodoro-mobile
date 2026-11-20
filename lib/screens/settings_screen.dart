import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/app_blocking_platform.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import 'app_blocking_screen.dart';
import 'add_task_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.user, required this.onLogout});
  final UserModel user;
  final Future<void> Function() onLogout;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = TaskService();
  bool _notificationsEnabled = true;
  int _defaultReminder = 60;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.preferences();
    if (mounted) {
      setState(() {
        _notificationsEnabled =
            (prefs['notifications_enabled'] as int? ?? 1) == 1;
        _defaultReminder = prefs['default_reminder_minutes'] as int? ?? 60;
        _loading = false;
      });
    }
  }

  Future<void> _setNotifications(bool enabled) async {
    setState(() => _saving = true);
    try {
      final saved = await _service.updatePreferences(
        userId: widget.user.id,
        notificationsEnabled: enabled,
        defaultReminderMinutes: _defaultReminder,
      );
      if (mounted) {
        if (saved) {
          setState(() => _notificationsEnabled = enabled);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin notifikasi belum diberikan. Pengingat tugas belum dapat ditampilkan.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan notifikasi belum dapat disimpan.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setDefaultReminder(int? minutes) async {
    if (minutes == null) return;
    setState(() {
      _defaultReminder = minutes;
      _saving = true;
    });
    try {
      await _service.updateDefaultReminder(minutes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan belum dapat disimpan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Akun dan daftar tugasmu tetap tersimpan di perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final navigator = Navigator.of(context);
    try {
      await widget.onLogout();
      if (navigator.mounted && navigator.canPop()) navigator.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum dapat keluar. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Notifikasi',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFFF8FCF8),
                elevation: 0,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Pengingat tenggat'),
                      subtitle: const Text(
                        'Izinkan pemberitahuan tugas di perangkat ini.',
                      ),
                      value: _notificationsEnabled,
                      onChanged: _saving ? null : _setNotifications,
                      activeTrackColor: AppTheme.green,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Pengingat bawaan'),
                      subtitle: Text(
                        reminderOptions[_defaultReminder] ??
                            'Atur pada setiap tugas',
                      ),
                      trailing: DropdownButton<int>(
                        value: _defaultReminder,
                        underline: const SizedBox.shrink(),
                        items: reminderOptions.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: _saving ? null : _setDefaultReminder,
                      ),
                    ),
                  ],
                ),
              ),
              if (AppBlockingPlatform.isSupported) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    'Fokus',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                      fontSize: 18,
                    ),
                  ),
                ),
                Card(
                  color: const Color(0xFFF8FCF8),
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(
                      Icons.phonelink_erase_outlined,
                      color: AppTheme.darkGreen,
                    ),
                    title: const Text('Pemblokiran Aplikasi'),
                    subtitle: const Text(
                      'Pilih aplikasi yang menampilkan pengingat selama fokus.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AppBlockingScreen(userId: widget.user.id),
                      ),
                    ),
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Tampilan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                    fontSize: 18,
                  ),
                ),
              ),
              Card(
                color: const Color(0xFFF8FCF8),
                elevation: 0,
                child: const ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: AppTheme.darkGreen,
                  ),
                  title: Text('Tema hijau lembut'),
                  subtitle: Text('Tampilan saat ini'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Akun',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                    fontSize: 18,
                  ),
                ),
              ),
              Card(
                color: const Color(0xFFF8FCF8),
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.softGreen,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      title: Text(widget.user.name),
                      subtitle: Text(widget.user.email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF9C3028),
                      ),
                      title: const Text(
                        'Keluar Akun',
                        style: TextStyle(color: Color(0xFF9C3028)),
                      ),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pengingat lokal dapat bergeser mengikuti pengaturan daya perangkat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.ink),
              ),
            ],
          ),
  );
}
