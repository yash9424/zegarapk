import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import 'activity_logs_page.dart';
import 'employee_directory_page.dart';
import 'leave_requests_page.dart';
import 'salary_page.dart';
import 'select_employee_page.dart';

/// Admin dashboard home — greeting + date, quick stats, coloured action cards
/// and a welcome banner.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.user});

  final AuthUser user;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  // Live counts shown in the stat row (from GET /dashboard/stats).
  int? _employees;
  int? _onLeave;
  int? _advances;
  String? _payroll;

  // Recent activity feed (latest 5 from GET /activity-logs/summary).
  List<ActivityLog> _recent = const [];
  bool _recentLoading = true;
  bool _recentError = false;

  // Drives the staggered entrance of the menu list.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Accent palette per section.
  static const _red = AppColors.primary;
  static const _purple = Color(0xFF7C5CFC);
  static const _green = Color(0xFF2BB673);
  static const _orange = Color(0xFFE8923B);
  static const _blue = Color(0xFF3B82C4);
  static const _violet = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _load();
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadStats(), _loadRecent()]);
  }

  Future<void> _loadStats() async {
    try {
      final s = await ZedgiftApi.instance.dashboardStats();
      if (mounted) {
        setState(() {
          _employees = s.employees;
          _onLeave = s.onLeave;
          _advances = s.advances;
          _payroll = s.payrollLabel;
        });
      }
      return;
    } catch (_) {
      // Fall back to per-endpoint counts if the dashboard call fails.
    }
    try {
      final emps = await ZedgiftApi.instance.employees();
      if (mounted) setState(() => _employees = emps.length);
    } catch (_) {}
    try {
      final leaves = await ZedgiftApi.instance.leaves();
      if (mounted) setState(() => _onLeave = leaves.length);
    } catch (_) {}
  }

  Future<void> _loadRecent() async {
    if (mounted) setState(() => _recentLoading = true);
    try {
      final res = await ZedgiftApi.instance.activityLogs(page: 1);
      if (!mounted) return;
      setState(() {
        _recent = res.items.take(5).toList();
        _recentLoading = false;
        _recentError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentLoading = false;
        _recentError = true;
      });
    }
  }

  String get _dayName {
    final n = DateTime.now();
    return _weekdays[n.weekday - 1];
  }

  String get _dateLabel {
    final n = DateTime.now();
    return '${n.day} ${_months[n.month - 1]} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          AppHeader(
            leadingIcon: Icons.menu,
            onLeadingTap: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    _greeting(),
                    const SizedBox(height: 14),
                    _statsRow(),
                    const SizedBox(height: 20),
                    _menuGrid(context),
                    const SizedBox(height: 22),
                    _activitySection(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Greeting + date -----------------------------------------------------

  Widget _greeting() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.user.name.isEmpty ? 'Admin' : widget.user.name,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Administrator',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _dateCard(),
      ],
    );
  }

  Widget _dateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_dayName,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(_dateLabel,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Stats row -----------------------------------------------------------

  Widget _statsRow() {
    final stats = <(IconData, Color, String, String)>[
      (Icons.groups_2_rounded, _red, _employees?.toString() ?? '0',
          'Employees'),
      (Icons.calendar_month_rounded, _purple, _onLeave?.toString() ?? '0',
          'On Leave'),
      (Icons.account_balance_wallet_rounded, _green, _advances?.toString() ?? '0',
          'Advances'),
      (Icons.payments_rounded, _orange, _payroll ?? '₹0', 'Total Payroll'),
    ];
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(child: _statCard(stats[i])),
          if (i != stats.length - 1) const SizedBox(width: 9),
        ],
      ],
    );
  }

  Widget _statCard((IconData, Color, String, String) s) {
    final accent = s.$2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Rounded-square tinted icon tile.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.$1, color: accent, size: 19),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              s.$3,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              s.$4,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Action cards --------------------------------------------------------

  Widget _menuGrid(BuildContext context) {
    final items = <(IconData, Color, String, String, VoidCallback)>[
      (Icons.groups_2_rounded, _red, 'Employees', 'Manage employee information',
          () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const EmployeeDirectoryPage()))),
      (Icons.calendar_month_rounded, _purple, 'Leaves',
          'Manage leave requests and approvals',
          () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const LeaveRequestsPage()))),
      (Icons.account_balance_rounded, _green, 'Loan',
          'Manage employee loans and history',
          () => _openSection(context, 'Loan',
              "Pick an employee to view their loan / deductions.", 4)),
      (Icons.account_balance_wallet_rounded, _orange, 'Advance',
          'Manage employee advances',
          () => _openSection(context, 'Advance',
              "Pick an employee to view their advances.", 3)),
      (Icons.fingerprint_rounded, _blue, 'Attendance',
          'Track and manage attendance', () => adminTab.value = 2),
      (Icons.description_rounded, _violet, 'Salary',
          'Manage salary and payslips',
          () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SalaryPage()))),
    ];
    // 2-column grid, equal-height pairs, with a staggered entrance per row.
    // Fixed 14px gaps between rows; the grid starts right under the stat
    // cards so there is no stray gap between them.
    final rowCount = (items.length / 2).ceil();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var r = 0; r < rowCount; r++) ...[
          _introWrap(
            r,
            rowCount,
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _actionCard(items[r * 2])),
                  const SizedBox(width: 14),
                  Expanded(
                    child: r * 2 + 1 < items.length
                        ? _actionCard(items[r * 2 + 1])
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
          if (r != rowCount - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  /// Staggered slide-up + fade-in for menu row [i] of [total].
  Widget _introWrap(int i, int total, Widget child) {
    final start = (i / total) * 0.55;
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 26),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _actionCard((IconData, Color, String, String, VoidCallback) item) {
    final accent = item.$2;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: item.$5,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top: icon on the left, menu name to its right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.$1, color: accent, size: 20),
                  ),
                  const SizedBox(width: 9),
                  // Auto-shrinks to fit so long names never get cut.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.$3,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Subtext across the width, arrow at the end.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      item.$4,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Recent activity -----------------------------------------------------

  Widget _activitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.history_rounded, color: _blue, size: 19),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    "Today's latest changes",
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            _viewAllButton(context),
          ],
        ),
        const SizedBox(height: 12),
        _activityBody(),
      ],
    );
  }

  Widget _viewAllButton(BuildContext context) {
    return Material(
      color: AppColors.softRedTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ActivityLogsPage())),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 3),
              Icon(Icons.arrow_forward_rounded,
                  size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityBody() {
    if (_recentLoading) {
      return Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: AppColors.primary),
        ),
      );
    }
    if (_recentError) {
      return _activityPlaceholder(
        Icons.cloud_off_rounded,
        'Could not load activity.',
        action: TextButton(
          onPressed: _loadRecent,
          child: const Text('Retry'),
        ),
      );
    }
    if (_recent.isEmpty) {
      return _activityPlaceholder(
        Icons.history_toggle_off_rounded,
        'No recent activity.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _recent.length; i++) ...[
          ActivityLogCard(log: _recent[i]),
          if (i != _recent.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _activityPlaceholder(IconData icon, String text, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ?action,
        ],
      ),
    );
  }

  void _openSection(
      BuildContext context, String title, String subtitle, int tabIndex) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SelectEmployeePage(
        title: title,
        subtitle: subtitle,
        tabIndex: tabIndex,
      ),
    ));
  }

}
