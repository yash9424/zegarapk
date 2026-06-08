import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

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

  static const _chips = <(String, LeaveStatus?)>[
    ('All Requests', null),
    ('Pending', LeaveStatus.pending),
    ('Approved', LeaveStatus.approved),
    ('Rejected', LeaveStatus.rejected),
  ];

  List<LeaveRequest> get _filtered => _items
      .where((r) => _filter == null || r.status == _filter)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 0,
        onTap: (i) => goToAdminTab(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(),
            const SizedBox(height: 8),
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
        itemBuilder: (context, i) =>
            _LeaveCard(request: list[i], initiallyExpanded: i < 2),
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
    final range = [from, to].where((e) => e.isNotEmpty).join(' - ');

    return LeaveRequest(
      name: name.isEmpty ? 'Employee' : name,
      role: s(['designation', 'role']),
      department: s(['department', 'department_name']),
      employeeId: s(['custom_employee_id', 'employee_id', 'id']),
      leaveType: s(['leave_type', 'type']).isEmpty
          ? 'Leave'
          : s(['leave_type', 'type']),
      ref: '#${s(['id', 'ref'])}',
      status: status,
      dateRange: range.isEmpty ? s(['date', 'dates']) : range,
      duration: s(['days', 'duration', 'total_days']),
      reason: s(['reason', 'note', 'remark']),
      footerNote: s(['created_at', 'applied_at']),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            splashRadius: 22,
          ),
          const Spacer(),
          const ZegarLogo(fontSize: 22),
          const Spacer(),
          UserAvatar(
            name: MockAuth.instance.currentUser?.name ?? 'Admin',
            radius: 20,
            ring: true,
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, status) = _chips[i];
          final selected = _filter == status;
          return GestureDetector(
            onTap: () => setState(() => _filter = status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.fieldBorder,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
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

({IconData icon, Color color}) _leaveTypeStyle(String type) {
  final t = type.toLowerCase();
  if (t.contains('sick')) {
    return (icon: Icons.medical_services_outlined, color: AppColors.primary);
  }
  if (t.contains('annual')) {
    return (icon: Icons.beach_access_outlined, color: const Color(0xFF2BB673));
  }
  if (t.contains('personal')) {
    return (icon: Icons.person_outline, color: AppColors.primary);
  }
  return (icon: Icons.event_outlined, color: const Color(0xFF3B82C4));
}

// ---- Card ----------------------------------------------------------------

class _LeaveCard extends StatefulWidget {
  const _LeaveCard({required this.request, this.initiallyExpanded = true});
  final LeaveRequest request;
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
                await _showEditDialog(r);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApprove(LeaveRequest r) async {
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
    if (ok == true && mounted) _snack('✓ Leave approved for ${r.name}');
  }

  Future<void> _showRejectDialog(LeaveRequest r) async {
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
    ctrl.dispose();
    if (ok == true && mounted) _snack('✗ Leave rejected for ${r.name}');
  }

  Future<void> _showEditDialog(LeaveRequest r) async {
    final ctrl = TextEditingController(text: r.reason);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Leave Request',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Reason',
            filled: true,
            fillColor: AppColors.fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == true && mounted) _snack('Leave request updated (mock)');
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
                      if (_expanded) ...[
                        const SizedBox(height: 14),
                        _idLine(r),
                        const SizedBox(height: 14),
                        _typeRow(r),
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
                        const SizedBox(height: 12),
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

  Widget _header(LeaveRequest r, _StatusStyle status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                r.role,
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _statusBadge(status),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Icon(
            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppColors.textMuted,
          ),
        ),
      ],
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
    return Text(
      '${r.department} • ID: ${r.employeeId}',
      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
  }

  Widget _typeRow(LeaveRequest r) {
    final ts = _leaveTypeStyle(r.leaveType);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ts.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ts.icon, color: ts.color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.leaveType,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'REF: ${r.ref}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateDurationBox(LeaveRequest r) {
    Widget col(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          col('Date Range', r.dateRange),
          const SizedBox(width: 12),
          col('Duration', r.duration),
        ],
      ),
    );
  }

  Widget _reasonBlock(LeaveRequest r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reason',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text(
          '"${r.reason}"',
          style: const TextStyle(
            fontSize: 14,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            r.footerNote,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        if (r.status == LeaveStatus.pending) ...[
          _smallButton('Edit', AppColors.fieldFill, AppColors.textPrimary,
              () => _showEditDialog(r)),
          const SizedBox(width: 8),
          _smallButton('Review', AppColors.softRedTint, AppColors.primary,
              () => _showActions(r)),
        ] else if (r.status == LeaveStatus.approved)
          GestureDetector(
            onTap: () => _showActions(r),
            child: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
          )
        else
          const Icon(Icons.history, size: 20, color: AppColors.textMuted),
      ],
    );
  }

  Widget _smallButton(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
