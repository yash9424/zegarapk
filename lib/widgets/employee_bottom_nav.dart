import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_bottom_nav.dart' show SlidingNav;

final ValueNotifier<int> employeeTab = ValueNotifier<int>(0);
final ValueNotifier<int> employeeProfileTab = ValueNotifier<int>(0);

class EmployeeBottomNav extends StatelessWidget {
  const EmployeeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.fingerprint, 'Attendance'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: SlidingNav(
            currentIndex: currentIndex,
            items: _items,
            activeColor: AppColors.primary,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
