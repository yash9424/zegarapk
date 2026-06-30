import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_format.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/employee_picker_sheet.dart';
import '../../widgets/search_field.dart';
import 'employee_detail_page.dart';

/// One employee's attendance for the selected day. Built by merging the full
/// employee roster with the day's punches, so people with no punch still show
/// up (as Absent).
class _AttRow {
  _AttRow({
    required this.id,
    required this.name,
    required this.customId,
    required this.departmentName,
    required this.dutyIn,
    required this.dutyOut,
    required this.status,
  });

  final int id;
  final String name;
  final int customId;
  final String departmentName;
  final String dutyIn;
  final String dutyOut;
  final String status; // "in" / "out" / "" (absent)

  bool get present => status.isNotEmpty || dutyIn.isNotEmpty || dutyOut.isNotEmpty;
  bool get isIn => status.toLowerCase() == 'in';
}

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  final String _query = ''; // kept so _filtered compiles; search is now a sheet
  List<EmployeeListItem> _roster = const []; // lazy-loaded for the picker

  bool _loading = true;
  String? _error;

  DateTime _date = _today();
  final ScrollController _dayScroll = ScrollController();

  List<_AttRow> _rows = const [];

  static const _monthNames = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY',
    'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];
  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Day-cell width + horizontal margin — used to auto-scroll to the selection.
  static const double _dayCellExtent = 58;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Format the backend expects in the query string: yyyy-MM-dd.
  String get _dateParam => '${_date.year}-${_two(_date.month)}-${_two(_date.day)}';

  /// "OCTOBER 2025" — the month-dropdown label.
  String get _monthLabel => '${_monthNames[_date.month - 1]} ${_date.year}';

  int get _daysInMonth => DateTime(_date.year, _date.month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
  }

  @override
  void dispose() {
    _dayScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Only the day's punches — no full roster. Each punch already carries the
      // employee's name / department / in-out, so the page shows just the people
      // who actually punched (no Absent rows, no heavy 500+ employee fetch).
      final punches = await ZedgiftApi.instance.recentPunches(date: _dateParam);
      final rows = [
        for (final p in punches)
          _AttRow(
            id: p.employeeId,
            name: p.employeeName.isEmpty ? 'Unnamed' : p.employeeName,
            customId: p.customId,
            departmentName: p.departmentName,
            dutyIn: p.dutyIn,
            dutyOut: p.dutyOut,
            status: p.status,
          ),
      ];

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load attendance. Pull to retry.';
        _loading = false;
      });
    }
  }

  List<_AttRow> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.departmentName.toLowerCase().contains(q) ||
          r.customId.toString().contains(q);
    }).toList();
  }

  void _scrollToSelectedDay() {
    if (!_dayScroll.hasClients) return;
    final target = (_date.day - 1) * _dayCellExtent - 90;
    _dayScroll.jumpTo(target.clamp(0.0, _dayScroll.position.maxScrollExtent));
  }

  void _selectDay(DateTime day) {
    if (day == _date) return;
    setState(() => _date = day);
    _load();
  }

  /// Month/year dropdown — opens the native picker so the admin can jump to
  /// any month, then the day strip re-renders for that month.
  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _today(),
      helpText: 'Select date',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      final d = DateTime(picked.year, picked.month, picked.day);
      if (d != _date) {
        setState(() => _date = d);
        _load();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToSelectedDay());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(),
          _searchBar(),
          const SizedBox(height: 14),
          _dailyHeader(),
          _calendarBar(),
          const SizedBox(height: 12),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final list = _filtered;
    final present = list.length;
    final inCount = list.where((r) => r.isIn).length;
    final outCount = present - inCount;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _statRow(present, inCount, outCount),
          const SizedBox(height: 18),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text('No punches yet for this day.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
              ),
            )
          else
            for (final r in list) ...[
              _AttCard(row: r),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  Widget _appBar() {
    // Back goes to the Home tab.
    return AppHeader(
      leadingIcon: Icons.arrow_back,
      onLeadingTap: () => adminTab.value = 0,
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SearchField(
        hint: 'Search employees or departments...',
        onTap: _openPicker,
      ),
    );
  }

  /// Open the shared employee picker; on selection, show that employee's
  /// profile on the Attendance tab. Loads the roster lazily on first use.
  Future<void> _openPicker() async {
    if (_roster.isEmpty) {
      try {
        _roster = await ZedgiftApi.instance.employees();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Could not load employees.'),
            behavior: SnackBarBehavior.floating,
          ));
        return;
      }
    }
    if (!mounted) return;
    final picked = await pickEmployee(context, _roster);
    if (picked == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EmployeeDetailPage(
        employeeId: picked.id,
        fallbackName: picked.name,
        initialTab: 5, // Attendance tab
      ),
    ));
  }

  /// "Daily Attendance" title with the month dropdown on the right.
  Widget _dailyHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Daily Attendance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _monthDropdown(),
        ],
      ),
    );
  }

  Widget _monthDropdown() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _pickMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today,
                size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              _monthLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  /// Horizontal day strip with the selected day highlighted.
  Widget _calendarBar() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        controller: _dayScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _daysInMonth,
        itemBuilder: (_, i) => _dayCell(i + 1),
      ),
    );
  }

  Widget _dayCell(int day) {
    final cellDate = DateTime(_date.year, _date.month, day);
    final selected = day == _date.day;
    final isFuture = cellDate.isAfter(_today());
    final weekday = _weekdayShort[cellDate.weekday - 1];

    return GestureDetector(
      onTap: isFuture ? null : () => _selectDay(cellDate),
      child: Container(
        width: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.fieldBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : isFuture
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(int present, int inCount, int outCount) {
    return Row(
      children: [
        Expanded(
          child: _statCard(Icons.groups_2_rounded, 'Total Present', '$present',
              AttColors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
              Icons.login_rounded, 'Total In', '$inCount', AttColors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
              Icons.logout_rounded, 'Total Out', '$outCount', AttColors.orange),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The exact palette from the attendance design spec.
class AttColors {
  AttColors._();
  static const Color green = Color(0xFF0B8941); // Present / IN / Approved
  static const Color blue = Color(0xFF3B8EF6); // Total In
  static const Color orange = Color(0xFFF97316); // Total Out / Pending
  static const Color pink = Color(0xFFFFE0E2); // avatar tint
  static const Color slate = Color(0xFF64748B); // muted text
  static const Color ink = Color(0xFF0F172A); // strong text
  static const Color cloud = Color(0xFFF1F5F9); // chip background
}

class _AttCard extends StatelessWidget {
  const _AttCard({required this.row});
  final _AttRow row;

  /// "John M Wick" → "JW" (first + last word initials).
  String get _initials {
    final parts =
        row.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final inTime = to12Hour(row.dutyIn);
    final outTime = to12Hour(row.dutyOut);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EmployeeDetailPage(
              employeeId: row.id,
              fallbackName: row.name,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEF1F6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AttColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _badge(Icons.badge_outlined, 'ID: ${row.customId}'),
                            if (row.departmentName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: _badge(Icons.apartment_rounded,
                                    row.departmentName,
                                    muted: true),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEF1F6)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _timeCol('In Time', inTime, isIn: true),
                  _timeCol('Out Time', outTime, isIn: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AttColors.pink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, {bool muted = false}) {
    final color = muted ? AttColors.slate : AppColors.primary;
    final bg = muted ? AttColors.cloud : AppColors.softRedTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill() {
    final Color color;
    final String label;
    if (!row.present) {
      color = AttColors.slate;
      label = 'ABSENT';
    } else if (row.isIn) {
      color = AttColors.green;
      label = 'IN';
    } else {
      color = AttColors.orange;
      label = 'OUT';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }

  Widget _timeCol(String label, String value, {required bool isIn}) {
    final has = value.isNotEmpty;
    // In time reads green, Out time reads orange; both fade to slate when the
    // punch hasn't happened yet (shows "--:--").
    final accent = isIn ? AttColors.green : AttColors.orange;
    final shown = has ? accent : AttColors.slate;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AttColors.slate)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: shown),
              const SizedBox(width: 6),
              Text(
                has ? value : '--:--',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: shown,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
