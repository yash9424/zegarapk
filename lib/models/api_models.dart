// Plain data models mapped from the ZedGift API JSON.
//
// Each has a `fromJson` that is defensive about types — the backend mixes
// ints, strings, nulls and empty strings, so helpers coerce safely.

String _str(dynamic v) => v == null ? '' : v.toString();

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _dbl(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// "70000.000000" → "₹70,000.00" (plain thousands grouping).
String _money(dynamic v) {
  final fixed = _dbl(v).toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceFirst('-', '');
  final neg = parts[0].startsWith('-');
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${neg ? '-' : ''}₹$buf.${parts[1]}';
}

/// "27.000000" → "27"; "1.5" → "1.5".
String _trimNum(dynamic v) {
  final d = _dbl(v);
  return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

/// A row from `GET /employees`.
class EmployeeListItem {
  EmployeeListItem({
    required this.id,
    required this.customId,
    required this.name,
    required this.phone,
    required this.doj,
    required this.departmentName,
    required this.designationName,
    required this.typeName,
    required this.active,
  });

  final int id;
  final int customId;
  final String name;
  final String phone;
  final String doj;
  final String departmentName;
  final String designationName;
  final String typeName;
  final bool active; // user.status == 1

  factory EmployeeListItem.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] as Map?)?.cast<String, dynamic>();
    final dept = (j['department'] as Map?)?.cast<String, dynamic>();
    final desig = (j['designation'] as Map?)?.cast<String, dynamic>();
    final type = (j['employeetype'] as Map?)?.cast<String, dynamic>();
    return EmployeeListItem(
      id: _int(j['id']),
      customId: _int(j['custom_employee_id']),
      name: _str(j['name']).trim(),
      phone: _str(j['personal_phone']).trim(),
      doj: _str(j['doj']),
      departmentName: dept == null ? '' : _str(dept['name']).trim(),
      designationName: desig == null ? '' : _str(desig['name']).trim(),
      typeName: type == null ? '' : _str(type['name']).trim(),
      active: user != null && _int(user['status']) == 1,
    );
  }
}

/// A bank row inside the employee detail.
class EmployeeBank {
  EmployeeBank({
    required this.accountNumber,
    required this.ifsc,
    required this.holderName,
    required this.bankName,
    required this.branch,
  });

  final String accountNumber;
  final String ifsc;
  final String holderName;
  final String bankName;
  final String branch;

  factory EmployeeBank.fromJson(Map<String, dynamic> j) => EmployeeBank(
        accountNumber: _str(j['bank_account_number']),
        ifsc: _str(j['bank_ifsc_code']),
        holderName: _str(j['account_holder_name']),
        bankName: _str(j['bank_name']),
        branch: _str(j['bank_branch']),
      );
}

/// Full record from `GET /employees/{id}`.
class EmployeeDetail {
  EmployeeDetail({
    required this.id,
    required this.customId,
    required this.name,
    required this.phone,
    required this.emergencyPhone,
    required this.education,
    required this.doj,
    required this.dob,
    required this.departmentName,
    required this.designationName,
    required this.typeName,
    required this.permanentAddress,
    required this.currentAddress,
    required this.permanentState,
    required this.currentState,
    required this.salary,
    required this.netSalary,
    required this.previousCompany,
    required this.banks,
  });

  final int id;
  final int customId;
  final String name;
  final String phone;
  final String emergencyPhone;
  final String education;
  final String doj;
  final String dob;
  final String departmentName;
  final String designationName;
  final String typeName;
  final String permanentAddress;
  final String currentAddress;
  final String permanentState;
  final String currentState;
  final String salary;
  final String netSalary;
  final String previousCompany;
  final List<EmployeeBank> banks;

