import 'dart:convert';

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

  Future<List<Company>> companies() async {
    final data = await _c.get('companies');
    return _list(data).map(Company.fromJson).toList();
  }

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

  /// Apply a leave on behalf of [employeeId]. Dates are `dd/MM/yyyy`, times
  /// are `hh:mm AM/PM` (the format the backend's create form expects).
  /// Endpoint: `POST /leaves`. Saves with status = 0 (Pending).
  Future<void> createLeave({
    required int employeeId,
    required String startDate,
    required String endDate,
    required String startTime,
    required String endTime,
    required String reason,
  }) async {
    await _c.postForm('leaves', {
      'employee_id': employeeId.toString(),
      'start_date': startDate,
      'end_date': endDate,
      'start_time': startTime,
      'end_time': endTime,
      'leave_reason': reason,
    });
  }

  /// Edit an existing leave. Endpoint: `PUT /leaves/{id}` (values in query).
  Future<void> updateLeave(
    int id, {
    required int employeeId,
    required String startDate,
    required String endDate,
    required String startTime,
    required String endTime,
    required String reason,
  }) async {
    await _c.put('leaves/$id', query: {
      'employee_id': employeeId,
      'start_date': startDate,
      'end_date': endDate,
      'start_time': startTime,
      'end_time': endTime,
      'leave_reason': reason,
    });
  }

  /// Remove a leave. Endpoint: `DELETE /leaves/{id}`.
  Future<void> deleteLeave(int id) async {
    await _c.delete('leaves/$id');
  }

  /// Approve (1) or reject (2) a leave. A [remark] is required when rejecting.
  /// Endpoint: `POST /leaves/approval?leave_id=&status=&remark=`.
  Future<void> approveLeave(
    int id, {
    required int status,
    String? remark,
  }) async {
    await _c.postForm(
      'leaves/approval',
      const <String, String>{},
      query: {
        'leave_id': id,
        'status': status,
        if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      },
    );
  }

  // ---- Attendance --------------------------------------------------------

  /// Recent punches. When [date] (format `yyyy-MM-dd`) is given it asks the
  /// backend for that day's attendance; without it the server returns today's.
  Future<List<RecentPunch>> recentPunches({String? date}) async {
    final data = await _c.get(
      'attendance/recent',
      query: {if (date != null && date.isNotEmpty) 'date': date},
    );
    return _list(data).map(RecentPunch.fromJson).toList();
  }

  Future<List<AttendanceHistoryDay>> attendanceHistory(int employeeId) async {
    final data =
        await _c.get('attendance/history', query: {'employee_id': employeeId});
    return _list(data).map(AttendanceHistoryDay.fromJson).toList();
  }

  // ---- Payroll / Advance / Deductions / Leaves --------------------------

  /// The payroll list for a month (`GET /salary?month=&year=`). Each row
  /// carries the employee, amounts and paid/approved flags the Salary screen
  /// shows. Defaults to the current month/year when not given.
  Future<List<SalaryListItem>> salaries({int? month, int? year}) async {
    final data = await _c.get('salary', query: {
      'month': ?month,
      'year': ?year,
    });
    return _list(data).map(SalaryListItem.fromJson).toList();
  }

  /// One salary row's full detail (`GET /salary/{id}`).
  Future<SalaryListItem> salaryDetail(int id) async {
    final data = await _c.get('salary/$id');
    return SalaryListItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// The full payroll breakdown for the payslip screen (`GET /salary/{id}`).
  Future<SalaryDetail> salaryFull(int id) async {
    final data = await _c.get('salary/$id');
    return SalaryDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  /// One month's salary for an employee (`GET /salary/by-employee`).
  /// Returns null when no salary has been generated for that month.
  Future<SalaryRecord?> salaryForMonth(
      int employeeId, int month, int year) async {
    try {
      final data = await _c.get('salary/by-employee', query: {
        'employee_id': employeeId,
        'month': month,
        'year': year,
      });
      if (data is Map) {
        return SalaryRecord.fromJson(data.cast<String, dynamic>());
      }
    } catch (_) {
      // No record for this month — treated as "no payroll".
    }
    return null;
  }

  /// Download a salary slip PDF (`GET /salary/slip/{id}/download`) as raw bytes.
  Future<List<int>> salarySlipBytes(int salaryId) =>
      _c.getBytes('salary/slip/$salaryId/download');

  /// Salary advances for an employee (`GET /advances?employee_id=`).
  Future<List<AdvanceRecord>> advances(int employeeId) async {
    final data = await _c.get('advances', query: {'employee_id': employeeId});
    return _list(data).map(AdvanceRecord.fromJson).toList();
  }

  /// Add an advance (`POST /advances`).
  Future<void> createAdvance({
    required int employeeId,
    required int month,
    required int year,
    required String amount,
    String? remark,
  }) async {
    await _c.postForm('advances', {
      'employee_id': employeeId.toString(),
      'month': month.toString(),
      'year': year.toString(),
      'amount': amount,
      if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
    });
  }

  /// Edit an advance (`PUT /advances/{id}` — values in query).
  Future<void> updateAdvance(
    int id, {
    required int employeeId,
    required int month,
    required int year,
    required String amount,
    String? remark,
  }) async {
    await _c.put('advances/$id', query: {
      'employee_id': employeeId,
      'month': month,
      'year': year,
      'amount': amount,
      if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
    });
  }

  /// Remove an advance (`DELETE /advances/{id}`).
  Future<void> deleteAdvance(int id) async => _c.delete('advances/$id');

  /// Mark an advance as paid out (`POST /advances/payout`, field `id`).
  Future<void> payoutAdvance(int id) async {
    await _c.postForm('advances/payout', {'id': id.toString()});
  }

  /// Deductions (loan / penalty / uniform) for an employee
  /// (`GET /deductions/by-employee?employee_id=`).
  Future<List<DeductionRecord>> deductions(int employeeId) async {
    final data = await _c
        .get('deductions/by-employee', query: {'employee_id': employeeId});
    return _list(data).map(DeductionRecord.fromJson).toList();
  }

  /// The deduction types (Loan Advance / Penalty / Uniform) — `GET
  /// /deductions/types`. Returned as id+name pairs.
  Future<List<NamedCount>> deductionTypes() async {
    final data = await _c.get('deductions/types');
    return _list(data).map(NamedCount.fromJson).toList();
  }

  /// Add a deduction (`POST /deductions`). [typeId] is the assettype id.
  Future<void> createDeduction({
    required int employeeId,
    required int typeId,
    required String amount,
    String? description,
  }) async {
    await _c.postForm('deductions', {
      'employee_id': employeeId.toString(),
      'assettype_id': typeId.toString(),
      'amount': amount,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  /// Edit a deduction (`PUT /deductions/{id}` — values in query).
  Future<void> updateDeduction(
    int id, {
    required int employeeId,
    required int typeId,
    required String amount,
    String? description,
  }) async {
    await _c.put('deductions/$id', query: {
      'employee_id': employeeId,
      'assettype_id': typeId,
      'amount': amount,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  /// Remove a deduction (`DELETE /deductions/{id}`).
  Future<void> deleteDeduction(int id) async => _c.delete('deductions/$id');

  // ---- Feedback ----------------------------------------------------------

  /// Feedback notes for one employee, filtered client-side from
  /// `GET /employee-feedback` (list endpoint has no employee_id param).
  Future<List<FeedbackRecord>> employeeFeedback(int employeeId) async {
    final data = await _c.get('employee-feedback');
    return _list(data)
        .map(FeedbackRecord.fromJson)
        .where((f) => f.employeeId == employeeId)
        .toList();
  }

  /// Add a feedback note (`POST /employee-feedback`).
  /// [type] is 1 = Positive, 2 = Negative.
  Future<void> createFeedback({
    required int employeeId,
    required int type,
    required String text,
  }) async {
    await _c.postForm('employee-feedback', {
      'employee_id': employeeId.toString(),
      'feedback_type': type.toString(),
      'feedback': text.trim(),
    });
  }

  /// Edit a feedback note (`PUT /employee-feedback/{id}` — values in query).
  Future<void> updateFeedback(
    int id, {
    required int employeeId,
    required int type,
    required String text,
  }) async {
    await _c.put('employee-feedback/$id', query: {
      'employee_id': employeeId,
      'feedback_type': type,
      'feedback': text.trim(),
    });
  }

  /// Remove a feedback note (`DELETE /employee-feedback/{id}`).
  Future<void> deleteFeedback(int id) async =>
      _c.delete('employee-feedback/$id');

  /// Leaves for one employee, filtered client-side from `GET /leaves`
  /// (the list endpoint has no employee_id query param).
  Future<List<LeaveRecord>> employeeLeaves(int employeeId) async {
    final data = await _c.get('leaves');
    return _list(data)
        .map(LeaveRecord.fromJson)
        .where((l) => l.employeeId == employeeId)
        .toList();
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

  /// Register an employee's reference face photo + embeddings.
  /// Endpoint: `POST /employees/face/register`.
  /// `face_image` required; `embeddings` is a JSON array of vectors
  /// (one per captured angle, e.g. `[[...],[...]]`) — the server stores it as
  /// `face_embeddings` and uses it to identify the person later.
  Future<void> registerFace(
    int employeeId,
    String imagePath, {
    String? embeddings,
  }) async {
    await _c.postForm(
      'employees/face/register',
      {
        'employee_id': employeeId.toString(),
        if (embeddings != null && embeddings.isNotEmpty)
          'embeddings': embeddings,
      },
      files: {'face_image': imagePath},
    );
  }

  /// Get one employee's registered face (`GET /employees/face/{id}`).
  Future<Map<String, dynamic>> getFace(int employeeId) async {
    final data = await _c.get('employees/face/$employeeId');
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Mark attendance by face. The phone sends the scanned face's [embedding];
  /// the SERVER finds the matching employee and records the punch.
  /// Endpoint: `POST /attendance/face/punch` (field `embeddings` = JSON).
  /// Returns the decoded `data` (matched employee + punch info).
  Future<Map<String, dynamic>> attendanceByFace(
    List<double> embedding, {
    String? timestamp,
  }) async {
    final data = await _c.postForm('attendance/face/punch', {
      'embeddings': jsonEncode(embedding),
      if (timestamp != null && timestamp.isNotEmpty) 'timestamp': timestamp,
    });
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
