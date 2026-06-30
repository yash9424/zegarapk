import 'package:flutter/material.dart';

import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
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
  // Live counts shown in the stat row.
  int? _employees;
  int? _onLeave;

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
    try {
      final emps = await ZedgiftApi.instance.employees();
      if (mounted) setState(() => _employees = emps.length);
    } catch (_) {}
    try {
      final leaves = await ZedgiftApi.instance.leaves();
      if (mounted) setState(() => _onLeave = leaves.length);
    } catch (_) {}
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _greeting(),
                const SizedBox(height: 20),
                _statsRow(),
                const SizedBox(height: 22),
                _menuList(context),
                const SizedBox(height: 22),
                _welcomeBanner(context),
              ],
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Administrator',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
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
      (Icons.groups_2_rounded, _red, _employees?.toString() ?? '—',
          'Employees'),
      (Icons.calendar_month_rounded, _purple, _onLeave?.toString() ?? '—',
          'On Leave'),
      (Icons.account_balance_wallet_rounded, _green, '—', 'Advances'),
      (Icons.payments_rounded, _orange, '—', 'Payroll'),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(s.$1, color: accent, size: 20),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 1),
          Text(
            s.$4,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            width: double.infinity,
            child: CustomPaint(painter: _SparkPainter(accent)),
          ),
        ],
      ),
    );
  }

  // ---- Action cards --------------------------------------------------------

  Widget _menuList(BuildContext context) {
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
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _introWrap(i, items.length, _listItem(items[i])),
          if (i != items.length - 1) const SizedBox(height: 12),
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

  Widget _listItem((IconData, Color, String, String, VoidCallback) item) {
    final accent = item.$2;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.$5,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colour accent strip down the left edge.
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      child: Row(
                        children: [
                          _iconTile(accent, item.$1),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.$3,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.$4,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _arrowChip(accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconTile(Color accent, IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: accent, size: 25),
    );
  }

  Widget _arrowChip(Color accent) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
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

  // ---- Welcome banner ------------------------------------------------------

  Widget _welcomeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.softRedTint,
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: AppColors.softRedTint),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back! 👋',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Here's what's happening with your organization today.",
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => adminTab.value = 2, // Attendance overview
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View Full Dashboard',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.insights_rounded,
              size: 64, color: AppColors.primary.withValues(alpha: 0.30)),
        ],
      ),
    );
  }
}

/// A small decorative sparkline behind a stat value.
class _SparkPainter extends CustomPainter {
  _SparkPainter(this.color);
  final Color color;

  static const _pts = [0.6, 0.35, 0.5, 0.3, 0.55, 0.25, 0.4];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final dx = size.width / (_pts.length - 1);
    for (var i = 0; i < _pts.length; i++) {
      final x = dx * i;
      final y = size.height * _pts[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(path, line);

    // Soft fill under the line.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.color != color;
}
