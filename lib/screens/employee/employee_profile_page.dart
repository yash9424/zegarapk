import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../services/mock_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/employee_bottom_nav.dart';
import '../../widgets/zegar_logo.dart';

class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key, required this.user});

  final AuthUser user;

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  int _tab = 0;

  static const _green = Color(0xFF2BB673);
  static const _greenBg = Color(0xFFE7F7EF);

  @override
  void initState() {
    super.initState();
    _tab = employeeProfileTab.value;
    employeeProfileTab.addListener(_onProfileTab);
  }

  @override
  void dispose() {
    employeeProfileTab.removeListener(_onProfileTab);
    super.dispose();
  }

  void _onProfileTab() {
    if (mounted) setState(() => _tab = employeeProfileTab.value);
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textPrimary),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(sheetContext);
                _snack('Edit profile — coming soon');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.primary),
              title: const Text('Log Out',
                  style: TextStyle(color: AppColors.primary)),
              onTap: () {
                Navigator.pop(sheetContext);
                confirmAndLogout(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _headerCard(),
                const SizedBox(height: 18),
                _tabBar(),
                const SizedBox(height: 18),
                ..._tabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
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
          _roundedAvatar(36, 10),
        ],
      ),
    );
  }

  Widget _roundedAvatar(double size, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        MockData.employeeAvatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          color: AppColors.softRedTint,
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
      ),
    );
  }

  // ---- Header --------------------------------------------------------------

  Widget _headerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: _roundedAvatar(92, 16),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _showSettings,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.surface, width: 2.5),
                      ),
                      child: const Icon(Icons.settings,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.user.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MockData.employeeRole,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _chip(Icons.badge_outlined, 'ID: ${MockData.employeeId}',
                  AppColors.softRedTint, AppColors.primary),
              _chip(Icons.location_on_outlined, MockData.employeeLocation,
                  const Color(0xFFEDEFF4), AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _snack('Edit profile — coming soon'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Profile',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
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

  Widget _tabBar() {
    const tabs = <(IconData, String)>[
      (Icons.receipt_long_outlined, 'Payroll History'),
      (Icons.event_busy_outlined, 'Leave Requests'),
      (Icons.work_history_outlined, 'Profession'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(child: _tabItem(i, tabs[i].$1, tabs[i].$2)),
        ],
      ),
    );
  }

  Widget _tabItem(int i, IconData icon, String label) {
    final active = _tab == i;
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => employeeProfileTab.value = i,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 2.5,
            color: active ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  List<Widget> _tabContent() {
    switch (_tab) {
      case 1:
        return _leaveTab();
      case 2:
        return _professionTab();
      default:
        return _payrollTab();
    }
  }

  // ---- Tab 1: Payroll ------------------------------------------------------

  List<Widget> _payrollTab() {
    return [
      Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: AppColors.fieldFill,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text('EARNINGS RECORDS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      )),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _snack('Download statement — coming soon'),
                    child: const Icon(Icons.download_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(flex: 4, child: _colLabel('MONTH')),
                  Expanded(flex: 4, child: _colLabel('BASE SALARY')),
                  Expanded(flex: 3, child: _colLabel('STATUS')),
                ],
              ),
            ),
            for (final p in MockData.payroll) _payrollRow(p),
          ],
        ),
      ),
    ];
  }

  Widget _payrollRow(PayrollRecord p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(text: '${p.month}\n'),
                  TextSpan(
                    text: p.year,
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(p.amount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusPill(
                p.paid ? 'PAID' : 'PROCESSING',
                p.paid ? _green : AppColors.primary,
                p.paid ? _greenBg : AppColors.softRedTint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Tab 2: Leave --------------------------------------------------------

  List<Widget> _leaveTab() {
    return [
      _leaveBalanceCard('Annual Leaves', MockData.annualUsed,
          MockData.annualTotal, Icons.beach_access_outlined),
      const SizedBox(height: 14),
      _leaveBalanceCard('Sick Leaves', MockData.sickUsed, MockData.sickTotal,
          Icons.medical_services_outlined),
      const SizedBox(height: 16),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _snack('Request Leave — coming soon'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.softRedTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Icon(Icons.add_circle_outline,
                  color: AppColors.primary, size: 22),
              SizedBox(height: 4),
              Text('Request Leave',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(flex: 4, child: _colLabel('DATES')),
                  Expanded(flex: 4, child: _colLabel('TYPE')),
                  Expanded(flex: 3, child: _colLabel('STATUS')),
                ],
              ),
            ),
            for (final l in MockData.empLeaveHistory) _leaveRow(l),
          ],
        ),
      ),
    ];
  }

  Widget _leaveBalanceCard(String title, int used, int total, IconData icon) {
    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: used.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      TextSpan(
                        text: ' / $total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 30, color: AppColors.textMuted.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _leaveRow(EmpLeaveRecord l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dates,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(l.days,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(l.type,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.textPrimary,
                )),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusPill(
                l.approved ? 'APPROVED' : 'PENDING',
                l.approved ? _green : AppColors.primary,
                l.approved ? _greenBg : AppColors.softRedTint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Tab 3: Profession ---------------------------------------------------

  List<Widget> _professionTab() {
    Widget row(String label, String value, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 12),
              Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
        );

    return [
      Container(
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Employment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            row('Joining Date', MockData.empJoiningDate),
            row('Department', MockData.employeeDepartment),
            row('Reporting To', MockData.empReportingTo),
            row('Employment Type', MockData.empEmploymentType, last: true),
          ],
        ),
      ),
    ];
  }

  // ---- Shared --------------------------------------------------------------

  Widget _colLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      );

  Widget _statusPill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: fg,
          )),
    );
  }
}
