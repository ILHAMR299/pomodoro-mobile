import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/mascot_brand.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth, required this.onAuthenticated, required this.onLogin});
  final AuthService auth;
  final ValueChanged<UserModel> onAuthenticated;
  final VoidCallback onLogin;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); _confirmation.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final user = await widget.auth.register(name: _name.text, email: _email.text, password: _password.text);
      if (mounted) widget.onAuthenticated(user);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Akun belum dapat dibuat. Coba lagi.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Center(child: MascotBrand()),
    const SizedBox(height: 12),
    const Text('Buat Akun Baru', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
    const SizedBox(height: 7),
    const Text('Mulai perjalanan fokusmu bersama kami.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.ink)),
    const SizedBox(height: 20),
    AuthTextField(controller: _name, label: 'Nama lengkap', icon: Icons.person_outline_rounded, textInputAction: TextInputAction.next, validator: (value) => value == null || value.trim().isEmpty ? 'Nama tidak boleh kosong.' : null),
    const SizedBox(height: 12),
    AuthTextField(controller: _email, label: 'Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: (value) => value == null || value.trim().isEmpty ? 'Email tidak boleh kosong.' : !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? 'Masukkan alamat email yang valid.' : null),
    const SizedBox(height: 12),
    AuthTextField(controller: _password, label: 'Kata sandi', icon: Icons.lock_outline_rounded, obscureText: !_showPassword, textInputAction: TextInputAction.next, validator: (value) => value == null || value.length < 8 ? 'Kata sandi minimal 8 karakter.' : null, suffix: IconButton(tooltip: _showPassword ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi', onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
    const SizedBox(height: 12),
    AuthTextField(controller: _confirmation, label: 'Konfirmasi kata sandi', icon: Icons.lock_outline_rounded, obscureText: !_showPassword, textInputAction: TextInputAction.done, validator: (value) => value != _password.text ? 'Konfirmasi kata sandi belum sesuai.' : null),
    if (_error != null) ...[const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9C3028)))],
    const SizedBox(height: 17),
    FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Buat Akun')),
    const SizedBox(height: 10),
    TextButton(onPressed: _busy ? null : widget.onLogin, child: const Text('Sudah punya akun? Masuk', style: TextStyle(color: AppTheme.darkGreen))),
  ])))))));
}
