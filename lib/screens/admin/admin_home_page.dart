import 'package:flutter/material.dart';

import '../../services/mock_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import 'employee_directory_page.dart';
import 'leave_requests_page.dart';
import 'select_employee_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key, required this.user});

  final AuthUser user;

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
                const SizedBox(height: 22),
                _menuGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _greeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hello,',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),
        Text(
          user.name,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Administrator Login',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// The 2-column quick-action grid (Employees, Leaves, Loan, Advance,
  /// Attendance, Salary). Pages that don't exist yet show "Coming soon".
  Widget _menuGrid(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.groups_2_rounded, 'Employees', () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmployeeDirectoryPage()))),
      (Icons.calendar_month_rounded, 'Leaves', () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LeaveRequestsPage()))),
      (Icons.account_balance_rounded, 'Loan', () => _openSection(context,
          'Loan', "Pick an employee to view their loan / deductions.", 4)),
      (Icons.account_balance_wallet_rounded, 'Advance', () => _openSection(
          context, 'Advance', "Pick an employee to view their advances.", 3)),
      (Icons.fingerprint_rounded, 'Attendance', () => adminTab.value = 2),
      (Icons.payments_rounded, 'Salary', () => _openSection(
          context, 'Salary', "Pick an employee to view their payroll.", 1)),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: _menuCard(items[i])),
              const SizedBox(width: 14),
              Expanded(
                child: i + 1 < items.length
                    ? _menuCard(items[i + 1])
                    : const SizedBox(),
              ),
            ],
          ),
          if (i + 2 < items.length) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _menuCard((IconData, String, VoidCallback) item) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.$3,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.softRedTint, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryLight, AppColors.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(item.$1, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                item.$2,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
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
