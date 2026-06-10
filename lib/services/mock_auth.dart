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
      return AuthResult.success(authUser);
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Leaves the admin panel UI but KEEPS the device authorised so the kiosk
  /// "Mark Attendance" keeps working for employees who never log in.
  /// Use [unlinkDevice] to fully sign the device out.
  void logout() {
    currentUser = null;
  }

  /// Fully sign out: clears the admin session AND the saved device token,
  /// so the kiosk will require an admin to log in again.
  Future<void> unlinkDevice() async {
    currentUser = null;
    await ApiClient.instance.saveToken(null);
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
