import 'package:flutter/material.dart';

import '../../services/mock_auth.dart';
import '../../theme/app_theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_drawer.dart';
import 'admin_attendance_page.dart';
import 'admin_home_page.dart';
import 'admin_profile_page.dart';
import 'employee_directory_page.dart';
import 'leave_requests_page.dart';
import 'register_employee_page.dart';

/// Admin panel container with the bottom navigation bar and the floating
/// QR scan button. The Home tab hosts [AdminHomePage].
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.user});

  final AuthUser user;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void initState() {
    super.initState();
    adminTab.value = 0;
    adminTab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    adminTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminHomePage(user: widget.user),
      const AdminAttendancePage(),
      AdminProfilePage(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      drawer: AppDrawer(
        name: MockData.adminName,
        subtitle: 'Administrator',
        avatarUrl: MockData.adminAvatar,
        entries: [
          DrawerEntry(Icons.home_outlined, 'Home', () => adminTab.value = 0),
          DrawerEntry(
              Icons.event_available, 'Attendance', () => adminTab.value = 1),
          DrawerEntry(
              Icons.person_outline, 'Profile', () => adminTab.value = 2),
          DrawerEntry(Icons.person_add_alt_1, 'Register Employee',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const RegisterEmployeePage()))),
          DrawerEntry(Icons.groups, 'Employee Directory',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const EmployeeDirectoryPage()))),
          DrawerEntry(Icons.fact_check_outlined, 'Leave Requests',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const LeaveRequestsPage()))),
        ],
      ),
      body: IndexedStack(index: adminTab.value, children: pages),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: adminTab.value,
        onTap: (i) => adminTab.value = i,
      ),
    );
  }
}

