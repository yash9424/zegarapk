import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/api_models.dart';
import '../../services/api_client.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_format.dart';
import '../../widgets/user_avatar.dart';
import 'register_employee_page.dart';

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
  List<FeedbackRecord> _feedback = const [];
  List<NamedCount> _deductionTypes = const [];

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
        safe(api.employeeFeedback(widget.employeeId), <FeedbackRecord>[]),
        safe(api.deductionTypes(), <NamedCount>[]),
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
        _feedback = results[5] as List<FeedbackRecord>;
        _deductionTypes = results[6] as List<NamedCount>;
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
                builder: (_) => RegisterEmployeePage(
                  initialEmployeeId: widget.employeeId,
                  initialEmployeeName: name,
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
    (Icons.rate_review_outlined, 'Feedback'),
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
      case 6:
        return _feedbackTab();
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
        columns: const ['MONTH', 'NET SALARY', 'SLIP'],
        flex: const [4, 4, 3],
        onTapRow: (i) => _downloadSlip(_salaries[i]),
        rows: [
          for (final s in _salaries)
            [
              _twoLine('${_monthName(s.month)} ${s.year}', 'Base ${s.fixSalary}'),
              Text(s.netSalary,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('PDF',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
            ],
        ],
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('Tap a row to download that month\'s salary slip.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    ];
  }

  // ---- Tab: Leaves ---------------------------------------------------------

  List<Widget> _leavesTab() {
    final addBtn = _addButton('Apply', () => _leaveForm());
    if (_leaves.isEmpty) {
      return [
        _tableCard(
          header: 'LEAVE REQUESTS',
          columns: const ['DATES', 'REASON', 'STATUS'],
          flex: const [4, 4, 3],
          action: addBtn,
          rows: const [],
        ),
        const SizedBox(height: 12),
        _emptyState('No leave requests found.'),
      ];
    }
    return [
      _tableCard(
        header: 'LEAVE REQUESTS',
        columns: const ['DATES', 'REASON', 'STATUS'],
        flex: const [4, 4, 3],
        action: addBtn,
        onTapRow: (i) => _leaveActions(_leaves[i]),
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
    final addBtn = _addButton('Add', () => _advanceForm());
    if (_advances.isEmpty) {
      return [
        _tableCard(
          header: 'ADVANCES',
          columns: const ['MONTH', 'AMOUNT', 'STATUS'],
          flex: const [4, 4, 3],
          action: addBtn,
          rows: const [],
        ),
        const SizedBox(height: 12),
        _emptyState('No advances found.'),
      ];
    }
    return [
      _tableCard(
        header: 'ADVANCES',
        columns: const ['MONTH', 'AMOUNT', 'STATUS'],
        flex: const [4, 4, 3],
        action: addBtn,
        onTapRow: (i) => _advanceActions(_advances[i]),
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
    final addBtn = _addButton('Add', () => _deductionForm());
    if (_deductions.isEmpty) {
      return [
        _tableCard(
          header: 'DEDUCTIONS',
          columns: const ['TYPE', 'AMOUNT', 'DATE'],
          flex: const [4, 4, 3],
          action: addBtn,
          rows: const [],
        ),
        const SizedBox(height: 12),
        _emptyState('No deductions found.'),
      ];
    }
    return [
      _tableCard(
        header: 'DEDUCTIONS',
        columns: const ['TYPE', 'AMOUNT', 'DATE'],
        flex: const [4, 4, 3],
        action: addBtn,
        onTapRow: (i) => _deductionActions(_deductions[i]),
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

  // ---- Tab: Feedback -------------------------------------------------------

  List<Widget> _feedbackTab() {
    final addBtn = _addButton('Add', () => _feedbackForm());
    if (_feedback.isEmpty) {
      return [
        _tableCard(
          header: 'FEEDBACK',
          columns: const ['TYPE', 'NOTE', 'DATE'],
          flex: const [3, 5, 3],
          action: addBtn,
          rows: const [],
        ),
        const SizedBox(height: 12),
        _emptyState('No feedback yet.'),
      ];
    }
    return [
      _tableCard(
        header: 'FEEDBACK',
        columns: const ['TYPE', 'NOTE', 'DATE'],
        flex: const [3, 5, 3],
        action: addBtn,
        onTapRow: (i) => _feedbackActions(_feedback[i]),
        rows: [
          for (final f in _feedback)
            [
              f.isPositive
                  ? _statusPill('POSITIVE', _green, _greenBg)
                  : _statusPill('NEGATIVE', _red, _redBg),
              Text(f.text.isEmpty ? '—' : f.text,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppColors.textPrimary)),
              Text(_fmtDate(f.date),
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
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
  /// [action] is an optional widget shown at the right of the header (e.g. an
  /// "Add" button). [onTapRow] makes each row tappable (index passed back).
  Widget _tableCard({
    required String header,
    required List<String> columns,
    required List<int> flex,
    required List<List<Widget>> rows,
    Widget? action,
    void Function(int index)? onTapRow,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(header,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      )),
                ),
                ?action,
              ],
            ),
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
          for (var ri = 0; ri < rows.length; ri++)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapRow == null ? null : () => onTapRow(ri),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < rows[ri].length; i++)
                        Expanded(
                          flex: flex[i],
                          child: i == rows[ri].length - 1
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: rows[ri][i])
                              : rows[ri][i],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Small pill "+ Add" button used in table headers.
  Widget _addButton(String label, VoidCallback onTap) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 15, color: Colors.white),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
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

  // ---- Mutations: shared plumbing -----------------------------------------

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? _red : _green,
      ));
  }

  /// Runs a write [op] behind a blocking spinner, then reloads + toasts.
  Future<void> _run(Future<void> Function() op, String success) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      await op();
      if (mounted) Navigator.of(context).pop(); // close spinner
      _toast(success);
      await _load();
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast(e.message, error: true);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      _toast('Something went wrong. Please try again.', error: true);
    }
  }

  Future<void> _confirmRun(
      String question, Future<void> Function() op, String success) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please confirm'),
        content: Text(question),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (ok == true) await _run(op, success);
  }

  // ---- Bottom-sheet + form building blocks --------------------------------

  Future<void> _sheet(List<Widget> tiles) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 6),
            ...tiles,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label,
          style: TextStyle(fontWeight: FontWeight.w600, color: c)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  List<Widget> _dialogActions(BuildContext ctx, {String save = 'Save'}) => [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(save, style: const TextStyle(color: Colors.white)),
        ),
      ];

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  Widget _monthDropdown(int value, ValueChanged<int?> onCh) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        decoration: _dec('Month'),
        items: [
          for (var m = 1; m <= 12; m++)
            DropdownMenuItem(value: m, child: Text(_monthName(m))),
        ],
        onChanged: onCh,
      );

  Widget _yearDropdown(int value, ValueChanged<int?> onCh) {
    final now = DateTime.now().year;
    final years = <int>[for (var y = now - 3; y <= now + 1; y++) y];
    if (!years.contains(value)) years.insert(0, value);
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: _dec('Year'),
      items: [
        for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: onCh,
    );
  }

  Widget _choice(
      String label, bool active, Color color, Color bg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? bg : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? color : AppColors.fieldBorder,
              width: active ? 1.6 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: active ? color : AppColors.textSecondary)),
      ),
    );
  }

  Widget _pickerTile(String label, String value, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: _dec(label),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
      );

  String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String _fmtDmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtAmPm(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    var h = t.hour % 12;
    if (h == 0) h = 12;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  DateTime? _parseDmy(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    var part = s.trim();
    if (part.contains(' ')) part = part.split(' ').first;
    if (part.contains('T')) part = part.split('T').first;
    if (part.contains('/')) {
      final p = part.split('/');
      if (p.length == 3) {
        return DateTime.tryParse(
            '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
      }
    }
    return DateTime.tryParse(part);
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final up = s.toUpperCase();
    final pm = up.contains('PM');
    final am = up.contains('AM');
    final clean = up.replaceAll('AM', '').replaceAll('PM', '').trim();
    final b = clean.split(':');
    if (b.isEmpty) return null;
    var h = int.tryParse(b[0]) ?? 0;
    final m = b.length > 1 ? (int.tryParse(b[1]) ?? 0) : 0;
    if (pm && h < 12) h += 12;
    if (am && h == 12) h = 0;
    return TimeOfDay(hour: h % 24, minute: m % 60);
  }

  // ---- Salary slip ---------------------------------------------------------

  Future<void> _downloadSlip(SalaryRecord s) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      final bytes = await ZedgiftApi.instance.salarySlipBytes(s.id);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/salary_slip_${widget.employeeId}_${s.month}_${s.year}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) Navigator.of(context).pop();
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done) {
        _toast('Saved to ${file.path}');
      }
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast(e.message, error: true);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      _toast('Could not open the salary slip.', error: true);
    }
  }

  // ---- Advance: actions + form --------------------------------------------

  void _advanceActions(AdvanceRecord a) {
    _sheet([
      _sheetTile(Icons.edit_outlined, 'Edit advance',
          () => _advanceForm(existing: a)),
      if (!a.paid)
        _sheetTile(
            Icons.check_circle_outline, 'Mark as paid out',
            () => _confirmRun('Mark this advance as paid out?',
                () => ZedgiftApi.instance.payoutAdvance(a.id), 'Advance paid out'),
            color: _green),
      _sheetTile(
          Icons.delete_outline, 'Delete advance',
          () => _confirmRun('Delete this advance?',
              () => ZedgiftApi.instance.deleteAdvance(a.id), 'Advance deleted'),
          color: _red),
    ]);
  }

  Future<void> _advanceForm({AdvanceRecord? existing}) async {
    final now = DateTime.now();
    var month = existing?.month ?? now.month;
    var year = existing?.year ?? now.year;
    final amountCtl =
        TextEditingController(text: existing == null ? '' : _plain(existing.amountRaw));
    final remarkCtl = TextEditingController(text: existing?.remark ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Add advance' : 'Edit advance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: _monthDropdown(month, (m) => setS(() => month = m!))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _yearDropdown(year, (y) => setS(() => year = y!))),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: amountCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Amount (₹)')),
                const SizedBox(height: 12),
                TextField(
                    controller: remarkCtl,
                    decoration: _dec('Remark (optional)')),
              ],
            ),
          ),
          actions: _dialogActions(ctx),
        ),
      ),
    );
    if (ok == true) {
      final amount = amountCtl.text.trim();
      if (amount.isEmpty) {
        _toast('Enter an amount.', error: true);
      } else {
        await _run(
          () => existing == null
              ? ZedgiftApi.instance.createAdvance(
                  employeeId: widget.employeeId,
                  month: month,
                  year: year,
                  amount: amount,
                  remark: remarkCtl.text)
              : ZedgiftApi.instance.updateAdvance(existing.id,
                  employeeId: widget.employeeId,
                  month: month,
                  year: year,
                  amount: amount,
                  remark: remarkCtl.text),
          existing == null ? 'Advance added' : 'Advance updated',
        );
      }
    }
    amountCtl.dispose();
    remarkCtl.dispose();
  }

  // ---- Deduction: actions + form ------------------------------------------

  void _deductionActions(DeductionRecord d) {
    _sheet([
      _sheetTile(Icons.edit_outlined, 'Edit deduction',
          () => _deductionForm(existing: d)),
      _sheetTile(
          Icons.delete_outline, 'Delete deduction',
          () => _confirmRun('Delete this deduction?',
              () => ZedgiftApi.instance.deleteDeduction(d.id), 'Deduction deleted'),
          color: _red),
    ]);
  }

  Future<void> _deductionForm({DeductionRecord? existing}) async {
    if (_deductionTypes.isEmpty) {
      _toast('Deduction types are still loading. Try again in a moment.',
          error: true);
      return;
    }
    var typeId = existing?.typeId ?? _deductionTypes.first.id;
    if (!_deductionTypes.any((t) => t.id == typeId)) {
      typeId = _deductionTypes.first.id;
    }
    final amountCtl =
        TextEditingController(text: existing == null ? '' : _plain(existing.amountRaw));
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Add deduction' : 'Edit deduction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: typeId,
                  decoration: _dec('Type'),
                  items: [
                    for (final t in _deductionTypes)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setS(() => typeId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: amountCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Amount (₹)')),
                const SizedBox(height: 12),
                TextField(
                    controller: descCtl,
                    decoration: _dec('Description (optional)')),
              ],
            ),
          ),
          actions: _dialogActions(ctx),
        ),
      ),
    );
    if (ok == true) {
      final amount = amountCtl.text.trim();
      if (amount.isEmpty) {
        _toast('Enter an amount.', error: true);
      } else {
        await _run(
          () => existing == null
              ? ZedgiftApi.instance.createDeduction(
                  employeeId: widget.employeeId,
                  typeId: typeId,
                  amount: amount,
                  description: descCtl.text)
              : ZedgiftApi.instance.updateDeduction(existing.id,
                  employeeId: widget.employeeId,
                  typeId: typeId,
                  amount: amount,
                  description: descCtl.text),
          existing == null ? 'Deduction added' : 'Deduction updated',
        );
      }
    }
    amountCtl.dispose();
    descCtl.dispose();
  }

  // ---- Leave: actions + form ----------------------------------------------

  void _leaveActions(LeaveRecord l) {
    _sheet([
      if (l.status == 0) ...[
        _sheetTile(
            Icons.check_circle_outline, 'Approve',
            () => _confirmRun('Approve this leave?',
                () => ZedgiftApi.instance.approveLeave(l.id, status: 1),
                'Leave approved'),
            color: _green),
        _sheetTile(Icons.cancel_outlined, 'Reject', () => _rejectLeave(l),
            color: _red),
      ],
      _sheetTile(
          Icons.edit_outlined, 'Edit', () => _leaveForm(existing: l)),
      _sheetTile(
          Icons.delete_outline, 'Delete',
          () => _confirmRun('Delete this leave?',
              () => ZedgiftApi.instance.deleteLeave(l.id), 'Leave deleted'),
          color: _red),
    ]);
  }

  Future<void> _rejectLeave(LeaveRecord l) async {
    final remarkCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject leave'),
        content: TextField(
            controller: remarkCtl,
            maxLines: 2,
            decoration: _dec('Reason for rejection')),
        actions: _dialogActions(ctx, save: 'Reject'),
      ),
    );
    if (ok == true) {
      await _run(
          () => ZedgiftApi.instance
              .approveLeave(l.id, status: 2, remark: remarkCtl.text),
          'Leave rejected');
    }
    remarkCtl.dispose();
  }

  Future<void> _leaveForm({LeaveRecord? existing}) async {
    final now = DateTime.now();
    var start = _parseDmy(existing?.startDate) ?? now;
    var end = _parseDmy(existing?.endDate) ?? now;
    var startT = _parseTime(existing?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    var endT = _parseTime(existing?.endTime) ?? const TimeOfDay(hour: 18, minute: 0);
    final reasonCtl = TextEditingController(text: existing?.reason ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Apply leave' : 'Edit leave'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pickerTile('Start date', _fmtDmy(start), () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030));
                  if (d != null) setS(() => start = d);
                }),
                _pickerTile('End date', _fmtDmy(end), () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: end,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030));
                  if (d != null) setS(() => end = d);
                }),
                _pickerTile('Start time', _fmtAmPm(startT), () async {
                  final t = await showTimePicker(context: ctx, initialTime: startT);
                  if (t != null) setS(() => startT = t);
                }),
                _pickerTile('End time', _fmtAmPm(endT), () async {
                  final t = await showTimePicker(context: ctx, initialTime: endT);
                  if (t != null) setS(() => endT = t);
                }),
                TextField(
                    controller: reasonCtl,
                    maxLines: 2,
                    decoration: _dec('Reason')),
              ],
            ),
          ),
          actions: _dialogActions(ctx, save: existing == null ? 'Apply' : 'Save'),
        ),
      ),
    );
    if (ok == true) {
      final reason = reasonCtl.text.trim();
      if (reason.isEmpty) {
        _toast('Enter a reason.', error: true);
      } else {
        final sd = _fmtDmy(start);
        final ed = _fmtDmy(end);
        final st = _fmtAmPm(startT);
        final et = _fmtAmPm(endT);
        await _run(
          () => existing == null
              ? ZedgiftApi.instance.createLeave(
                  employeeId: widget.employeeId,
                  startDate: sd,
                  endDate: ed,
                  startTime: st,
                  endTime: et,
                  reason: reason)
              : ZedgiftApi.instance.updateLeave(existing.id,
                  employeeId: widget.employeeId,
                  startDate: sd,
                  endDate: ed,
                  startTime: st,
                  endTime: et,
                  reason: reason),
          existing == null ? 'Leave applied' : 'Leave updated',
        );
      }
    }
    reasonCtl.dispose();
  }

  // ---- Feedback: actions + form -------------------------------------------

  void _feedbackActions(FeedbackRecord f) {
    _sheet([
      _sheetTile(Icons.edit_outlined, 'Edit feedback',
          () => _feedbackForm(existing: f)),
      _sheetTile(
          Icons.delete_outline, 'Delete feedback',
          () => _confirmRun('Delete this feedback?',
              () => ZedgiftApi.instance.deleteFeedback(f.id), 'Feedback deleted'),
          color: _red),
    ]);
  }

  Future<void> _feedbackForm({FeedbackRecord? existing}) async {
    var type = existing?.type ?? 1;
    final textCtl = TextEditingController(text: existing?.text ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Add feedback' : 'Edit feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: _choice('Positive', type == 1, _green, _greenBg,
                          () => setS(() => type = 1))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _choice('Negative', type == 2, _red, _redBg,
                          () => setS(() => type = 2))),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: textCtl,
                    maxLines: 3,
                    decoration: _dec('Feedback')),
              ],
            ),
          ),
          actions: _dialogActions(ctx),
        ),
      ),
    );
    if (ok == true) {
      final text = textCtl.text.trim();
      if (text.isEmpty) {
        _toast('Enter feedback text.', error: true);
      } else {
        await _run(
          () => existing == null
              ? ZedgiftApi.instance.createFeedback(
                  employeeId: widget.employeeId, type: type, text: text)
              : ZedgiftApi.instance.updateFeedback(existing.id,
                  employeeId: widget.employeeId, type: type, text: text),
          existing == null ? 'Feedback added' : 'Feedback updated',
        );
      }
    }
    textCtl.dispose();
  }
}
