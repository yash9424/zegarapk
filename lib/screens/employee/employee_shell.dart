import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../services/mock_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/employee_bottom_nav.dart';
import 'employee_announcements_page.dart';
import 'employee_attendance_page.dart';
import 'employee_home_page.dart';
import 'employee_my_attendance_page.dart';
import 'employee_profile_page.dart';

/// Employee panel container with the flat-style bottom navigation bar.
class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key, required this.user});

  final AuthUser user;

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  @override
  void initState() {
    super.initState();
    employeeTab.value = 0;
    employeeTab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    employeeTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EmployeeHomePage(user: widget.user),
      const EmployeeAttendancePage(),
      EmployeeProfilePage(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      drawer: AppDrawer(
        name: MockData.employeeName,
        subtitle: MockData.employeeRole,
        avatarUrl: MockData.employeeAvatar,
        entries: [
          DrawerEntry(
              Icons.home_outlined, 'Home', () => employeeTab.value = 0),
          DrawerEntry(
              Icons.fingerprint, 'Attendance', () => employeeTab.value = 1),
          DrawerEntry(
              Icons.person_outline, 'Profile', () => employeeTab.value = 2),
          DrawerEntry(Icons.event_available_outlined, 'My Attendance',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const EmployeeMyAttendancePage()))),
          DrawerEntry(Icons.campaign_outlined, 'Announcements',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const EmployeeAnnouncementsPage()))),
        ],
      ),
      body: IndexedStack(index: employeeTab.value, children: pages),
      bottomNavigationBar: EmployeeBottomNav(
        currentIndex: employeeTab.value,
        onTap: (i) => employeeTab.value = i,
      ),
    );
  }
}

