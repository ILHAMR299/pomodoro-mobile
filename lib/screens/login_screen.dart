import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/mascot_brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onAuthenticated, required this.onRegister});
  final AuthService auth;
  final ValueChanged<UserModel> onAuthenticated;
  final VoidCallback onRegister;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final user = await widget.auth.login(email: _email.text, password: _password.text);
      if (mounted) widget.onAuthenticated(user);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Belum dapat masuk. Periksa penyimpanan lalu coba lagi.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Center(child: MascotBrand()),
    const SizedBox(height: 23),
    const Text('Selamat Datang Kembali!', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
    const SizedBox(height: 8),
    const Text('Siap melanjutkan fokusmu hari ini?', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.ink)),
    const SizedBox(height: 27),
    AuthTextField(controller: _email, label: 'Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: (value) => value == null || value.trim().isEmpty ? 'Email tidak boleh kosong.' : !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? 'Masukkan alamat email yang valid.' : null),
    const SizedBox(height: 15),
    AuthTextField(controller: _password, label: 'Kata sandi', icon: Icons.lock_outline_rounded, obscureText: !_showPassword, textInputAction: TextInputAction.done, validator: (value) => value == null || value.isEmpty ? 'Kata sandi tidak boleh kosong.' : null, suffix: IconButton(tooltip: _showPassword ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi', onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
    if (_error != null) ...[const SizedBox(height: 13), Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9C3028)))],
    const SizedBox(height: 22),
    FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Masuk')),
    const SizedBox(height: 18),
    TextButton(onPressed: _busy ? null : widget.onRegister, child: const Text('Belum punya akun? Daftar', style: TextStyle(color: AppTheme.darkGreen))),
  ])))))));
}
