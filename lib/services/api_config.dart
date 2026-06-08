/// Central configuration for the ZedGift backend.
///
/// All REST calls go through [ApiClient] which reads these values. If the
/// client ever moves the API to another host, only this file changes.
class ApiConfig {
  ApiConfig._();

  /// Live ZedGift API base. Every endpoint path is appended to this,
  /// e.g. `$baseUrl/login`, `$baseUrl/employees`.
  static const String baseUrl = 'https://zedgift.viaaratech.com/api';

  /// The company whose data the app shows. The backend expects this on
  /// every authenticated request as the `Company-ID` header.
  /// Company 1 = the main ZedGift company (most employees).
  static const String companyId = '1';

  /// Network timeout for a single request.
  static const Duration timeout = Duration(seconds: 30);
}
