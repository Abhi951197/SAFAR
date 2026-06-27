import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signIn(_email.text.trim(), _password.text);
    } catch (_) {
      if (mounted) _showError('Invalid email or password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await _auth.signInWithGoogle();
    } catch (error) {
      if (mounted) _showError('Google sign-in could not be started. $error');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter your email first, then tap forgot password.');
      return;
    }
    try {
      await _auth.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
      }
    } catch (error) {
      if (mounted) _showError('Could not send reset email. $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showImageBackground: true,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ListView(
        children: [
          const SizedBox(height: 28),
          const Center(child: SafarLogo(height: 130)),
          const SizedBox(height: 14),
          GlassPanel(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome Back', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Continue your journey', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', hintText: 'example@email.com', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Email required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Password required' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _resetPassword, child: const Text('Forgot password?')),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('or continue with', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          const SizedBox(height: 12),
          GoogleButton(onPressed: _googleLoading ? null : _google),
          const SizedBox(height: 38),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? ", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Sign Up', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
