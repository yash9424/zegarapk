/// Roles a logged-in user can have.
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

/// Mock authentication. Admin uses fixed credentials; any other
/// non-empty email/password combination logs in as an employee.
class MockAuth {
  MockAuth._();
  static final MockAuth instance = MockAuth._();

  // Fixed admin credentials — share these to reach the Admin panel.
  static const String adminEmail = 'admin@gmail.com';
  static const String adminPassword = 'admin123';

  // Fixed employee demo credentials.
  static const String employeeEmail = 'user@gmail.com';
  static const String employeePassword = 'user123';
  static const String employeeName = 'Alexander Mercer';

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Simulate a short network round-trip.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final id = email.trim().toLowerCase();

    if (id.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Please enter your credentials.');
    }

    if (id == adminEmail && password == adminPassword) {
      return const AuthResult.success(
        AuthUser(
          name: 'Administrator',
          email: adminEmail,
          role: UserRole.admin,
        ),
      );
    }

    // Block anyone trying the admin email with the wrong password.
    if (id == adminEmail) {
      return const AuthResult.failure('Incorrect admin password.');
    }

    if (id == employeeEmail && password == employeePassword) {
      return const AuthResult.success(
        AuthUser(
          name: employeeName,
          email: employeeEmail,
          role: UserRole.employee,
        ),
      );
    }

    if (id == employeeEmail) {
      return const AuthResult.failure('Incorrect password.');
    }

    if (password.length < 4) {
      return const AuthResult.failure('Password must be at least 4 characters.');
    }

    // Everything else is treated as a valid employee (mock data).
    final display = _displayNameFor(id);
    return AuthResult.success(
      AuthUser(name: display, email: id, role: UserRole.employee),
    );
  }

  String _displayNameFor(String email) {
    final local = email.contains('@') ? email.split('@').first : email;
    final cleaned = local.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Employee';
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
