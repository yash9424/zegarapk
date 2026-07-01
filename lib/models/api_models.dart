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

/// 20160 → "20,160" (thousands grouping for a plain integer).
String _intGroup(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

/// Company-wide counters from `GET /dashboard/stats`.
class DashboardStats {
  DashboardStats({
    required this.employees,
    required this.onLeave,
    required this.advances,
    required this.payroll,
  });

  final int employees;
  final int onLeave;
  final int advances;
  final double payroll;

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        employees: _int(j['total_employee_count']),
        onLeave: _int(j['total_leave_count']),
        advances: _int(j['total_advance_count']),
        payroll: _dbl(j['total_salary_amount_sum']),
      );

  /// Compact Indian-style money for the stat card: ₹0, ₹24.5L, ₹1.2Cr.
  String get payrollLabel {
    final v = payroll;
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
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
    required this.id,
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

  final int id;
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
        id: _int(j['id']),
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

/// A row from `GET /salary?month=&year=` (the payroll list). Carries both the
/// pre-formatted ₹ strings the card shows and a few raw doubles used for the
/// detail breakdown. Reads the nested `employee` block for name / id / dept.
class SalaryListItem {
  SalaryListItem({
    required this.id,
    required this.month,
    required this.year,
    required this.employeeId,
    required this.name,
    required this.customId,
    required this.departmentName,
    required this.designationName,
    required this.typeName,
    required this.fixSalary,
    required this.attendanceMinutes,
    required this.overtimeMinutes,
    required this.earnings,
    required this.deductions,
    required this.grossSalary,
    required this.companyContribution,
    required this.netPayable,
    required this.paid,
    required this.approved,
  });

  final int id;
  final int month;
  final int year;
  final int employeeId;
  final String name;
  final int customId;
  final String departmentName;
  final String designationName;
  final String typeName;
  final String fixSalary; // ₹
  final int attendanceMinutes; // total worked minutes
  final int overtimeMinutes; // OT minutes
  final String earnings; // ₹ (gross before deductions)
  final String deductions; // ₹
  final String grossSalary; // ₹
  final String companyContribution; // ₹
  final String netPayable; // ₹
  final bool paid;
  final bool approved;

  /// "ZG-2045" style code from the custom employee id.
  String get code => 'ZG-$customId';

  String get attendanceLabel => '${_intGroup(attendanceMinutes)} Min';
  String get overtimeLabel => '${_intGroup(overtimeMinutes)} Min';

  factory SalaryListItem.fromJson(Map<String, dynamic> j) {
    final emp = (j['employee'] as Map?)?.cast<String, dynamic>();
    final dept = (emp?['department'] as Map?)?.cast<String, dynamic>();
    final desig = (emp?['designation'] as Map?)?.cast<String, dynamic>();
    final type = (emp?['employeetype'] as Map?)?.cast<String, dynamic>();

    final gross = _dbl(j['gross_salary']);
    final deduction = _dbl(j['total_deduction']);
    final company = _dbl(j['ctc_contribution']) != 0
        ? _dbl(j['ctc_contribution'])
        : _dbl(j['epf_contribution']);
    final salaryAmount = _dbl(j['salary_amount']);
    final earnings = salaryAmount != 0 ? salaryAmount : gross;

    // Prefer the real net (bank + cash); fall back to the design's arithmetic
    // (earnings − deductions + company contribution) when those are blank.
    final netReal = _dbl(j['net_salary_bank']) + _dbl(j['net_salary_cash']);
    final net = netReal != 0 ? netReal : (earnings - deduction + company);

    return SalaryListItem(
      id: _int(j['id']),
      month: _int(j['month']),
      year: _int(j['year']),
      employeeId: _int(j['employee_id']),
      name: emp == null ? '' : _str(emp['name']).trim(),
      customId: emp == null
          ? _int(j['employee_id'])
          : _int(emp['custom_employee_id']),
      departmentName: dept == null ? '' : _str(dept['name']).trim(),
      designationName: desig == null ? '' : _str(desig['name']).trim(),
      typeName: type == null ? '' : _str(type['name']).trim(),
      fixSalary: _money(j['fix_salary']),
      attendanceMinutes: (_dbl(j['total_hrs']) * 60).round(),
      overtimeMinutes: (_dbl(j['total_ot_hrs']) * 60).round(),
      earnings: _money(earnings),
      deductions: _money(deduction),
      grossSalary: _money(gross != 0 ? gross : earnings),
      companyContribution: _money(company),
      netPayable: _money(net),
      paid: _int(j['paid']) == 1,
      approved: _int(j['approved']) == 1,
    );
  }
}

/// Full payroll breakdown from `GET /salary/{id}` — everything the salary
/// detail (payslip) screen shows: basics, days, earnings, deductions, net and
/// company contribution. All ₹ fields are pre-formatted; a few raw doubles are
/// kept where the screen needs to compute or compare.
class SalaryDetail {
  SalaryDetail({
    required this.id,
    required this.month,
    required this.year,
    required this.employeeId,
    required this.name,
    required this.customId,
    required this.departmentName,
    required this.designationName,
    required this.typeName,
    required this.paid,
    required this.approved,
    required this.pfActive,
    required this.fixWageLabel,
    required this.fixSalary,
    required this.workingHrs,
    required this.workingDays,
    required this.totalMinutes,
    required this.presentDays,
    required this.paidHoliday,
    required this.totalDays,
    required this.basicSalary,
    required this.otAmount,
    required this.otHours,
    required this.paidHolidayAmount,
    required this.mealAmount,
    required this.productionIncentive,
    required this.grossSalary,
    required this.pf,
    required this.pt,
    required this.advancePayment,
    required this.loanRecovery,
    required this.holdSalary,
    required this.totalDeduction,
    required this.bankTransfer,
    required this.cashPayment,
    required this.netPayable,
    required this.bonus,
    required this.epf,
    required this.ctc,
  });

  final int id;
  final int month;
  final int year;
  final int employeeId;
  final String name;
  final int customId;
  final String departmentName;
  final String designationName;
  final String typeName;
  final bool paid;
  final bool approved;

  // Basics
  final bool pfActive;
  final String fixWageLabel; // "Standard" / "Variable"
  final String fixSalary; // ₹
  final String workingHrs;
  final String workingDays;
  final String totalMinutes;

  // Days
  final String presentDays;
  final String paidHoliday;
  final String totalDays;

  // Earnings
  final String basicSalary; // ₹
  final String otAmount; // ₹
  final String otHours;
  final String paidHolidayAmount; // ₹
  final String mealAmount; // ₹
  final String productionIncentive; // ₹
  final String grossSalary; // ₹

  // Deductions
  final String pf; // ₹
  final String pt; // ₹
  final String advancePayment; // ₹
  final String loanRecovery; // ₹
  final String holdSalary; // ₹
  final String totalDeduction; // ₹

  // Net
  final String bankTransfer; // ₹
  final String cashPayment; // ₹
  final String netPayable; // ₹

  // Company contribution
  final String bonus; // ₹
  final String epf; // ₹
  final String ctc; // ₹

  String get code => 'ID: $customId';

  factory SalaryDetail.fromJson(Map<String, dynamic> j) {
    final emp = (j['employee'] as Map?)?.cast<String, dynamic>();
    final dept = (emp?['department'] as Map?)?.cast<String, dynamic>();
    final desig = (emp?['designation'] as Map?)?.cast<String, dynamic>();
    final type = (emp?['employeetype'] as Map?)?.cast<String, dynamic>();

    final totalHrs = _dbl(j['total_hrs']);
    final otHrs = _dbl(j['total_ot_hrs']);

    final basic = _dbl(j['salary_amount']);
    final ot = _dbl(j['ot_amount']);
    final meal = _dbl(j['tiffin_amount']);
    final incentive = _dbl(j['pro_ince_amount']);
    final grossRaw = _dbl(j['gross_salary']);
    final gross = grossRaw != 0 ? grossRaw : (basic + ot + meal + incentive);
    // No dedicated "paid holiday amount" field — it's the remainder that makes
    // the parts add up to gross.
    var phAmount = gross - (basic + ot + meal + incentive);
    if (phAmount < 0) phAmount = 0;

    final pfDed = _dbl(j['pf_deduction']);
    final epfC = _dbl(j['epf_contribution']);

    final bank = _dbl(j['net_salary_bank']);
    final cash = _dbl(j['net_salary_cash']);
    final totalDed = _dbl(j['total_deduction']);
    final netReal = bank + cash;
    final net = netReal != 0 ? netReal : (gross - totalDed);

    final salaryType = _str(type?['salary_type']).toLowerCase();

    return SalaryDetail(
      id: _int(j['id']),
      month: _int(j['month']),
      year: _int(j['year']),
      employeeId: _int(j['employee_id']),
      name: emp == null ? '' : _str(emp['name']).trim(),
      customId: emp == null
          ? _int(j['employee_id'])
          : _int(emp['custom_employee_id']),
      departmentName: dept == null ? '' : _str(dept['name']).trim(),
      designationName: desig == null ? '' : _str(desig['name']).trim(),
      typeName: type == null ? '' : _str(type['name']).trim(),
      paid: _int(j['paid']) == 1,
      approved: _int(j['approved']) == 1,
      pfActive: pfDed > 0 || epfC > 0,
      fixWageLabel: salaryType == 'fixed' ? 'Standard' : 'Variable',
      fixSalary: _money(j['fix_salary']),
      workingHrs: _trimNum(totalHrs),
      workingDays: _trimNum(j['month_working_days']),
      totalMinutes: _intGroup((totalHrs * 60).round()),
      presentDays: _trimNum(j['present_days']),
      paidHoliday: _trimNum(j['ph_days']),
      totalDays: _trimNum(j['total_days']),
      basicSalary: _money(basic),
      otAmount: _money(ot),
      otHours: _trimNum(otHrs),
      paidHolidayAmount: _money(phAmount),
      mealAmount: _money(meal),
      productionIncentive: _money(incentive),
      grossSalary: _money(gross),
      pf: _money(pfDed),
      pt: _money(j['pt_deduction']),
      advancePayment: _money(j['advance_deduction']),
      loanRecovery: _money(j['loan_deduction']),
      holdSalary: _money(j['bond_deduction']),
      totalDeduction: _money(totalDed),
      bankTransfer: _money(bank),
      cashPayment: _money(cash),
      netPayable: _money(net),
      bonus: _money(j['bonus_contribution']),
      epf: _money(epfC),
      ctc: _money(j['ctc_contribution']),
    );
  }
}

/// A salary advance from `GET /advances`. Carries the raw amount/month/year
/// too so the edit form can pre-fill them.
class AdvanceRecord {
  AdvanceRecord({
    required this.id,
    required this.month,
    required this.year,
    required this.amount,
    required this.amountRaw,
    required this.remark,
    required this.paid,
  });

  final int id;
  final int month;
  final int year;
  final String amount; // formatted ₹
  final double amountRaw; // numeric, for edit form
  final String remark;
  final bool paid; // payout == 1

  factory AdvanceRecord.fromJson(Map<String, dynamic> j) => AdvanceRecord(
        id: _int(j['id']),
        month: _int(j['month']),
        year: _int(j['year']),
        amount: _money(j['amount']),
        amountRaw: _dbl(j['amount']),
        remark: _str(j['remark']).trim(),
        paid: _int(j['payout']) == 1,
      );
}

/// A deduction entry (Loan Advance / Penalty / Uniform) from
/// `GET /deductions/by-employee`.
class DeductionRecord {
  DeductionRecord({
    required this.id,
    required this.typeId,
    required this.typeName,
    required this.amount,
    required this.amountRaw,
    required this.description,
    required this.date,
  });

  final int id;
  final int typeId; // assettype_id, for edit form
  final String typeName;
  final String amount;
  final double amountRaw;
  final String description;
  final String date;

  factory DeductionRecord.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] as Map?)?.cast<String, dynamic>() ??
        (j['assettype'] as Map?)?.cast<String, dynamic>();
    return DeductionRecord(
      id: _int(j['id']),
      typeId: type != null ? _int(type['id']) : _int(j['assettype_id']),
      typeName: type == null ? 'Deduction' : _str(type['name']).trim(),
      amount: _money(j['amount']),
      amountRaw: _dbl(j['amount']),
      description: _str(j['description']).trim(),
      date: _str(j['created_at']),
    );
  }
}

