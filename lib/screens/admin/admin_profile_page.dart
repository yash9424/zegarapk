import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../services/mock_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _avatarBlock(),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user.name == 'Administrator'
                        ? MockData.adminName
                        : user.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _employeeIdRow(),
                const SizedBox(height: 24),
                _section(
                  'PROFESSIONAL DETAILS',
                  [
                    _InfoRow(
                      icon: Icons.work_outline,
                      iconColor: AppColors.primary,
                      label: 'Role',
                      value: MockData.adminRole,
                    ),
                    _InfoRow(
                      icon: Icons.apartment,
                      iconColor: AppColors.textSecondary,
                      label: 'Department',
                      value: MockData.adminDepartment,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _section(
                  'SECURITY & ACCESS',
                  [
                    _InfoRow(
                      icon: Icons.fingerprint,
                      iconColor: AppColors.primary,
                      label: 'Biometric Status',
                      value: MockData.adminBiometric,
                      trailing: _activeBadge(),
                    ),
                    _InfoRow(
                      icon: Icons.mail_outline,
                      iconColor: AppColors.textSecondary,
                      label: 'Work Email',
                      value: user.email,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _logoutButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar(BuildContext context) {
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
          UserAvatar(name: user.name, radius: 18),
        ],
      ),
    );
  }

  Widget _avatarBlock() {
    return Center(
      child: SizedBox(
        width: 116,
        height: 116,
        child: Stack(
          children: [
            UserAvatar(
              name: user.name,
              radius: 56,
              ring: true,
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.scaffold, width: 2.5),
                ),
                child: const Icon(Icons.verified_user,
                    color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeIdRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'EMPLOYEE ID:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.softRedTint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            MockData.adminEmployeeId,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _activeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'ACTIVE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xFF2BB673),
        ),
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => confirmAndLogout(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFC4C8)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.softRedTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
