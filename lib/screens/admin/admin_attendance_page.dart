import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/api_client.dart';
import '../../services/mock_auth.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_format.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';
import 'employee_detail_page.dart';

/// One employee's attendance for the selected day. Built by merging the full
/// employee roster with the day's punches, so people with no punch still show
/// up (as Absent).
class _AttRow {
  _AttRow({
    required this.id,
    required this.name,
    required this.customId,
    required this.departmentName,
    required this.companyName,
    required this.dutyIn,
    required this.dutyOut,
    required this.status,
  });

  final int id;
  final String name;
  final int customId;
  final String departmentName;
  final String companyName;
  final String dutyIn;
  final String dutyOut;
  final String status; // "in" / "out" / "" (absent)

  bool get present => status.isNotEmpty || dutyIn.isNotEmpty || dutyOut.isNotEmpty;
  bool get isIn => status.toLowerCase() == 'in';
}

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _loading = true;
  String? _error;

  DateTime _date = _today();
  List<Company> _companies = const [];
  late String _companyId = ApiClient.instance.companyId;
  bool _allCompanies = false;

  List<_AttRow> _rows = const [];

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Display format the client asked for: dd-mm-yyyy.
  String get _dateLabel => '${_two(_date.day)}-${_two(_date.month)}-${_date.year}';

  /// Format the backend expects in the query string.
  String get _dateParam => '${_date.year}-${_two(_date.month)}-${_two(_date.day)}';

  bool get _isToday {
    final t = _today();
    return _date.year == t.year && _date.month == t.month && _date.day == t.day;
  }

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
    final original = ApiClient.instance.companyId;
    try {
      if (_companies.isEmpty) {
        try {
          _companies = await ZedgiftApi.instance.companies();
        } catch (_) {
          // Some deployments have a single company / no list endpoint.
          _companies = const [];
        }
      }

      // Which companies to pull. "All Companies" loops every one and tags
      // each row, so the admin sees everyone at once.
      final List<Company> targets;
      if (_companies.isEmpty) {
        targets = [
          Company(id: int.tryParse(original) ?? 0, name: 'Company'),
        ];
      } else if (_allCompanies) {
        targets = _companies;
      } else {
        targets = [
          _companies.firstWhere(
            (c) => c.id.toString() == _companyId,
            orElse: () => _companies.first,
          ),
        ];
      }

      final rows = <_AttRow>[];
      for (final c in targets) {
        ApiClient.instance.companyId = c.id.toString();
        final results = await Future.wait([
          ZedgiftApi.instance.employees(),
          ZedgiftApi.instance.recentPunches(date: _dateParam),
        ]);
        final emps = results[0] as List<EmployeeListItem>;
        final punches = results[1] as List<RecentPunch>;
        final byId = {for (final p in punches) p.employeeId: p};
        for (final e in emps) {
          final p = byId[e.id];
          rows.add(_AttRow(
            id: e.id,
            name: e.name.isEmpty ? 'Unnamed' : e.name,
            customId: e.customId,
            departmentName: e.departmentName,
            companyName: c.name,
            dutyIn: p?.dutyIn ?? '',
            dutyOut: p?.dutyOut ?? '',
            status: p?.status ?? '',
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load attendance. Pull to retry.';
        _loading = false;
      });
    } finally {
      ApiClient.instance.companyId = original;
    }
  }

  List<_AttRow> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.departmentName.toLowerCase().contains(q) ||
          r.companyName.toLowerCase().contains(q) ||
          r.customId.toString().contains(q);
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _today(),
      helpText: 'Select attendance date',
    );
    if (picked != null) {
      final d = DateTime(picked.year, picked.month, picked.day);
      if (d != _date) {
        setState(() => _date = d);
        _load();
      }
    }
  }

  Future<void> _pickCompany() async {
    // Options: All Companies (aggregate) + each company.
    final labels = <String>['All Companies', for (final c in _companies) c.name];
    final current = _allCompanies
        ? 0
        : 1 + _companies.indexWhere((c) => c.id.toString() == _companyId);

    final r = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Company',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: labels.length,
                itemBuilder: (_, i) {
                  final sel = i == current;
                  return ListTile(
                    leading: Icon(
                      i == 0 ? Icons.public : Icons.apartment,
                      color: sel ? AppColors.primary : AppColors.textMuted,
                    ),
                    title: Text(labels[i],
                        style: TextStyle(
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color:
                              sel ? AppColors.primary : AppColors.textPrimary,
                        )),
                    trailing: sel
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, i),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (r == null) return;
    if (r == 0) {
      if (!_allCompanies) {
        setState(() => _allCompanies = true);
        _load();
      }
    } else {
      final id = _companies[r - 1].id.toString();
      if (_allCompanies || id != _companyId) {
        setState(() {
          _allCompanies = false;
          _companyId = id;
        });
        _load();
      }
    }
  }

  String get _companyLabel {
    if (_allCompanies) return 'All Companies';
    if (_companies.isEmpty) return 'Company';
    return _companies
        .firstWhere((c) => c.id.toString() == _companyId,
            orElse: () => Company(id: 0, name: 'Company'))
        .name;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(),
          _searchBar(),
          const SizedBox(height: 10),
          _filterRow(),
          const SizedBox(height: 8),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final list = _filtered;
    final present = list.where((r) => r.present).length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _statRow(present, list.length),
          const SizedBox(height: 18),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text('No employees found.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15)),
              ),
            )
          else if (_allCompanies)
            ..._grouped(list)
          else
            for (final r in list) ...[
              _AttCard(row: r, showCompany: false),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  /// Company-wise sections when viewing all companies at once.
  List<Widget> _grouped(List<_AttRow> list) {
    final byCompany = <String, List<_AttRow>>{};
    for (final r in list) {
      byCompany.putIfAbsent(r.companyName, () => []).add(r);
    }
    final widgets = <Widget>[];
    final names = byCompany.keys.toList()..sort();
    for (final name in names) {
      final rows = byCompany[name]!;
      final present = rows.where((r) => r.present).length;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(
          children: [
            const Icon(Icons.apartment, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text('$present/${rows.length}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ],
        ),
      ));
      for (final r in rows) {
        widgets.add(_AttCard(row: r, showCompany: false));
        widgets.add(const SizedBox(height: 14));
      }
      widgets.add(const SizedBox(height: 6));
    }
    return widgets;
  }

  Widget _appBar() {
    final name = MockAuth.instance.currentUser?.name ?? 'Admin';
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
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search employees or departments...',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterRow() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _chip(
            label: _isToday ? 'Today ($_dateLabel)' : _dateLabel,
            icon: Icons.calendar_today,
            active: true,
            onTap: _pickDate,
          ),
          _chip(
            label: _companyLabel,
            icon: _allCompanies ? Icons.public : Icons.apartment,
            active: true,
            onTap: _pickCompany,
          ),
        ],
      ),
    );
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
                    size: 16, color: active ? Colors.white : AppColors.primary),
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

  Widget _statRow(int present, int total) {
    return Row(
      children: [
        Expanded(child: _statCard('PRESENT', '$present', AppColors.primary)),
        const SizedBox(width: 14),
        Expanded(
            child: _statCard('TOTAL', '$total', AppColors.textPrimary)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttCard extends StatelessWidget {
  const _AttCard({required this.row, required this.showCompany});
  final _AttRow row;
  final bool showCompany;

  @override
  Widget build(BuildContext context) {
    final sub = [
      'ID ${row.customId}',
      if (row.departmentName.isNotEmpty) row.departmentName,
      if (showCompany && row.companyName.isNotEmpty) row.companyName,
    ].join(' • ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EmployeeDetailPage(
              employeeId: row.id,
              fallbackName: row.name,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  UserAvatar(name: row.name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  _timeCol('In Time', to12Hour(row.dutyIn)),
                  _timeCol('Out Time', to12Hour(row.dutyOut)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge() {
    final Color color;
    final Color bg;
    final String label;
    if (!row.present) {
      color = const Color(0xFFB23A48);
      bg = const Color(0xFFFBE3E6);
      label = 'ABSENT';
    } else if (row.isIn) {
      color = const Color(0xFF2BB673);
      bg = const Color(0xFFE7F7EF);
      label = 'IN';
    } else {
      color = const Color(0xFFB8860B);
      bg = const Color(0xFFFBF3D9);
      label = 'OUT';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Widget _timeCol(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