/// A leave from `GET /leaves`. status: 0 pending, 1 approved, 2 rejected.
class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.days,
    required this.status,
  });

  final int id;
  final int employeeId;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String reason;
  final int days;
  final int status;

  factory LeaveRecord.fromJson(Map<String, dynamic> j) => LeaveRecord(
        id: _int(j['id']),
        employeeId: _int(j['employee_id']),
        startDate: _str(j['start_date']),
        endDate: _str(j['end_date']),
        startTime: _str(j['start_time']),
        endTime: _str(j['end_time']),
        reason: _str(j['leave_reason']).trim(),
        days: _int(j['total_leave_days']),
        status: _int(j['status']),
      );
}

/// An employee feedback note from `GET /employee-feedback`.
/// feedback_type: 1 = Positive, 2 = Negative.
class FeedbackRecord {
  FeedbackRecord({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.text,
    required this.date,
  });

  final int id;
  final int employeeId;
  final int type; // 1 positive, 2 negative
  final String text;
  final String date;

  bool get isPositive => type == 1;

  factory FeedbackRecord.fromJson(Map<String, dynamic> j) => FeedbackRecord(
        id: _int(j['id']),
        employeeId: _int(j['employee_id']),
        type: _int(j['feedback_type']),
        text: _str(j['feedback']).trim(),
        date: _str(j['created_at']),
      );
}
