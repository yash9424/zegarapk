import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_format.dart';
import '../../widgets/user_avatar.dart';
import 'face_enroll_page.dart';

/// Full employee profile in a tabbed layout — Personal, Payroll, Leaves,
/// Advance, Deductions and Attendance — each backed by the live ZedGift API.
class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({
    super.key,
    required this.employeeId,
    this.fallbackName = '',
  });

  final int employeeId;
  final String fallbackName;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  bool _loading = true;
  String? _error;
  int _tab = 0;

  EmployeeDetail? _emp;
  List<AttendanceHistoryDay> _history = const [];
  List<SalaryRecord> _salaries = const [];
  List<AdvanceRecord> _advances = const [];
  List<DeductionRecord> _deductions = const [];
  List<LeaveRecord> _leaves = const [];

  static const _green = Color(0xFF2BB673);
  static const _greenBg = Color(0xFFE7F7EF);
  static const _amber = Color(0xFFB8860B);
  static const _amberBg = Color(0xFFFBF3D9);
  static const _red = Color(0xFFB23A48);
  static const _redBg = Color(0xFFFBE3E6);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ZedgiftApi.instance;
      final emp = await api.employeeDetail(widget.employeeId);

      // Everything else is best-effort — a failure in one tab's data must not
      // block the profile. Each future swallows its own error to [].
      Future<T> safe<T>(Future<T> f, T fallback) =>
          f.then((v) => v).catchError((_) => fallback);

      final now = DateTime.now();
      final salaryFutures = [
        for (var i = 0; i < 6; i++)
          api.salaryForMonth(
            widget.employeeId,
            DateTime(now.year, now.month - i, 1).month,
            DateTime(now.year, now.month - i, 1).year,
          ),
      ];

      final results = await Future.wait([
        safe(api.attendanceHistory(widget.employeeId), <AttendanceHistoryDay>[]),
        safe(Future.wait(salaryFutures), <SalaryRecord?>[]),
        safe(api.advances(widget.employeeId), <AdvanceRecord>[]),
        safe(api.deductions(widget.employeeId), <DeductionRecord>[]),
        safe(api.employeeLeaves(widget.employeeId), <LeaveRecord>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _emp = emp;
        _history = results[0] as List<AttendanceHistoryDay>;
        _salaries =
            (results[1] as List<SalaryRecord?>).whereType<SalaryRecord>().toList();
        _advances = results[2] as List<AdvanceRecord>;
        _deductions = results[3] as List<DeductionRecord>;
        _leaves = results[4] as List<LeaveRecord>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this employee.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _emp?.name.isNotEmpty == true
        ? _emp!.name
        : (widget.fallbackName.isEmpty ? 'Employee' : widget.fallbackName);
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Register Face',
            icon: const Icon(Icons.face_retouching_natural),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FaceEnrollPage(
                  employeeId: widget.employeeId,
                  employeeName: name,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _emp == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error ?? 'Not found',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _headerCard(_emp!),
          const SizedBox(height: 18),
          _tabBar(),
          const SizedBox(height: 18),
          ..._tabContent(),
        ],
      ),
    );
  }

  // ---- Header --------------------------------------------------------------

  Widget _headerCard(EmployeeDetail e) {
    final sub = [e.designationName, e.departmentName]
        .where((s) => s.isNotEmpty)
        .join(' • ');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          UserAvatar(name: e.name, radius: 40, ring: true),
          const SizedBox(height: 14),
          Text(
            e.name.isEmpty ? 'Unnamed' : e.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _chip(Icons.badge_outlined, 'ID: ${e.customId}',
                  AppColors.softRedTint, AppColors.primary),
              if (e.typeName.isNotEmpty)
                _chip(Icons.work_outline, e.typeName, const Color(0xFFEDEFF4),
                    AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  // ---- Tabs ----------------------------------------------------------------

  static const _tabs = <(IconData, String)>[
    (Icons.person_outline, 'Personal'),
    (Icons.receipt_long_outlined, 'Payroll'),
    (Icons.event_busy_outlined, 'Leaves'),
    (Icons.payments_outlined, 'Advance'),
    (Icons.remove_circle_outline, 'Deductions'),
    (Icons.access_time, 'Attendance'),
  ];

  Widget _tabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _tabItem(i, _tabs[i].$1, _tabs[i].$2),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int i, IconData icon, String label) {
    final active = _tab == i;
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 2.5,
            width: 60,
            color: active ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  List<Widget> _tabContent() {
    switch (_tab) {
      case 1:
        return _payrollTab();
      case 2:
        return _leavesTab();
      case 3:
        return _advanceTab();
      case 4:
        return _deductionsTab();
      case 5:
        return _attendanceTab();
      default:
        return _personalTab();
    }
  }

  // ---- Tab: Personal -------------------------------------------------------

  List<Widget> _personalTab() {
    final e = _emp!;
    return [
      _section('Work', [
        _kv('Employee ID', e.customId.toString()),
        _kv('Department', e.departmentName),
        _kv('Designation', e.designationName),
        _kv('Type', e.typeName),
        _kv('Date of joining', e.doj),
        _kv('Previous company', e.previousCompany),
      ]),
      const SizedBox(height: 14),
      _section('Personal', [
        _kv('Phone', e.phone),
        _kv('Emergency', e.emergencyPhone),
        _kv('Education', e.education),
        _kv('Date of birth', e.dob),
        _kv('Current city', e.currentState),
        _kv('Current address', e.currentAddress),
        _kv('Permanent address', e.permanentAddress),
      ]),
      const SizedBox(height: 14),
      _section('Salary', [
        _kv('Salary', e.salary),
        _kv('Net salary', e.netSalary),
      ]),
      if (e.banks.isNotEmpty) ...[
        const SizedBox(height: 14),
        _section('Bank', [
          for (final b in e.banks) ...[
            _kv('Bank', b.bankName),
            _kv('A/C holder', b.holderName),
            _kv('A/C number', b.accountNumber),
            _kv('IFSC', b.ifsc),
            _kv('Branch', b.branch),
          ],
        ]),
      ],
    ];
  }

  // ---- Tab: Payroll --------------------------------------------------------

  List<Widget> _payrollTab() {
    if (_salaries.isEmpty) {
      return [_emptyState('No payroll records found.')];
    }
    return [
      _tableCard(
        header: 'EARNINGS RECORDS',
        columns: const ['MONTH', 'NET SALARY', 'STATUS'],
        flex: const [4, 4, 3],
        rows: [
          for (final s in _salaries)
            [
              _twoLine('${_monthName(s.month)} ${s.year}', 'Base ${s.fixSalary}'),
              Text(s.netSalary,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              _statusPill(s.paid ? 'PAID' : 'PENDING',
                  s.paid ? _green : _amber, s.paid ? _greenBg : _amberBg),
            ],
        ],
      ),
    ];
  }

  // ---- Tab: Leaves ---------------------------------------------------------

  List<Widget> _leavesTab() {
    if (_leaves.isEmpty) {
      return [_emptyState('No leave requests found.')];
    }
    return [
      _tableCard(
        header: 'LEAVE REQUESTS',
        columns: const ['DATES', 'REASON', 'STATUS'],
        flex: const [4, 4, 3],
        rows: [
          for (final l in _leaves)
            [
              _twoLine(_fmtDate(l.startDate),
                  '${l.days} day${l.days == 1 ? '' : 's'}'),
              Text(l.reason.isEmpty ? '—' : l.reason,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppColors.textPrimary)),
              _leaveStatusPill(l.status),
            ],
        ],
      ),
    ];
  }

  // ---- Tab: Advance --------------------------------------------------------

  List<Widget> _advanceTab() {
    if (_advances.isEmpty) {
      return [_emptyState('No advances found.')];
    }
    return [
      _tableCard(
        header: 'ADVANCES',
        columns: const ['MONTH', 'AMOUNT', 'STATUS'],
        flex: const [4, 4, 3],
        rows: [
          for (final a in _advances)
            [
              _twoLine('${_monthName(a.month)} ${a.year}',
                  a.remark.isEmpty ? '' : a.remark),
              Text(a.amount,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              _statusPill(a.paid ? 'PAID' : 'UNPAID',
                  a.paid ? _green : _amber, a.paid ? _greenBg : _amberBg),
            ],
        ],
      ),
    ];
  }

  // ---- Tab: Deductions -----------------------------------------------------

  List<Widget> _deductionsTab() {
    if (_deductions.isEmpty) {
      return [_emptyState('No deductions found.')];
    }
    return [
      _tableCard(
        header: 'DEDUCTIONS',
        columns: const ['TYPE', 'AMOUNT', 'DATE'],
        flex: const [4, 4, 3],
        rows: [
          for (final d in _deductions)
            [
              _twoLine(d.typeName,
                  d.description.isEmpty ? '' : d.description),
              Text(d.amount,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _red)),
              Text(_fmtDate(d.date),
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
        ],
      ),
    ];
  }

  // ---- Tab: Attendance -----------------------------------------------------

  List<Widget> _attendanceTab() {
    if (_history.isEmpty) {
      return [_emptyState('No attendance records found.')];
    }
    return [
      _tableCard(
        header: 'RECENT ATTENDANCE',
        columns: const ['DATE', 'IN', 'OUT'],
        flex: const [4, 3, 3],
        rows: [
          for (final d in _history)
            [
              Text(_fmtDate(d.date),
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(to12Hour(d.dutyIn).isEmpty ? '—' : to12Hour(d.dutyIn),
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(to12Hour(d.dutyOut).isEmpty ? '—' : to12Hour(d.dutyOut),
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
        ],
      ),
    ];
  }

  // ---- Shared building blocks ---------------------------------------------

  Widget _section(String title, List<Widget> rows) {
    final visible = rows.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    final v = value.trim();
    if (v.isEmpty || v == '0' || v == '1970-01-01') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  /// A bordered card with a tinted header strip and a simple data table.
  Widget _tableCard({
    required String header,
    required List<String> columns,
    required List<int> flex,
    required List<List<Widget>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.fieldFill,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.centerLeft,
            child: Text(header,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(flex: flex[i], child: _colLabel(columns[i])),
              ],
            ),
          ),
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < r.length; i++)
                    Expanded(
                      flex: flex[i],
                      child: i == r.length - 1
                          ? Align(alignment: Alignment.centerLeft, child: r[i])
                          : r[i],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _twoLine(String top, String bottom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(top,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppColors.textPrimary)),
        if (bottom.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(bottom,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _colLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.textSecondary,
        ),
      );

  Widget _statusPill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: fg,
          )),
    );
  }

  Widget _leaveStatusPill(int status) {
    switch (status) {
      case 1:
        return _statusPill('APPROVED', _green, _greenBg);
      case 2:
        return _statusPill('REJECTED', _red, _redBg);
      default:
        return _statusPill('PENDING', _amber, _amberBg);
    }
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Text(text,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ),
    );
  }

  String _monthName(int m) =>
      (m >= 1 && m <= 12) ? _months[m - 1] : m.toString();

  /// "2026-05-27" / "2026-06-20 08:00:00" → "27 May 2026".
  String _fmtDate(String s) {
    if (s.isEmpty) return '—';
    final datePart = s.contains('T')
        ? s.split('T').first
        : (s.contains(' ') ? s.split(' ').first : s);
    final p = datePart.split('-');
    if (p.length == 3) {
      final y = p[0];
      final mo = int.tryParse(p[1]) ?? 0;
      final d = int.tryParse(p[2])?.toString() ?? p[2];
      return '$d ${_monthName(mo)} $y';
    }
    return s;
  }
}
