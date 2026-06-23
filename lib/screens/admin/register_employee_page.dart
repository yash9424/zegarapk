import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/face_scan_circle.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';
import 'face_enroll_page.dart';

/// Pick an existing employee (real list from the API). Selecting one fills the
/// detail fields, and the face is registered via the camera enrol flow.
class RegisterEmployeePage extends StatefulWidget {
  const RegisterEmployeePage({super.key});

  @override
  State<RegisterEmployeePage> createState() => _RegisterEmployeePageState();
}

class _RegisterEmployeePageState extends State<RegisterEmployeePage> {
  bool _loading = true;
  String? _error;
  List<EmployeeListItem> _employees = const [];
  EmployeeListItem? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ZedgiftApi.instance.employees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load employees.';
        _loading = false;
      });
    }
  }

  Future<void> _pickEmployee() async {
    final picked = await showModalBottomSheet<EmployeeListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EmployeePickerSheet(employees: _employees),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  void _registerFace() {
    final e = _selected;
    if (e == null) {
      _snack('Please select an employee first.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FaceEnrollPage(employeeId: e.id, employeeName: e.name),
    ));
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
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 0,
        onTap: (i) => goToAdminTab(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Register Face',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Select an employee, then tap the camera to register the face.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(120),
                      onTap: _registerFace,
                      child: const FaceScanCircle(
                        imageUrl: '',
                        placeholderIcon: Icons.camera_alt,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: _lightingBadge()),
                  const SizedBox(height: 24),
                  _formCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
    final name = MockAuth.instance.currentUser?.name ?? 'Admin';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            splashRadius: 22,
          ),
          const Spacer(),
          const ZegarLogo(fontSize: 22),
          const Spacer(),
          UserAvatar(name: name, radius: 20, ring: true),
        ],
      ),
    );
  }

  Widget _lightingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softRedTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          SizedBox(width: 6),
          Text(
            'Optimal Lighting',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    final e = _selected;
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Select Employee'),
          const SizedBox(height: 8),
          _employeePicker(),
          const SizedBox(height: 18),
          _label('Employee ID'),
          const SizedBox(height: 8),
          _readField(e == null ? '' : e.customId.toString(), 'EMP ID'),
          const SizedBox(height: 18),
          _label('Name'),
          const SizedBox(height: 8),
          _readField(e?.name ?? '', 'Full name'),
        ],
      ),
    );
  }

  // ---- Field building blocks ---------------------------------------------

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

  BoxDecoration _fieldBox() => BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      );

  /// Read-only filled field (auto-filled from the selected employee).
  Widget _readField(String value, String hint) {
    final empty = value.trim().isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      decoration: _fieldBox(),
      child: Text(
        empty ? hint : value,
        style: TextStyle(
          fontSize: 14,
          color: empty ? AppColors.textMuted : AppColors.textPrimary,
          fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _employeePicker() {
    final e = _selected;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _loading ? null : _pickEmployee,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: _fieldBox(),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _loading
                    ? 'Loading employees...'
                    : _error != null
                        ? _error!
                        : e == null
                            ? 'Choose an employee...'
                            : '${e.name}  (ID ${e.customId})',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: e == null ? AppColors.textMuted : AppColors.textPrimary,
                  fontWeight: e == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

}

/// Searchable employee picker (handles the ~900-employee list).
class _EmployeePickerSheet extends StatefulWidget {
  const _EmployeePickerSheet({required this.employees});
  final List<EmployeeListItem> employees;

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.employees
        : widget.employees
            .where((e) =>
                e.name.toLowerCase().contains(q) ||
                e.customId.toString().contains(q) ||
                e.departmentName.toLowerCase().contains(q))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _q = v),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search name, ID, department...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('No employees found',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (_, i) {
                        final e = list[i];
                        return ListTile(
                          leading: UserAvatar(name: e.name, radius: 20),
                          title: Text(e.name.isEmpty ? 'Unnamed' : e.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          subtitle: Text(
                              'ID ${e.customId} • ${e.departmentName}',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                          onTap: () => Navigator.pop(context, e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
