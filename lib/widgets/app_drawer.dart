import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/mock_auth.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class DrawerEntry {
  const DrawerEntry(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Shared navigation drawer with a staggered slide-in animation, page links
/// and a logout action. Used by both the admin and employee panels.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.entries,
  });

  final String name;
  final String subtitle;
  final String avatarUrl;
  final List<DrawerEntry> entries;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    final start = (0.12 + index * 0.08).clamp(0.0, 0.7);
    final anim = CurvedAnimation(
      parent: _c,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(-26 * (1 - anim.value), 0),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      ...widget.entries,
      DrawerEntry(Icons.logout, 'Log Out', () => confirmAndLogout(context)),
    ];

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          _header(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < all.length; i++)
                  _animated(
                    i,
                    _tile(all[i], isLogout: i == all.length - 1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: widget.name,
            imageUrl: widget.avatarUrl,
            radius: 28,
            ring: true,
          ),
          const SizedBox(height: 12),
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _tile(DrawerEntry e, {required bool isLogout}) {
    final color = isLogout ? AppColors.primary : AppColors.textPrimary;
    return ListTile(
      leading: Icon(e.icon, color: isLogout ? AppColors.primary : AppColors.textSecondary),
      title: Text(
        e.label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isLogout ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // close the drawer
        e.onTap();
      },
    );
  }
}

/// Shows a confirmation dialog and, if confirmed, returns to the login screen.
Future<void> confirmAndLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Log out?',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: const Text('Are you sure you want to log out of Zegar?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Log Out',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (ok == true && context.mounted) {
    MockAuth.instance.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
