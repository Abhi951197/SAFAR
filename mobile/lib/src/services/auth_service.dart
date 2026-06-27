import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String name, String email, String password) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updateProfileMetadata({String? name, String? avatarUrl}) async {
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          if (name != null) 'full_name': name,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        },
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'safar://login-callback',
      queryParams: kIsWeb ? null : {'access_type': 'offline', 'prompt': 'consent'},
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