  factory EmployeeDetail.fromJson(Map<String, dynamic> j) {
    final dept = (j['department'] as Map?)?.cast<String, dynamic>();
    final desig = (j['designation'] as Map?)?.cast<String, dynamic>();
    final type = (j['employeetype'] as Map?)?.cast<String, dynamic>();
    final pState = (j['permanent_state'] as Map?)?.cast<String, dynamic>();
    final cState = (j['current_state'] as Map?)?.cast<String, dynamic>();
    final banksJson = (j['banks'] as List?) ?? const [];
    return EmployeeDetail(
      id: _int(j['id']),
      customId: _int(j['custom_employee_id']),
      name: _str(j['name']).trim(),
      phone: _str(j['personal_phone']).trim(),
      emergencyPhone: _str(j['emergency_phone']).trim(),
      education: _str(j['education']).trim(),
      doj: _str(j['doj']),
      dob: _str(j['dob']),
      departmentName: dept == null ? '' : _str(dept['name']).trim(),
      designationName: desig == null ? '' : _str(desig['name']).trim(),
      typeName: type == null ? '' : _str(type['name']).trim(),
      permanentAddress: _str(j['permanent_address']).trim(),
      currentAddress: _str(j['current_address']).trim(),
      permanentState: pState == null ? '' : _str(pState['name']).trim(),
      currentState: cState == null ? '' : _str(cState['name']).trim(),
      salary: _str(j['salary']),
      netSalary: _str(j['net_salary']),
      previousCompany: _str(j['previous_company']).trim(),
      banks: banksJson
          .whereType<Map>()
          .map((b) => EmployeeBank.fromJson(b.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// A company from `GET /companies`.
class Company {
  Company({required this.id, required this.name});
  final int id;
  final String name;

  factory Company.fromJson(Map<String, dynamic> j) =>
      Company(id: _int(j['id']), name: _str(j['name']).trim());
}

/// A name + employee_count row (departments, designations, employee-types).
class NamedCount {
  NamedCount({required this.id, required this.name, required this.count});
  final int id;
  final String name;
  final int count;

  factory NamedCount.fromJson(Map<String, dynamic> j) => NamedCount(
        id: _int(j['id']),
        name: _str(j['name']).trim(),
        count: _int(j['employee_count']),
      );
}

/// A row from `GET /attendance/recent`.
class RecentPunch {
  RecentPunch({
    required this.employeeId,
    required this.employeeName,
    required this.customId,
    required this.departmentName,
    required this.date,
    required this.dutyIn,
    required this.dutyOut,
    required this.status, // "in" / "out"
  });

  final int employeeId;
  final String employeeName;
  final int customId;
  final String departmentName;
  final String date;
  final String dutyIn;
  final String dutyOut;
  final String status;

  bool get isIn => status.toLowerCase() == 'in';

  factory RecentPunch.fromJson(Map<String, dynamic> j) => RecentPunch(
        employeeId: _int(j['employee_id']),
        employeeName: _str(j['employee_name']).trim(),
        customId: _int(j['custom_employee_id']),
        departmentName: _str(j['department_name']).trim(),
        date: _str(j['date']),
        dutyIn: _str(j['duty_in']),
        dutyOut: _str(j['duty_out']),
        status: _str(j['punch_status']),
      );
}

/// A day from `GET /attendance/history`.
class AttendanceHistoryDay {
  AttendanceHistoryDay({
    required this.date,
    required this.dutyIn,
    required this.dutyOut,
    required this.workTime,
    required this.remarks,
  });

  final String date;
  final String dutyIn;
  final String dutyOut;
  final String workTime;
  final String remarks;

  factory AttendanceHistoryDay.fromJson(Map<String, dynamic> j) =>
      AttendanceHistoryDay(
        date: _str(j['date']),
        dutyIn: _str(j['duty_in']),
        dutyOut: _str(j['duty_out']),
        workTime: _str(j['work_time']),
        remarks: _str(j['remarks']),
      );
}

/// One month's payroll from `GET /salary/by-employee`.
class SalaryRecord {
  SalaryRecord({
    required this.month,
    required this.year,
    required this.fixSalary,
    required this.grossSalary,
    required this.netSalary,
    required this.totalDeduction,
    required this.presentDays,
    required this.totalDays,
    required this.paid,
  });

  final int month;
  final int year;
  final String fixSalary;
  final String grossSalary;
  final String netSalary;
  final String totalDeduction;
  final String presentDays;
  final String totalDays;
  final bool paid;

  factory SalaryRecord.fromJson(Map<String, dynamic> j) => SalaryRecord(
        month: _int(j['month']),
        year: _int(j['year']),
        fixSalary: _money(j['fix_salary']),
        grossSalary: _money(j['gross_salary']),
        netSalary: _money(_dbl(j['net_salary_bank']) + _dbl(j['net_salary_cash'])),
        totalDeduction: _money(j['total_deduction']),
        presentDays: _trimNum(j['present_days']),
        totalDays: _trimNum(j['total_days']),
        paid: _int(j['paid']) == 1,
      );
}

/// A salary advance from `GET /advances`.
class AdvanceRecord {
  AdvanceRecord({
    required this.month,
    required this.year,
    required this.amount,
    required this.remark,
    required this.paid,
  });

  final int month;
  final int year;
  final String amount;
  final String remark;
  final bool paid; // payout == 1

  factory AdvanceRecord.fromJson(Map<String, dynamic> j) => AdvanceRecord(
        month: _int(j['month']),
        year: _int(j['year']),
        amount: _money(j['amount']),
        remark: _str(j['remark']).trim(),
        paid: _int(j['payout']) == 1,
      );
}

/// A deduction entry (Loan Advance / Penalty / Uniform) from
/// `GET /deductions/by-employee`.
class DeductionRecord {
  DeductionRecord({
    required this.typeName,
    required this.amount,
    required this.description,
    required this.date,
  });

  final String typeName;
  final String amount;
  final String description;
  final String date;

  factory DeductionRecord.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] as Map?)?.cast<String, dynamic>();
    return DeductionRecord(
      typeName: type == null ? 'Deduction' : _str(type['name']).trim(),
      amount: _money(j['amount']),
      description: _str(j['description']).trim(),
      date: _str(j['created_at']),
    );
  }
}

/// A leave from `GET /leaves`. status: 0 pending, 1 approved, 2 rejected.
class LeaveRecord {
  LeaveRecord({
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.days,
    required this.status,
  });

  final int employeeId;
  final String startDate;
  final String endDate;
  final String reason;
  final int days;
  final int status;

  factory LeaveRecord.fromJson(Map<String, dynamic> j) => LeaveRecord(
        employeeId: _int(j['employee_id']),
        startDate: _str(j['start_date']),
        endDate: _str(j['end_date']),
        reason: _str(j['leave_reason']).trim(),
        days: _int(j['total_leave_days']),
        status: _int(j['status']),
      );
}
