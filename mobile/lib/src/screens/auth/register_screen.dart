import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signUp(_name.text.trim(), _email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account could not be created.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showImageBackground: true,
      padding: EdgeInsets.zero,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: SafarLogo(height: 120)),
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text("Let's get you started", style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name', hintText: 'John Doe', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', hintText: 'example@email.com', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) => value == null || !value.contains('@') ? 'Valid email required' : null,
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
                      validator: (value) => value == null || value.length < 6 ? 'Use at least 6 characters' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('or continue with', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
            const SizedBox(height: 12),
            GoogleButton(onPressed: () => AuthService().signInWithGoogle()),
            const SizedBox(height: 34),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text('Login', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
