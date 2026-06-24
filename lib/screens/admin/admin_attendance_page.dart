import 'package:flutter/material.dart';

import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_format.dart';
import '../../widgets/search_field.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';
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
  final _searchCtrl = TextEditingController();
  String _query = '';

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
    _searchCtrl.dispose();
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
    final name = MockAuth.instance.currentUser?.name ?? 'Admin';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            splashRadius: 22,
          ),
          const Spacer(),
          const ZegarLogo(fontSize: 22),
          const Spacer(),
          UserAvatar(name: name, radius: 20, ring: true),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SearchField(
        controller: _searchCtrl,
        hint: 'Search employees or departments...',
        onChanged: (v) => setState(() => _query = v),
        onClear: () {
          _searchCtrl.clear();
          setState(() => _query = '');
        },
        hasText: _query.isNotEmpty,
      ),
    );
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
        Expanded(child: _statCard('PRESENT', '$present', AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('IN', '$inCount', const Color(0xFF2BB673))),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('OUT', '$outCount', const Color(0xFFB8860B))),
      ],
    );
  }

  Widget _statCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttCard extends StatelessWidget {
  const _AttCard({required this.row});
  final _AttRow row;

  @override
  Widget build(BuildContext context) {
    final sub = [
      'ID ${row.customId}',
      if (row.departmentName.isNotEmpty) row.departmentName,
    ].join(' • ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  UserAvatar(name: row.name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  _timeCol('In Time', to12Hour(row.dutyIn)),
                  _timeCol('Out Time', to12Hour(row.dutyOut)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge() {
    final Color color;
    final Color bg;
    final String label;
    if (!row.present) {
      color = const Color(0xFFB23A48);
      bg = const Color(0xFFFBE3E6);
      label = 'ABSENT';
    } else if (row.isIn) {
      color = const Color(0xFF2BB673);
      bg = const Color(0xFFE7F7EF);
      label = 'IN';
    } else {
      color = const Color(0xFFB8860B);
      bg = const Color(0xFFFBF3D9);
      label = 'OUT';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Widget _timeCol(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
