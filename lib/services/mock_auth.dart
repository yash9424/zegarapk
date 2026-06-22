import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Roles a logged-in user can have. The ZedGift API is an admin-level API
/// (it returns org-wide employees and attendance), so a successful login
/// lands in the admin panel.
enum UserRole { admin, employee }

class AuthUser {
  const AuthUser({
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final UserRole role;
}

class AuthResult {
  const AuthResult.success(this.user)
      : ok = true,
        error = null;
  const AuthResult.failure(this.error)
      : ok = false,
        user = null;

  final bool ok;
  final AuthUser? user;
  final String? error;
}

/// Authentication backed by the live ZedGift API (`POST /login`).
///
/// On success the Bearer token is stored in [ApiClient] so every later call
/// is authenticated. The class name is kept as `MockAuth` so existing screens
/// don't need import changes — but it is now a real network login.
class MockAuth {
  MockAuth._();
  static final MockAuth instance = MockAuth._();

  AuthUser? currentUser;

  static const _kName = 'zedgift_user_name';
  static const _kEmail = 'zedgift_user_email';

  /// True if a previous session is still active (token + user restored).
  bool get isLoggedIn => currentUser != null && ApiClient.instance.isAuthenticated;

  /// Restore a saved session on app start so the admin stays logged in
  /// (no automatic logout when the app is reopened).
  Future<void> restore() async {
    await ApiClient.instance.restoreToken();
    if (!ApiClient.instance.isAuthenticated) return;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName) ?? 'Administrator';
    final email = prefs.getString(_kEmail) ?? '';
    currentUser = AuthUser(name: name, email: email, role: UserRole.admin);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final id = email.trim();
    if (id.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Please enter your credentials.');
    }

    try {
      final data = await ApiClient.instance.postForm(
        'login',
        {'email': id, 'password': password},
        auth: false,
      );

      final map = (data as Map).cast<String, dynamic>();
      final token = map['access_token'] as String?;
      if (token == null || token.isEmpty) {
        return const AuthResult.failure('Login failed. Please try again.');
      }
      await ApiClient.instance.saveToken(token);

      final user = (map['user'] as Map?)?.cast<String, dynamic>();
      final name = _composeName(user) ?? id;
      final mail = (user?['email'] as String?) ?? id;

      final authUser =
          AuthUser(name: name, email: mail, role: UserRole.admin);
      currentUser = authUser;
      // Persist user so the session survives an app restart.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kName, name);
      await prefs.setString(_kEmail, mail);
      return AuthResult.success(authUser);
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Admin sign-out (when the user taps Log Out): clears the admin session and
  /// saved user so the panel is locked again. The device stays authorized for
  /// kiosk attendance, so "Mark Attendance" keeps working without re-login.
  Future<void> logout() async {
    currentUser = null;
    await ApiClient.instance.signOutAdmin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
  }

  String? _composeName(Map<String, dynamic>? user) {
    if (user == null) return null;
    final parts = [
      user['first_name'],
      user['father_name'],
      user['last_name'],
    ].map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty);
    final joined = parts.join(' ').trim();
    return joined.isEmpty ? null : joined;
  }
}
