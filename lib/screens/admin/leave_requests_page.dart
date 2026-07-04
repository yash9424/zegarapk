import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/search_field.dart';
import '../leave_form_page.dart';

class LeaveRequestsPage extends StatefulWidget {
  const LeaveRequestsPage({super.key});

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  LeaveStatus? _filter; // null = All Requests

  bool _loading = true;
  String? _error;
  List<LeaveRequest> _items = const [];

  // Search + Month/Year filters (same as the other list pages).
  final _searchCtl = TextEditingController();
  String _q = '';
  late int _month;
  late int _year;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ZedgiftApi.instance.leaves();
      if (!mounted) return;
      setState(() {
        _items = rows.map(_mapLeave).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load leave requests.';
        _loading = false;
      });
    }
  }

  static const _green = Color(0xFF2BB673);
  static const _orange = Color(0xFFE8923B);

  static const _chips = <(String, LeaveStatus?, IconData, Color)>[
    ('All Requests', null, Icons.description_rounded, AppColors.primary),
    ('Pending', LeaveStatus.pending, Icons.access_time_rounded, _orange),
    ('Approved', LeaveStatus.approved, Icons.check_circle_rounded, _green),
  ];

  /// Status chip + search text + month/year (a leave matches when its date
  /// range overlaps the selected month).
  List<LeaveRequest> get _filtered {
    final q = _q.trim().toLowerCase();
    return _items.where((r) {
      if (_filter != null && r.status != _filter) return false;
      if (!_inSelectedMonth(r)) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.employeeId.toLowerCase().contains(q) ||
          r.department.toLowerCase().contains(q) ||
          r.role.toLowerCase().contains(q);
    }).toList();
  }

  bool _inSelectedMonth(LeaveRequest r) {
    final a = parseApiDateTime(r.rawStart);
    final b = parseApiDateTime(r.rawEnd);
    if (a == null && b == null) return true; // unparseable — never hide it
    final start = a ?? b!;
    final end = b ?? a!;
    final mStart = DateTime(_year, _month, 1);
    final mEnd = DateTime(_year, _month + 1, 0, 23, 59, 59);
    return !start.isAfter(mEnd) && !end.isBefore(mStart);
  }

  Future<void> _newLeave() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LeaveFormPage()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _newLeave,
        icon: const Icon(Icons.add),
        label: const Text('New Leave'),
      ),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 0,
        onTap: (i) => goToAdminTab(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(),
            _titleRow(),
            _searchBar(),
            const SizedBox(height: 10),
            _filterChips(),
            const SizedBox(height: 8),
            Expanded(child: _listArea()),
          ],
        ),
      ),
    );
  }

  Widget _listArea() {
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
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text('No leave requests.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, i) => _LeaveCard(
          request: list[i],
          initiallyExpanded: false, // all cards start collapsed
          onChanged: _load,
        ),
      ),
    );
  }

  // Defensive mapping — the /leaves response shape isn't documented, so we
  // read several possible field names and fall back gracefully.
  LeaveRequest _mapLeave(Map<String, dynamic> j) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    final emp = (j['employee'] as Map?)?.cast<String, dynamic>();
    final name = s(['employee_name', 'name']).isNotEmpty
        ? s(['employee_name', 'name'])
        : (emp == null ? '' : (emp['name']?.toString() ?? ''));

    final rawStatus = s(['status', 'leave_status']).toLowerCase();
    LeaveStatus status;
    if (rawStatus.contains('approve') || rawStatus == '1') {
      status = LeaveStatus.approved;
    } else if (rawStatus.contains('reject') || rawStatus == '2') {
      status = LeaveStatus.rejected;
    } else {
      status = LeaveStatus.pending;
    }

    final from = s(['from_date', 'start_date', 'leave_from', 'date_from']);
    final to = s(['to_date', 'end_date', 'leave_to', 'date_to']);

    // Role / department / employee-id live inside the nested `employee` object.
    String empSub(String group, String key) {
      final g = emp?[group];
      if (g is Map) return (g[key]?.toString() ?? '').trim();
      return '';
    }

    final role = empSub('designation', 'name').isNotEmpty
        ? empSub('designation', 'name')
        : s(['designation', 'role']);
    final department = empSub('department', 'name').isNotEmpty
        ? empSub('department', 'name')
        : s(['department', 'department_name']);
    final customId = (emp?['custom_employee_id']?.toString().trim() ?? '')
            .isNotEmpty
        ? emp!['custom_employee_id'].toString().trim()
        : s(['custom_employee_id', 'employee_id', 'id']);

    // Leave type comes back as a number — show a generic label for it.
    final rawType = s(['leave_type', 'type']);
    final leaveType =
        (rawType.isEmpty || int.tryParse(rawType) != null) ? 'Leave' : rawType;

    // Duration like "4 Days".
    final days = s(['total_leave_days', 'days', 'duration', 'total_days']);
    final duration = days.isEmpty
        ? ''
        : (int.tryParse(days) != null
            ? '$days ${days == '1' ? 'Day' : 'Days'}'
            : days);

    final empNumId = int.tryParse(s(['employee_id'])) ??
        (emp == null ? 0 : int.tryParse(emp['id']?.toString() ?? '') ?? 0);

    return LeaveRequest(
      name: name.isEmpty ? 'Employee' : name,
      role: role,
      department: department,
      employeeId: customId,
      leaveType: leaveType,
      ref: '#${s(['id', 'ref'])}',
      status: status,
      dateRange: _fmtRange(from, to),
      duration: duration,
      reason: s(['leave_reason', 'reason', 'note', 'remark']),
      footerNote: s(['created_at', 'applied_at']),
      leaveId: int.tryParse(s(['id'])) ?? 0,
      empNumId: empNumId,
      rawStart: from,
      rawEnd: to,
    );
  }

  /// Format a leave's start/end as "27 Jun - 30 Jun, 2026" (day month, year).
  String _fmtRange(String from, String to) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final a = parseApiDateTime(from);
    final b = parseApiDateTime(to);
    String d(DateTime t) => '${t.day} ${m[t.month - 1]}';
    if (a != null && b != null) {
      return a.year == b.year
          ? '${d(a)} - ${d(b)}, ${a.year}'
          : '${d(a)}, ${a.year} - ${d(b)}, ${b.year}';
    }
    final only = a ?? b;
    if (only != null) return '${d(only)}, ${only.year}';
    String dateOnly(String v) => v.contains(' ') ? v.split(' ').first : v;
    return [dateOnly(from), dateOnly(to)]
        .where((e) => e.isNotEmpty)
        .join(' - ');
  }

  Widget _appBar() {
    return const AppHeader(leadingIcon: Icons.arrow_back);
  }

  /// Page heading styled like the Home greeting (red 19px title + small grey
  /// subtext) with the Month / Year filter pills on the right.
  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaves',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage leave requests and approvals',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _filterPill(label: _months[_month - 1], onTap: _pickMonth),
          const SizedBox(width: 8),
          _filterPill(label: '$_year', onTap: _pickYear),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SearchField(
        controller: _searchCtl,
        hint: 'Search employee name or ID...',
        hasText: _q.isNotEmpty,
        onChanged: (v) => setState(() => _q = v),
        onClear: () {
          _searchCtl.clear();
          setState(() => _q = '');
        },
      ),
    );
  }

  Widget _filterPill({required String label, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    const full = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final picked = await _pickFromSheet<int>(
      title: 'Select Month',
      items: [for (var m = 1; m <= 12; m++) (m, full[m - 1])],
      selected: _month,
    );
    if (picked != null && picked != _month) {
      setState(() => _month = picked);
    }
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final years = [for (var y = now.year - 4; y <= now.year + 1; y++) y];
    final picked = await _pickFromSheet<int>(
      title: 'Select Year',
      items: [for (final y in years) (y, '$y')],
      selected: _year,
    );
    if (picked != null && picked != _year) {
      setState(() => _year = picked);
    }
  }

  Future<T?> _pickFromSheet<T>({
    required String title,
    required List<(T, String)> items,
    required T selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final it in items)
                    ListTile(
                      title: Text(it.$2,
                          style: TextStyle(
                            fontWeight: it.$1 == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: it.$1 == selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          )),
                      trailing: it.$1 == selected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 20)
                          : null,
                      onTap: () => Navigator.pop(ctx, it.$1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, status, icon, accent) = _chips[i];
          final selected = _filter == status;
          return GestureDetector(
            onTap: () => setState(() => _filter = status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.fieldBorder,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 17,
                      color: selected ? Colors.white : accent),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

// ---- Status helpers ------------------------------------------------------

class _StatusStyle {
  const _StatusStyle(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;
}

_StatusStyle _statusStyle(LeaveStatus s) {
  switch (s) {
    case LeaveStatus.approved:
      return const _StatusStyle(
          'Approved', Color(0xFF2BB673), Color(0xFFE7F7EF));
    case LeaveStatus.pending:
      return const _StatusStyle(
          'Pending', Color(0xFFE8923B), Color(0xFFFCEFE0));
    case LeaveStatus.rejected:
      return const _StatusStyle(
          'Rejected', AppColors.primary, AppColors.softRedTint);
  }
}

// ---- Card ----------------------------------------------------------------

class _LeaveCard extends StatefulWidget {
  const _LeaveCard({
    required this.request,
    required this.onChanged,
    this.initiallyExpanded = true,
  });
  final LeaveRequest request;
  final VoidCallback onChanged;
  final bool initiallyExpanded;

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _showActions(LeaveRequest r) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('${r.leaveType} — ${r.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF2BB673)),
              title: const Text('Approve',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2BB673))),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmApprove(r);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.cancel_outlined, color: AppColors.primary),
              title: const Text('Reject',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
              onTap: () async {
                Navigator.pop(ctx);
                await _showRejectDialog(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                await _openEdit(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.primary),
              title: const Text('Delete',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmDelete(r);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Leaves loaded from the live API carry a real [leaveId]; the static demo
  /// rows don't, so actions are only available on real records.
  bool _guardLive(LeaveRequest r) {
    if (r.leaveId > 0) return true;
    _snack('This action is only available on live leave records.');
    return false;
  }

  Future<void> _confirmApprove(LeaveRequest r) async {
    if (!_guardLive(r)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Leave?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Approve ${r.leaveType} for ${r.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve',
                  style: TextStyle(
                      color: Color(0xFF2BB673),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ZedgiftApi.instance.approveLeave(r.leaveId, status: 1);
      if (!mounted) return;
      _snack('✓ Leave approved for ${r.name}');
      widget.onChanged();
    } catch (_) {
      _snack('Could not approve. Please try again.');
    }
  }

  Future<void> _showRejectDialog(LeaveRequest r) async {
    if (!_guardLive(r)) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Leave?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejecting ${r.leaveType} for ${r.name}.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection note (required)',
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Reject',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    try {
      await ZedgiftApi.instance
          .approveLeave(r.leaveId, status: 2, remark: note);
      if (!mounted) return;
      _snack('✗ Leave rejected for ${r.name}');
      widget.onChanged();
    } catch (_) {
      _snack('Could not reject. Please try again.');
    }
  }

  Future<void> _openEdit(LeaveRequest r) async {
    if (!_guardLive(r)) return;
    final start = parseApiDateTime(r.rawStart);
    final end = parseApiDateTime(r.rawEnd);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LeaveFormPage(
          editLeaveId: r.leaveId,
          fixedEmployeeId: r.empNumId,
          fixedEmployeeName: r.name,
          initialStart: start,
          initialEnd: end,
          initialStartTime: start == null ? null : TimeOfDay.fromDateTime(start),
          initialEndTime: end == null ? null : TimeOfDay.fromDateTime(end),
          initialReason: r.reason,
        ),
      ),
    );
    if (changed == true) widget.onChanged();
  }

  Future<void> _confirmDelete(LeaveRequest r) async {
    if (!_guardLive(r)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Leave?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Permanently delete ${r.leaveType} for ${r.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ZedgiftApi.instance.deleteLeave(r.leaveId);
      if (!mounted) return;
      _snack('Leave deleted.');
      widget.onChanged();
    } catch (_) {
      _snack('Could not delete. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final status = _statusStyle(r.status);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: status.color),
              Expanded(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(r, status),
                      const SizedBox(height: 12),
                      _idLine(r),
                      if (_expanded) ...[
                        const SizedBox(height: 14),
                        _dateDurationBox(r),
                        const SizedBox(height: 14),
                        if (r.status == LeaveStatus.rejected &&
                            r.rejectionNote != null)
                          _rejectionBox(r)
                        else
                          _reasonBlock(r),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: 14),
                        _footer(r),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final p = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
  }

  Widget _avatar(_StatusStyle status) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(widget.request.name),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: status.color,
        ),
      ),
    );
  }

  Widget _header(LeaveRequest r, _StatusStyle status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(status),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  r.role.isEmpty ? 'Default Designation' : r.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _statusBadge(status),
        const SizedBox(width: 2),
        _trailingControl(r),
      ],
    );
  }

  Widget _trailingControl(LeaveRequest r) {
    if (r.status == LeaveStatus.pending) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showActions(r),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.more_vert, color: AppColors.textMuted),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _statusBadge(_StatusStyle status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _idLine(LeaveRequest r) {
    return Row(
      children: [
        const Icon(Icons.apartment_rounded,
            size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            r.department.isEmpty ? '—' : r.department,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        const Text('•', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(width: 8),
        const Icon(Icons.badge_outlined,
            size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          'ID: ${r.employeeId}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _dateDurationBox(LeaveRequest r) {
    Widget col(IconData icon, String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(Icons.calendar_today_rounded, 'Date Range', r.dateRange),
          const SizedBox(width: 12),
          col(Icons.access_time_rounded, 'Duration', r.duration),
        ],
      ),
    );
  }

  Widget _reasonBlock(LeaveRequest r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('Reason',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          r.reason.isEmpty ? '—' : '"${r.reason}"',
          style: const TextStyle(
            fontSize: 14.5,
            fontStyle: FontStyle.italic,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _rejectionBox(LeaveRequest r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softRedTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rejection Note',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              )),
          const SizedBox(height: 6),
          Text(
            '"${r.rejectionNote}"',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(LeaveRequest r) {
    final pending = r.status == LeaveStatus.pending;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _smallButton('Edit', Icons.edit_outlined, AppColors.fieldFill,
            AppColors.textPrimary, () => _openEdit(r)),
        const SizedBox(width: 10),
        if (pending)
          _smallButton('Review', Icons.visibility_outlined,
              AppColors.softRedTint, AppColors.primary, () => _showActions(r))
        else
          _smallButton('Delete', Icons.delete_outline, AppColors.softRedTint,
              AppColors.primary, () => _confirmDelete(r)),
      ],
    );
  }

  Widget _smallButton(
      String label, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
