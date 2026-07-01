import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/search_field.dart';
import '../../widgets/user_avatar.dart';
import 'salary_detail_page.dart';

/// Payroll list for a month — searchable, with Month / Year filters and an
/// expandable card per employee showing attendance, earnings, deductions and
/// the net payable, plus Approve / Hold / View actions.
class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  static const _green = Color(0xFF2BB673);
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool _loading = true;
  String? _error;
  List<SalaryListItem> _all = const [];

  // Local approve / hold state (the backend exposes no approve endpoint yet,
  // so the action result is reflected in the UI for this session).
  final Set<int> _approved = {};
  final Set<int> _held = {};
  final Set<int> _expanded = {};

  late int _month;
  late int _year;

  // When set, the list shows just this employee (chosen from the search
  // drawer). Null = show everyone for the month.
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ZedgiftApi.instance.salaries(month: _month, year: _year);
      if (!mounted) return;
      setState(() {
        _all = list;
        // Seed local flags from the server's approved status.
        _approved
          ..clear()
          ..addAll(list.where((s) => s.approved).map((s) => s.id));
        _held.clear();
        _selectedId = null; // reset the search filter on (re)load
        _expanded
          ..clear()
          ..addAll(list.take(1).map((s) => s.id)); // first card open
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load salary records.';
        _loading = false;
      });
    }
  }

  List<SalaryListItem> get _filtered {
    if (_selectedId == null) return _all;
    return _all.where((s) => s.id == _selectedId).toList();
  }

  SalaryListItem? get _selected {
    for (final s in _all) {
      if (s.id == _selectedId) return s;
    }
    return null;
  }

  void _snack(String msg) {
    if (!mounted) return;
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
            const AppHeader(leadingIcon: Icons.arrow_back),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _titleRow(),
                    const SizedBox(height: 14),
                    _searchBar(),
                    if (_selected != null) ...[
                      const SizedBox(height: 10),
                      _selectedChip(_selected!),
                    ],
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      )
                    else if (_error != null)
                      _empty(_error!)
                    else if (_all.isEmpty)
                      _empty(
                          'No salary records for ${_months[_month - 1]} $_year.')
                    else
                      for (final s in _filtered) ...[
                        _salaryCard(s),
                        const SizedBox(height: 14),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Title + filters -----------------------------------------------------

  Widget _titleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Salary',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const Spacer(),
        _filterPill(
          label: _monthShort[_month - 1],
          onTap: _pickMonth,
        ),
        const SizedBox(width: 8),
        _filterPill(
          label: '$_year',
          onTap: _pickYear,
        ),
      ],
    );
  }

  Widget _filterPill({required String label, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await _pickFromSheet<int>(
      title: 'Select Month',
      items: [for (var m = 1; m <= 12; m++) (m, _months[m - 1])],
      selected: _month,
    );
    if (picked != null && picked != _month) {
      setState(() => _month = picked);
      _load();
    }
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final years = [for (var y = now.year - 4; y <= now.year + 1; y++) y];
    final picked = await _pickFromSheet<int>(
      title: 'Select Year',
      items: [for (final y in years) (y, '$y')],
      selected: _year,
    );
    if (picked != null && picked != _year) {
      setState(() => _year = picked);
      _load();
    }
  }

  Future<T?> _pickFromSheet<T>({
    required String title,
    required List<(T, String)> items,
    required T selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final it in items)
                    ListTile(
                      title: Text(it.$2,
                          style: TextStyle(
                            fontWeight: it.$1 == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: it.$1 == selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          )),
                      trailing: it.$1 == selected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 20)
                          : null,
                      onTap: () => Navigator.pop(ctx, it.$1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Read-only search bar — tapping it opens the employee drawer (same UX as
  /// the Employee Directory search).
  Widget _searchBar() {
    final sel = _selected;
    return SearchField(
      hint: sel == null
          ? 'Search employee name or ID...'
          : sel.name.isEmpty
              ? 'Employee #${sel.customId}'
              : sel.name,
      onTap: _loading ? () {} : _openPicker,
    );
  }

  /// A removable chip shown under the search bar while one employee is picked.
  Widget _selectedChip(SalaryListItem s) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.softRedTint,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _selectedId = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Showing ${s.name.isEmpty ? 'Employee #${s.customId}' : s.name}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.close_rounded,
                    size: 15, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Open the salary employee drawer — searchable list of everyone with a
  /// salary record this month. Picking one filters the page to that person.
  Future<void> _openPicker() async {
    if (_all.isEmpty) {
      _snack('No salary records for ${_months[_month - 1]} $_year yet.');
      return;
    }
    final picked = await showModalBottomSheet<SalaryListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SalaryPickerSheet(items: _all),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedId = picked.id;
      _expanded.add(picked.id);
    });
  }

  // ---- Salary card ---------------------------------------------------------

  Widget _salaryCard(SalaryListItem s) {
    final open = _expanded.contains(s.id);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tap opens the full payslip; the chevron toggles the
          // inline summary.
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: Radius.circular(open ? 0 : 18),
            ),
            onTap: () => _view(s),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.softRedTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name.isEmpty ? 'Employee #${s.customId}' : s.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ID: ${s.code}'
                          '${s.departmentName.isEmpty ? '' : ' • ${s.departmentName.toUpperCase()}'}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (s.designationName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.designationName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      if (open) {
                        _expanded.remove(s.id);
                      } else {
                        _expanded.add(s.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Body (only when expanded).
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _cardBody(s),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _cardBody(SalaryListItem s) {
    final held = _held.contains(s.id);
    final approved = _approved.contains(s.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type bar.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Type: ${s.typeName.isEmpty ? '—' : s.typeName}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  s.fixSalary,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Attendance / Overtime.
          Row(
            children: [
              Expanded(
                child: _metricBox('Attendance', s.attendanceLabel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBox('Overtime', s.overtimeLabel, accent: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Earnings / Deductions.
          Row(
            children: [
              Expanded(
                child: _metricBox('Earnings', s.earnings),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBox('Deductions', s.deductions, accent: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Summary lines.
          _summaryLine('Gross Salary', s.grossSalary),
          const SizedBox(height: 6),
          _summaryLine('Company Contribution', s.companyContribution),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'NET PAYABLE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                s.netPayable,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Actions.
          Row(
            children: [
              Expanded(
                flex: 11,
                child: approved
                    ? _approvedChip()
                    : _primaryBtn(
                        'Approve',
                        onTap: () => _approve(s),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 9,
                child: _outlineBtn(
                  held ? 'Held' : 'Hold',
                  onTap: () => _hold(s),
                  active: held,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 9,
                child: _outlineBtn(
                  'View',
                  icon: Icons.visibility_outlined,
                  onTap: () => _view(s),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _primaryBtn(String label, {required VoidCallback onTap}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _approvedChip() {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 18, color: Colors.white),
              SizedBox(width: 5),
              Text('Approved',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn(
    String label, {
    IconData? icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? AppColors.primary : AppColors.textPrimary,
          backgroundColor:
              active ? AppColors.softRedTint : Colors.transparent,
          padding: EdgeInsets.zero,
          side: BorderSide(
              color: active ? AppColors.primary : AppColors.fieldBorder),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Actions -------------------------------------------------------------

  void _approve(SalaryListItem s) {
    setState(() {
      _approved.add(s.id);
      _held.remove(s.id);
    });
    _snack('${_firstName(s)}\'s salary approved.');
  }

  void _hold(SalaryListItem s) {
    setState(() {
      if (_held.contains(s.id)) {
        _held.remove(s.id);
      } else {
        _held.add(s.id);
        _approved.remove(s.id);
      }
    });
    _snack(_held.contains(s.id)
        ? '${_firstName(s)}\'s salary put on hold.'
        : 'Hold removed for ${_firstName(s)}.');
  }

  String _firstName(SalaryListItem s) =>
      s.name.isEmpty ? 'Employee' : s.name.split(' ').first;

  /// Open the full salary detail (payslip) page for this employee.
  Future<void> _view(SalaryListItem s) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SalaryDetailPage(
        salaryId: s.id,
        fallbackName: s.name,
        monthLabel: '${_months[s.month - 1]} ${s.year}',
      ),
    ));
  }

  Widget _empty(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Bottom drawer that lists every employee with a salary record this month and
/// filters live as you type — same UX as the Employee Directory search.
class _SalaryPickerSheet extends StatefulWidget {
  const _SalaryPickerSheet({required this.items});
  final List<SalaryListItem> items;

  @override
  State<_SalaryPickerSheet> createState() => _SalaryPickerSheetState();
}

class _SalaryPickerSheetState extends State<_SalaryPickerSheet> {
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
        ? widget.items
        : widget.items
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.code.toLowerCase().contains(q) ||
                s.customId.toString().contains(q) ||
                s.departmentName.toLowerCase().contains(q))
            .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
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
                  ? Center(
                      child: Text('No employees found',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                    )
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

  Widget _row(SalaryListItem s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              children: [
                UserAvatar(name: s.name, radius: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name.isEmpty ? 'Employee #${s.customId}' : s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _badge(Icons.badge_outlined, s.code),
                          if (s.departmentName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: _badge(Icons.apartment, s.departmentName,
                                  muted: true),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.netPayable,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
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
}
