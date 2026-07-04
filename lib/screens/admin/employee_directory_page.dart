import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/employee_picker_sheet.dart';
import '../../widgets/search_field.dart';
import '../../widgets/user_avatar.dart';
import 'employee_detail_page.dart';

class EmployeeDirectoryPage extends StatefulWidget {
  const EmployeeDirectoryPage({super.key});

  @override
  State<EmployeeDirectoryPage> createState() => _EmployeeDirectoryPageState();
}

class _EmployeeDirectoryPageState extends State<EmployeeDirectoryPage> {
  final String _query = '';
  final Set<String> _depts = {}; // empty = all departments
  final Set<String> _statuses = {}; // subset of {active, inactive}; empty = all

  bool _loading = true;
  String? _error;
  List<EmployeeListItem> _all = const [];
  List<NamedCount> _departments = const [];

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
      final results = await Future.wait([
        ZedgiftApi.instance.employees(),
        ZedgiftApi.instance.departments(),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<EmployeeListItem>;
        _departments = results[1] as List<NamedCount>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load employees. Pull to retry.';
        _loading = false;
      });
    }
  }

  List<EmployeeListItem> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((e) {
      final matchesCat =
          _depts.isEmpty || _depts.contains(e.departmentName);
      final matchesStatus = _statuses.isEmpty ||
          (e.active && _statuses.contains('active')) ||
          (!e.active && _statuses.contains('inactive'));
      final matchesQuery = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.designationName.toLowerCase().contains(q) ||
          e.departmentName.toLowerCase().contains(q) ||
          e.customId.toString().contains(q);
      return matchesCat && matchesStatus && matchesQuery;
    }).toList();
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
            _titleRow(),
            _searchBar(),
            if (!_loading && _error == null) ...[
              const SizedBox(height: 10),
              _filters(),
            ],
            const SizedBox(height: 8),
            Expanded(child: _listArea()),
          ],
        ),
      ),
    );
  }

  Widget _listArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return _retryState(_error!);
    }
    final list = _filtered;
    if (list.isEmpty) return _emptyState();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _EmployeeCard(employee: list[i]),
      ),
    );
  }

  Widget _appBar() {
    return const AppHeader(leadingIcon: Icons.arrow_back);
  }

  /// Page heading styled like the Home greeting — red 19px title with a small
  /// grey subtext below it.
  Widget _titleRow() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employees',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1.15,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Manage employee information',
              style:
                  TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SearchField(
        hint: 'Search employees, departments, or roles...',
        onTap: _loading ? () {} : _openPicker,
      ),
    );
  }

  /// Open the shared employee picker (search + badges + total count) and, on
  /// selection, go straight to that employee's profile.
  Future<void> _openPicker() async {
    final picked = await pickEmployee(context, _all);
    if (picked == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EmployeeDetailPage(
        employeeId: picked.id,
        fallbackName: picked.name,
      ),
    ));
  }

  Widget _filters() {
    final noFilter = _depts.isEmpty && _statuses.isEmpty;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _chip(
            label: 'All',
            icon: Icons.clear_all,
            active: noFilter,
            onTap: () => setState(() {
              _depts.clear();
              _statuses.clear();
            }),
          ),
          _chip(
            label: _deptLabel(),
            icon: Icons.groups,
            active: _depts.isNotEmpty,
            onTap: _pickDepartment,
          ),
          _chip(
            label: _statusLabel(),
            icon: Icons.verified_user_outlined,
            active: _statuses.isNotEmpty,
            onTap: _pickStatus,
          ),
        ],
      ),
    );
  }

  String _deptLabel() {
    if (_depts.isEmpty) return 'All Departments';
    if (_depts.length == 1) return _depts.first;
    return '${_depts.length} Departments';
  }

  String _statusLabel() {
    if (_statuses.isEmpty) return 'Active / Inactive';
    return [
      if (_statuses.contains('active')) 'Active',
      if (_statuses.contains('inactive')) 'Inactive',
    ].join(' + ');
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: active ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.fieldBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDepartment() async {
    final r = await _pickMulti(
      'Select Departments',
      [for (final d in _departments) (d.name, '${d.name} (${d.count})')],
      _depts,
    );
    if (r != null) setState(() => _depts..clear()..addAll(r));
  }

  Future<void> _pickStatus() async {
    final r = await _pickMulti(
      'Select Status',
      const [('active', 'Active'), ('inactive', 'Inactive')],
      _statuses,
    );
    if (r != null) setState(() => _statuses..clear()..addAll(r));
  }

  /// Multi-select bottom sheet with checkboxes. Returns the chosen set, or
  /// null if dismissed without applying.
  Future<Set<String>?> _pickMulti(
    String title,
    List<(String, String)> options,
    Set<String> current,
  ) {
    final sel = {...current};
    return showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final o = options[i];
                    final on = sel.contains(o.$1);
                    return CheckboxListTile(
                      value: on,
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(o.$2,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary)),
                      onChanged: (v) => setSheet(() {
                        if (v == true) {
                          sel.add(o.$1);
                        } else {
                          sel.remove(o.$1);
                        }
                      }),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(sel.clear),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.fieldBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, sel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('No employees found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _retryState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});
  final EmployeeListItem employee;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EmployeeDetailPage(
              employeeId: employee.id,
              fallbackName: employee.name,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _avatarWithStatus(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name.isEmpty ? 'Unnamed' : employee.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _badge(Icons.badge_outlined,
                            'ID ${employee.customId}'),
                        if (employee.departmentName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: _badge(
                                Icons.apartment, employee.departmentName,
                                muted: true),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, {bool muted = false}) {
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

  Widget _avatarWithStatus() {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        children: [
          UserAvatar(name: employee.name, radius: 25),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: employee.active
                    ? const Color(0xFF2BB673)
                    : AppColors.textMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
