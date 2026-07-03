import 'package:flutter/material.dart';

import '../../services/mock_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/user_avatar.dart';

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
                    user.name.isEmpty ? 'Administrator' : user.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _section(
                  '',
                  [
                    _InfoRow(
                      icon: Icons.business_outlined,
                      iconColor: AppColors.primary,
                      label: 'Company Name',
                      value:
                          user.companyName.isEmpty ? '—' : user.companyName,
                    ),
                    _InfoRow(
                      icon: Icons.person_outline,
                      iconColor: AppColors.primary,
                      label: 'Full Name',
                      value: user.name.isEmpty ? '—' : user.name,
                    ),
                    _InfoRow(
                      icon: Icons.shield_outlined,
                      iconColor: AppColors.primary,
                      label: 'Role',
                      value: user.role == UserRole.admin
                          ? 'Administrator'
                          : 'Employee',
                    ),
                    _InfoRow(
                      icon: Icons.mail_outline,
                      iconColor: AppColors.primary,
                      label: 'Work Email',
                      value: user.email.isEmpty ? '—' : user.email,
                    ),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      iconColor: AppColors.primary,
                      label: 'Phone',
                      value: user.phone.isEmpty ? '—' : user.phone,
                    ),
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      iconColor: AppColors.primary,
                      label: 'Account Status',
                      value: user.active ? 'Active' : 'Inactive',
                      trailing: user.active ? _activeBadge() : null,
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
    return AppHeader(
      leadingIcon: Icons.menu,
      onLeadingTap: () => Scaffold.of(context).openDrawer(),
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
              imageUrl: user.avatarUrl,
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
      padding: EdgeInsets.fromLTRB(18, title.isEmpty ? 14 : 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
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
          ],
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
      onTap: () =>
          confirmAndLogout(Navigator.of(context, rootNavigator: true)),
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
