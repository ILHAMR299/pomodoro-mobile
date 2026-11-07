import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/pomodoro_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() => runApp(const TemanFokusApp());

class TemanFokusApp extends StatelessWidget {
  const TemanFokusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Teman Fokus',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const _AppEntry(),
  );
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  final _auth = AuthService();
  UserModel? _user;
  bool _initialized = false;
  bool _loading = true;
  String? _error;
  bool _showRegister = false;

  Future<void> _initialize() async {
    final startedAt = DateTime.now();
    setState(() { _loading = true; _error = null; });
    try {
      _user = await _auth.restoreSession();
      final remaining = const Duration(seconds: 9) - DateTime.now().difference(startedAt);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (mounted) setState(() { _initialized = true; _loading = false; });
    } catch (_) {
      final remaining = const Duration(seconds: 9) - DateTime.now().difference(startedAt);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (mounted) setState(() { _loading = false; _error = 'Belum dapat membuka data aplikasi. Periksa ruang penyimpanan lalu coba lagi.'; });
    }
  }

  void _authenticated(UserModel user) => setState(() => _user = user);

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) setState(() { _user = null; _showRegister = false; });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _loading || _error != null) {
      return SplashScreen(
        loading: _loading,
        error: _error,
        onRetry: _initialize,
      );
    }
    if (_user != null) {
      return PomodoroScreen(userName: _user!.name, onLogout: _logout);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _showRegister
          ? RegisterScreen(key: const ValueKey('register'), auth: _auth, onAuthenticated: _authenticated, onLogin: () => setState(() => _showRegister = false))
          : LoginScreen(key: const ValueKey('login'), auth: _auth, onAuthenticated: _authenticated, onRegister: () => setState(() => _showRegister = true)),
    );
  }
}
