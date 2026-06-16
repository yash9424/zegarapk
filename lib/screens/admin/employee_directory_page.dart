import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/api_client.dart';
import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';
import 'employee_detail_page.dart';
import 'register_employee_page.dart';

class EmployeeDirectoryPage extends StatefulWidget {
  const EmployeeDirectoryPage({super.key});

  @override
  State<EmployeeDirectoryPage> createState() => _EmployeeDirectoryPageState();
}

class _EmployeeDirectoryPageState extends State<EmployeeDirectoryPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _category; // department name, null = All
  String _status = 'all'; // all / active / inactive

  bool _loading = true;
  String? _error;
  List<EmployeeListItem> _all = const [];
  List<NamedCount> _departments = const [];
  List<Company> _companies = const [];
  late String _companyId = ApiClient.instance.companyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        ZedgiftApi.instance.companies(),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<EmployeeListItem>;
        _departments = results[1] as List<NamedCount>;
        _companies = results[2] as List<Company>;
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
      final matchesCat = _category == null || e.departmentName == _category;
      final matchesStatus = _status == 'all' ||
          (_status == 'active' && e.active) ||
          (_status == 'inactive' && !e.active);
      final matchesQuery = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.designationName.toLowerCase().contains(q) ||
          e.departmentName.toLowerCase().contains(q) ||
          e.customId.toString().contains(q);
      return matchesCat && matchesStatus && matchesQuery;
    }).toList();
  }

  /// Switch the active company → reload its employees + departments.
  Future<void> _onCompanyChanged(String id) async {
    ApiClient.instance.companyId = id;
    setState(() {
      _companyId = id;
      _category = null; // department list will change
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const RegisterEmployeePage()),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.person_add_alt_1, color: Colors.white),
        ),
      ),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 0,
        onTap: (i) => goToAdminTab(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(),
            _searchBar(),
            if (!_loading && _error == null && _companies.isNotEmpty) ...[
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
    final name = MockAuth.instance.currentUser?.name ?? 'Admin';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
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

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search employees, departments, or roles...',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.tune, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          // Company (server list; switching reloads data).
          Expanded(
            child: _dropdown<String>(
              icon: Icons.apartment,
              value: _companyId,
              items: [
                for (final c in _companies)
                  DropdownMenuItem(value: c.id.toString(), child: Text(c.name)),
              ],
              onChanged: (v) {
                if (v != null && v != _companyId) _onCompanyChanged(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Department (of current company).
          Expanded(
            child: _dropdown<String?>(
              icon: Icons.groups,
              value: _category,
              items: [
                const DropdownMenuItem(value: null, child: Text('All Dept.')),
                for (final d in _departments)
                  DropdownMenuItem(value: d.name, child: Text(d.name)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          const SizedBox(width: 8),
          // Active / Inactive.
          Expanded(
            child: _dropdown<String>(
              icon: Icons.toggle_on,
              value: _status,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textMuted),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                items: items,
                onChanged: onChanged,
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
    final role = employee.designationName.isEmpty
        ? employee.typeName
        : employee.designationName;
    final team =
        employee.departmentName.isEmpty ? '—' : employee.departmentName;
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID ${employee.customId} • $role',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.business,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            team,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
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
