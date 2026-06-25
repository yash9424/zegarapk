import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/face_scan_circle.dart';
import '../../widgets/inline_face_enroll.dart';
import '../../widgets/search_field.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

/// Pick an existing employee (real list from the API). Selecting one fills the
/// detail fields, and the face is registered via the camera enrol flow.
class RegisterEmployeePage extends StatefulWidget {
  const RegisterEmployeePage({
    super.key,
    this.initialEmployeeId,
    this.initialEmployeeName,
  });

  /// When opened from an employee's profile, this employee is pre-selected so
  /// the inline camera is ready immediately (no need to search again).
  final int? initialEmployeeId;
  final String? initialEmployeeName;

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
        // Pre-select the employee we were opened for (from a profile page).
        if (widget.initialEmployeeId != null) {
          for (final e in list) {
            if (e.id == widget.initialEmployeeId) {
              _selected = e;
              break;
            }
          }
        }
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

  /// The face-capture area: a live inline camera circle once an employee is
  /// selected, otherwise a placeholder circle prompting a selection.
  Widget _captureArea() {
    final e = _selected;
    if (e == null) {
      return Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(120),
            onTap: () => _snack('Please select an employee first.'),
            child: const FaceScanCircle(
              imageUrl: '',
              placeholderIcon: Icons.camera_alt,
            ),
          ),
          const SizedBox(height: 14),
          Text('Select an employee above to start.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      );
    }
    return InlineFaceEnroll(
      // Key on the id so picking a different employee resets the capture.
      key: ValueKey(e.id),
      employeeId: e.id,
      employeeName: e.name,
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
                      'Select an employee, then tap the circle to capture the face from 5 angles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(child: _captureArea()),
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
  final _searchCtl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

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
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Grab handle.
            Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Title row + close.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 10, 6),
              child: Row(
                children: [
                  const Text(
                    'Select Employee',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.softRedTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${list.length}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Search.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: SearchField(
                controller: _searchCtl,
                hint: 'Search name, ID, department…',
                hasText: _q.isNotEmpty,
                onChanged: (v) => setState(() => _q = v),
                onClear: () {
                  _searchCtl.clear();
                  setState(() => _q = '');
                },
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _row(list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(EmployeeListItem e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              children: [
                UserAvatar(name: e.name, radius: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name.isEmpty ? 'Unnamed' : e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _miniTag(Icons.badge_outlined, 'ID ${e.customId}'),
                          if (e.departmentName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: _miniTag(
                                  Icons.apartment, e.departmentName,
                                  muted: true),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.softRedTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: AppColors.primary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(IconData icon, String text, {bool muted = false}) {
    final color = muted ? AppColors.textSecondary : AppColors.primary;
    final bg = muted ? const Color(0xFFEDEFF4) : AppColors.softRedTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 46, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text('No employees found',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Try a different name, ID or department',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
