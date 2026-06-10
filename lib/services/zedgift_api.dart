import '../models/api_models.dart';
import 'api_client.dart';

/// High-level, typed access to the ZedGift endpoints the app uses.
/// Screens call these methods and get back model objects (never raw JSON).
class ZedgiftApi {
  ZedgiftApi._();
  static final ZedgiftApi instance = ZedgiftApi._();

  final ApiClient _c = ApiClient.instance;

  List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  // ---- Employees ---------------------------------------------------------

  Future<List<EmployeeListItem>> employees() async {
    final data = await _c.get('employees');
    return _list(data).map(EmployeeListItem.fromJson).toList();
  }

  Future<EmployeeDetail> employeeDetail(int id) async {
    final data = await _c.get('employees/$id');
    return EmployeeDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  // ---- Lookups -----------------------------------------------------------

  Future<List<NamedCount>> departments() async {
    final data = await _c.get('departments');
    return _list(data).map(NamedCount.fromJson).toList();
  }

  Future<List<NamedCount>> designations() async {
    final data = await _c.get('designations');
    return _list(data).map(NamedCount.fromJson).toList();
  }

  Future<List<NamedCount>> employeeTypes() async {
    final data = await _c.get('employee-types');
    return _list(data).map(NamedCount.fromJson).toList();
  }

  // ---- Leaves ------------------------------------------------------------

  /// Raw leave rows from `GET /leaves`. The response shape isn't documented,
  /// so screens read fields defensively.
  Future<List<Map<String, dynamic>>> leaves() async {
    final data = await _c.get('leaves');
    return _list(data);
  }

  // ---- Attendance --------------------------------------------------------

  Future<List<RecentPunch>> recentPunches() async {
    final data = await _c.get('attendance/recent');
    return _list(data).map(RecentPunch.fromJson).toList();
  }

  Future<List<AttendanceHistoryDay>> attendanceHistory(int employeeId) async {
    final data =
        await _c.get('attendance/history', query: {'employee_id': employeeId});
    return _list(data).map(AttendanceHistoryDay.fromJson).toList();
  }

  /// Raw status map for an employee (e.g. currently in/out). Returns the
  /// decoded `data` as-is since the shape is small and screen-specific.
  Future<Map<String, dynamic>> attendanceStatus(int employeeId) async {
    final data =
        await _c.get('attendance/status', query: {'employee_id': employeeId});
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Mark a punch (clock in/out — the server auto-toggles). [type] is one of
  /// face / fingerprint / rfid / manual. Returns the decoded `data` (often
  /// contains the new `punch_status`).
  Future<Map<String, dynamic>> punch(
    int employeeId, {
    String type = 'manual',
  }) async {
    final data = await _c.postForm('attendance/punch', {
      'employee_id': employeeId.toString(),
      'type': type,
    });
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  // ---- Face --------------------------------------------------------------

  /// Register an employee's reference face photo + descriptor.
  /// `face_image` is required; `descriptor` (JSON) carries the embeddings so
  /// any device can identify the person after syncing.
  Future<void> registerFace(
    int employeeId,
    String imagePath, {
    String? descriptor,
  }) async {
    await _c.postForm(
      'attendance/face/register',
      {
        'employee_id': employeeId.toString(),
        if (descriptor != null && descriptor.isNotEmpty)
          'descriptor': descriptor,
      },
      files: {'face_image': imagePath},
    );
  }

  /// Get one employee's registered face (`GET /attendance/face/{id}`),
  /// including its stored `descriptor`. Returns the decoded `data` map.
  Future<Map<String, dynamic>> getFace(int employeeId) async {
    final data = await _c.get('attendance/face/$employeeId');
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
