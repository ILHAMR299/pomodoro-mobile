import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/installed_application.dart';
import '../services/app_blocking_platform.dart';
import '../theme/app_theme.dart';

class AppBlockingScreen extends StatefulWidget {
  const AppBlockingScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AppBlockingScreen> createState() => _AppBlockingScreenState();
}

class _AppBlockingScreenState extends State<AppBlockingScreen>
    with WidgetsBindingObserver {
  final _database = DatabaseHelper.instance;
  List<InstalledApplication> _applications = const [];
  Set<String> _selectedPackages = {};
  bool _usageAccess = false;
  bool _overlayAccess = false;
  bool _notificationAccess = false;
  bool _enabled = false;
  bool _blockDuringBreaks = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        AppBlockingPlatform.installedApplications(),
        _database.blockedApplications(widget.userId),
        _database.appBlockingSettings(widget.userId),
        AppBlockingPlatform.hasUsageAccess(),
        AppBlockingPlatform.canDrawOverlays(),
        AppBlockingPlatform.hasNotificationPermission(),
      ]);
      final savedApps = results[1] as List<Map<String, Object?>>;
      final settings = results[2] as Map<String, Object?>;
      if (!mounted) return;
      setState(() {
        _applications = results[0] as List<InstalledApplication>;
        _selectedPackages = savedApps
            .where((app) => (app['is_enabled'] as int) == 1)
            .map((app) => app['package_name'] as String)
            .toSet();
        _enabled = (settings['is_enabled'] as int? ?? 0) == 1;
        _blockDuringBreaks =
            (settings['block_during_breaks'] as int? ?? 0) == 1;
        _usageAccess = results[3] as bool;
        _overlayAccess = results[4] as bool;
        _notificationAccess = results[5] as bool;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Data pemblokiran belum dapat dimuat.';
        _loading = false;
      });
    }
  }

  Future<void> _refreshPermissions() async {
    try {
      final statuses = await Future.wait<bool>([
        AppBlockingPlatform.hasUsageAccess(),
        AppBlockingPlatform.canDrawOverlays(),
        AppBlockingPlatform.hasNotificationPermission(),
      ]);
      if (!mounted) return;
      setState(() {
        _usageAccess = statuses[0];
        _overlayAccess = statuses[1];
        _notificationAccess = statuses[2];
      });
    } catch (_) {
      // Permission status remains as last read; the next Settings visit retries.
    }
  }

  Future<void> _setApplication(InstalledApplication app, bool selected) async {
    setState(() => _saving = true);
    try {
      await _database.setBlockedApplication(
        userId: widget.userId,
        packageName: app.packageName,
        appName: app.appName,
        enabled: selected,
      );
      if (mounted) {
        setState(() {
          if (selected) {
            _selectedPackages.add(app.packageName);
          } else {
            _selectedPackages.remove(app.packageName);
          }
        });
      }
    } catch (_) {
      _showMessage('Pilihan aplikasi belum dapat disimpan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!enabled) {
      await _saveSettings(enabled: false);
      await AppBlockingPlatform.stopMonitoring();
      return;
    }
    if (_selectedPackages.isEmpty) {
      _showMessage('Pilih minimal satu aplikasi terlebih dahulu.');
      return;
    }
    if (!await _requestRequiredAccess()) return;
    await _saveSettings(enabled: true);
  }

  Future<bool> _requestRequiredAccess() async {
    if (!_usageAccess) {
      final open = await _explainPermission(
        title: 'Akses penggunaan aplikasi',
        explanation: 'FocusMaxx memeriksa aplikasi yang sedang terbuka hanya selama sesi fokus agar dapat mengenali aplikasi pilihanmu.',
        action: 'Buka pengaturan akses penggunaan',
      );
      if (open == true) await AppBlockingPlatform.openUsageAccessSettings();
      await _refreshPermissions();
      if (!_usageAccess) return false;
    }
    if (!_overlayAccess) {
      final open = await _explainPermission(
        title: 'Tampilkan di atas aplikasi lain',
        explanation: 'Izin ini dipakai untuk menampilkan pengingat FocusMaxx di atas aplikasi yang kamu pilih. FocusMaxx tidak menutup atau menghentikan aplikasi tersebut.',
        action: 'Buka pengaturan overlay',
      );
      if (open == true) await AppBlockingPlatform.openOverlaySettings();
      await _refreshPermissions();
      if (!_overlayAccess) return false;
    }
    if (!_notificationAccess) {
      final granted = await AppBlockingPlatform.requestNotificationPermission();
      if (mounted) setState(() => _notificationAccess = granted);
      if (!granted) {
        final open = await _explainPermission(
          title: 'Notifikasi sesi fokus',
          explanation: 'Izin notifikasi membuat status pemantauan FocusMaxx terlihat selama sesi fokus.',
          action: 'Buka pengaturan notifikasi',
        );
        if (open == true) {
          await AppBlockingPlatform.openNotificationSettings();
        }
        return false;
      }
    }
    return true;
  }

  Future<bool?> _explainPermission({
    required String title,
    required String explanation,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(explanation),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );

  Future<void> _saveSettings({required bool enabled}) async {
    setState(() => _saving = true);
    try {
      await _database.updateAppBlockingSettings(
        userId: widget.userId,
        enabled: enabled,
        blockDuringBreaks: _blockDuringBreaks,
      );
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      _showMessage('Pengaturan belum dapat disimpan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setBreakBehavior(bool enabled) async {
    setState(() => _blockDuringBreaks = enabled);
    try {
      await _database.updateAppBlockingSettings(
        userId: widget.userId,
        enabled: _enabled,
        blockDuringBreaks: enabled,
      );
    } catch (_) {
      if (mounted) setState(() => _blockDuringBreaks = !enabled);
      _showMessage('Pengaturan belum dapat disimpan.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemblokiran Aplikasi')),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemblokiran Aplikasi')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final unavailableCount = _selectedPackages
        .where(
          (package) => !_applications.any(
            (application) => application.packageName == package,
          ),
        )
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Pemblokiran Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          const Text(
            'Pilih aplikasi yang ingin kamu hindari saat fokus. FocusMaxx menampilkan pengingat, bukan menghentikan atau mengunci aplikasi.',
            style: TextStyle(color: AppTheme.ink),
          ),
          const SizedBox(height: 14),
          _PermissionTile(
            title: 'Akses penggunaan',
            subtitle: 'Mengenali aplikasi yang sedang aktif selama fokus.',
            granted: _usageAccess,
            onTap: () async {
              final open = await _explainPermission(
                title: 'Akses penggunaan aplikasi',
                explanation: 'Izin khusus Android ini dibutuhkan agar FocusMaxx dapat membaca perpindahan aplikasi selama sesi fokus.',
                action: 'Buka pengaturan',
              );
              if (open == true) {
                await AppBlockingPlatform.openUsageAccessSettings();
              }
            },
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            title: 'Tampilkan di atas aplikasi lain',
            subtitle:
                'Menampilkan panel pengingat ketika aplikasi pilihan dibuka.',
            granted: _overlayAccess,
            onTap: () async {
              final open = await _explainPermission(
                title: 'Izin tampilan overlay',
                explanation: 'FocusMaxx menggunakan izin ini hanya untuk menampilkan panel pengingat selama fokus. Panel dapat ditutup dengan kembali ke FocusMaxx.',
                action: 'Buka pengaturan',
              );
              if (open == true) await AppBlockingPlatform.openOverlaySettings();
            },
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            title: 'Notifikasi sesi fokus',
            subtitle:
                'Menampilkan status service pemantauan yang sedang berjalan.',
            granted: _notificationAccess,
            onTap: () async {
              final granted =
                  await AppBlockingPlatform.requestNotificationPermission();
              if (mounted) setState(() => _notificationAccess = granted);
              if (!granted) {
                final open = await _explainPermission(
                  title: 'Notifikasi sesi fokus',
                  explanation: 'Aktifkan notifikasi di pengaturan Android agar status pemantauan FocusMaxx terlihat.',
                  action: 'Buka pengaturan notifikasi',
                );
                if (open == true) {
                  await AppBlockingPlatform.openNotificationSettings();
                }
              }
            },
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFF8FCF8),
            elevation: 0,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan saat sesi fokus'),
                  subtitle: Text(
                    _enabled
                        ? 'Pengingat muncul untuk ${_selectedPackages.length} aplikasi terpilih.'
                        : 'Pemantauan mati sampai kamu mengaktifkannya.',
                  ),
                  value: _enabled,
                  onChanged: _saving ? null : _setEnabled,
                  activeTrackColor: AppTheme.green,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Tetap ingatkan saat istirahat'),
                  subtitle: const Text(
                    'Default: pemblokiran nonaktif saat break.',
                  ),
                  value: _blockDuringBreaks,
                  onChanged: _saving ? null : _setBreakBehavior,
                  activeTrackColor: AppTheme.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aplikasi terpasang',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${_selectedPackages.length} dipilih'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            unavailableCount == 0
                ? 'Daftar berisi aplikasi yang bisa dibuka dari launcher.'
                : '$unavailableCount pilihan tersimpan tidak lagi tersedia di perangkat.',
            style: const TextStyle(fontSize: 12, color: AppTheme.ink),
          ),
          const SizedBox(height: 8),
          if (_applications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'Tidak ada aplikasi launcher yang dapat dipilih.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._applications.map(
              (app) => CheckboxListTile(
                value: _selectedPackages.contains(app.packageName),
                onChanged: _saving
                    ? null
                    : (selected) => _setApplication(app, selected ?? false),
                secondary: app.iconBytes == null
                    ? const CircleAvatar(child: Icon(Icons.apps_rounded))
                    : CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage: MemoryImage(app.iconBytes!),
                      ),
                title: Text(
                  app.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  app.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                controlAffinity: ListTileControlAffinity.trailing,
                activeColor: AppTheme.green,
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFF8FCF8),
    elevation: 0,
    child: ListTile(
      onTap: onTap,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        granted ? Icons.check_circle_rounded : Icons.open_in_new_rounded,
        color: granted ? AppTheme.green : AppTheme.darkGreen,
      ),
    ),
  );
}
