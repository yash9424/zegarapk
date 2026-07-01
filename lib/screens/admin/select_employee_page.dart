import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/employee_picker_sheet.dart';
import '../../widgets/search_field.dart';
import 'employee_detail_page.dart';

enum _Section { salary, advance, loan }

/// Pick an employee (searchable, like Register Face) and show their Salary /
/// Advance / Loan records inline — the same data shown in the employee profile
/// tabs, against the live API. "Manage" opens the full profile tab for edits.
class SelectEmployeePage extends StatefulWidget {
  const SelectEmployeePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tabIndex,
  });

  final String title;
  final String subtitle;

  /// Tab in [EmployeeDetailPage]: 1 Payroll(Salary), 3 Advance, 4 Deductions.
  final int tabIndex;

  @override
  State<SelectEmployeePage> createState() => _SelectEmployeePageState();
}

class _SelectEmployeePageState extends State<SelectEmployeePage> {
  bool _loading = true;
  String? _error;
  List<EmployeeListItem> _employees = const [];
  EmployeeListItem? _selected;

  // Records for the selected employee.
  bool _recLoading = false;
  String? _recError;
  List<AdvanceRecord> _adv = const [];
  List<DeductionRecord> _ded = const [];
  List<SalaryRecord> _sal = const [];
  List<NamedCount> _dedTypes = const []; // loan/deduction types for the form

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Month / Year filter (same as the Salary page).
  late int _month;
  late int _year;

  _Section get _section => switch (widget.tabIndex) {
        1 => _Section.salary,
        4 => _Section.loan,
        _ => _Section.advance,
      };

  String _mName(int m) => (m >= 1 && m <= 12) ? _months[m - 1] : '$m';

  /// Format a server `created_at` ("2026-06-29 10:30:00") to a friendly
  /// "29 Jun 2026, 10:30 AM". Falls back to the raw value if unparseable.
  String _fmtDateTime(String raw) {
    if (raw.trim().isEmpty) return '';
    final dt = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_mName(dt.month)} ${dt.year}, $h:$mm $ap';
  }

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
      final list = await ZedgiftApi.instance.employees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load employees.';
        _loading = false;
      });
    }
  }

  Future<void> _pickEmployee() async {
    final picked = await pickEmployee(context, _employees);
    if (picked != null && mounted) {
      setState(() => _selected = picked);
      _loadRecords(picked.id);
    }
  }

  Future<void> _loadRecords(int empId) async {
    setState(() {
      _recLoading = true;
      _recError = null;
      _adv = const [];
      _ded = const [];
      _sal = const [];
    });
    try {
      final api = ZedgiftApi.instance;
      switch (_section) {
        case _Section.advance:
          _adv = await api.advances(empId, month: _month, year: _year);
          break;
        case _Section.loan:
          final r = await Future.wait([
            api.deductions(empId, month: _month, year: _year),
            api.deductionTypes(),
          ]);
          _ded = r[0] as List<DeductionRecord>;
          _dedTypes = r[1] as List<NamedCount>;
          break;
        case _Section.salary:
          final now = DateTime.now();
          final futures = <Future<SalaryRecord?>>[];
          for (var i = 0; i < 6; i++) {
            final d = DateTime(now.year, now.month - i, 1);
            futures.add(api.salaryForMonth(empId, d.month, d.year));
          }
          _sal = (await Future.wait(futures)).whereType<SalaryRecord>().toList();
          break;
      }
      if (!mounted) return;
      setState(() => _recLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recError = 'Could not load ${widget.title.toLowerCase()} records.';
        _recLoading = false;
      });
    }
  }

  void _openFullProfile() {
    final e = _selected;
    if (e == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EmployeeDetailPage(
        employeeId: e.id,
        fallbackName: e.name,
        initialTab: widget.tabIndex,
      ),
    ));
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

  // ---- CRUD: Advance -------------------------------------------------------

  Future<void> _advanceForm({AdvanceRecord? existing}) async {
    final empId = _selected!.id;
    final now = DateTime.now();
    final amountCtl = TextEditingController(
        text: existing == null ? '' : existing.amountRaw.toStringAsFixed(0));
    final remarkCtl = TextEditingController(text: existing?.remark ?? '');
    var month = existing?.month ?? now.month;
    var year = existing?.year ?? now.year;

    final ok = await _formSheet(
      title: existing == null ? 'Add Advance' : 'Edit Advance',
      builder: (setSheet) => [
        _monthYearRow(month, year, (m, y) => setSheet(() {
              month = m;
              year = y;
            })),
        const SizedBox(height: 14),
        _formField(amountCtl, 'Amount (₹)', number: true),
        const SizedBox(height: 14),
        _formField(remarkCtl, 'Remark (optional)'),
      ],
    );
    if (ok != true) return;
    final amount = amountCtl.text.trim();
    if (amount.isEmpty) {
      _snack('Enter an amount.');
      return;
    }
    try {
      final api = ZedgiftApi.instance;
      if (existing == null) {
        await api.createAdvance(
            employeeId: empId,
            month: month,
            year: year,
            amount: amount,
            remark: remarkCtl.text);
      } else {
        await api.updateAdvance(existing.id,
            employeeId: empId,
            month: month,
            year: year,
            amount: amount,
            remark: remarkCtl.text);
      }
      _snack('Advance saved.');
      _loadRecords(empId);
    } catch (_) {
      _snack('Could not save. Please try again.');
    }
  }

  // ---- CRUD: Deduction (Loan) ----------------------------------------------

  Future<void> _deductionForm({DeductionRecord? existing}) async {
    final empId = _selected!.id;
    if (_dedTypes.isEmpty) {
      _snack('Deduction types not available.');
      return;
    }
    final amountCtl = TextEditingController(
        text: existing == null ? '' : existing.amountRaw.toStringAsFixed(0));
    final descCtl = TextEditingController(text: existing?.description ?? '');
    var typeId = existing?.typeId ?? _dedTypes.first.id;

    final ok = await _formSheet(
      title: existing == null ? 'Add Loan / Deduction' : 'Edit Deduction',
      builder: (setSheet) => [
        _dropdown<int>(
          label: 'Type',
          value: _dedTypes.any((t) => t.id == typeId)
              ? typeId
              : _dedTypes.first.id,
          items: [for (final t in _dedTypes) (t.id, t.name)],
          onChanged: (v) => setSheet(() => typeId = v),
        ),
        const SizedBox(height: 14),
        _formField(amountCtl, 'Amount (₹)', number: true),
        const SizedBox(height: 14),
        _formField(descCtl, 'Description (optional)'),
      ],
    );
    if (ok != true) return;
    final amount = amountCtl.text.trim();
    if (amount.isEmpty) {
      _snack('Enter an amount.');
      return;
    }
    try {
      final api = ZedgiftApi.instance;
      if (existing == null) {
        await api.createDeduction(
            employeeId: empId,
            typeId: typeId,
            amount: amount,
            description: descCtl.text);
      } else {
        await api.updateDeduction(existing.id,
            employeeId: empId,
            typeId: typeId,
            amount: amount,
            description: descCtl.text);
      }
      _snack('Deduction saved.');
      _loadRecords(empId);
    } catch (_) {
      _snack('Could not save. Please try again.');
    }
  }

  // ---- Row actions (edit / delete / payout) --------------------------------

  Future<void> _advanceActions(AdvanceRecord a) async {
    final action = await _actionSheet(
      '${_mName(a.month)} ${a.year} • ${a.amount}',
      [
        if (!a.paid) ('payout', Icons.check_circle_outline, 'Mark paid out'),
        ('edit', Icons.edit_outlined, 'Edit'),
        ('delete', Icons.delete_outline, 'Delete'),
      ],
    );
    final empId = _selected!.id;
    if (action == 'edit') {
      await _advanceForm(existing: a);
    } else if (action == 'delete') {
      if (await _confirmDelete('advance')) {
        try {
          await ZedgiftApi.instance.deleteAdvance(a.id);
          _snack('Advance deleted.');
          _loadRecords(empId);
        } catch (_) {
          _snack('Could not delete.');
        }
      }
    } else if (action == 'payout') {
      try {
        await ZedgiftApi.instance.payoutAdvance(a.id);
        _snack('Marked as paid out.');
        _loadRecords(empId);
      } catch (_) {
        _snack('Could not update.');
      }
    }
  }

  Future<void> _deductionActions(DeductionRecord d) async {
    final action = await _actionSheet(
      '${d.typeName} • ${d.amount}',
      [
        ('edit', Icons.edit_outlined, 'Edit'),
        ('delete', Icons.delete_outline, 'Delete'),
      ],
    );
    final empId = _selected!.id;
    if (action == 'edit') {
      await _deductionForm(existing: d);
    } else if (action == 'delete') {
      if (await _confirmDelete('deduction')) {
        try {
          await ZedgiftApi.instance.deleteDeduction(d.id);
          _snack('Deduction deleted.');
          _loadRecords(empId);
        } catch (_) {
          _snack('Could not delete.');
        }
      }
    }
  }

  // ---- Small reusable form widgets -----------------------------------------

  Future<bool?> _formSheet({
    required String title,
    required List<Widget> Function(void Function(void Function()) setSheet)
        builder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              ...builder(setSheet),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController c, String hint,
      {bool number = false}) {
    return TextField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: [
            for (final it in items)
              DropdownMenuItem<T>(value: it.$1, child: Text(it.$2)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _monthYearRow(
      int month, int year, void Function(int, int) onChanged) {
    final now = DateTime.now();
    final years = [for (var y = now.year - 2; y <= now.year + 1; y++) y];
    return Row(
      children: [
        Expanded(
          child: _dropdown<int>(
            label: 'Month',
            value: month,
            items: [for (var m = 1; m <= 12; m++) (m, _mName(m))],
            onChanged: (m) => onChanged(m, year),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dropdown<int>(
            label: 'Year',
            value: years.contains(year) ? year : now.year,
            items: [for (final y in years) (y, '$y')],
            onChanged: (y) => onChanged(month, y),
          ),
        ),
      ],
    );
  }

  Future<String?> _actionSheet(
      String title, List<(String, IconData, String)> options) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            for (final o in options)
              ListTile(
                leading: Icon(o.$2, color: AppColors.primary),
                title: Text(o.$3,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(String what) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Permanently delete this $what?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return ok == true;
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _titleRow(),
                  const SizedBox(height: 16),
                  _searchBar(),
                  const SizedBox(height: 20),
                  if (_selected != null) _recordsArea(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
    return const AppHeader(leadingIcon: Icons.arrow_back);
  }

  /// Title (brand red) on the left + Month / Year filter pills on the right —
  /// same layout as the Salary page.
  Widget _titleRow() {
    return Row(
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const Spacer(),
        _filterPill(label: _months[_month - 1], onTap: _pickMonth),
        const SizedBox(width: 8),
        _filterPill(label: '$_year', onTap: _pickYear),
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
              Text(label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
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
      if (_selected != null) _loadRecords(_selected!.id);
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
      if (_selected != null) _loadRecords(_selected!.id);
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

  /// Shared search bar (same as the Salary page) — tapping opens the employee
  /// picker sheet.
  Widget _searchBar() {
    final e = _selected;
    return SearchField(
      hint: _loading
          ? 'Loading employees...'
          : _error != null
              ? _error!
              : e == null
                  ? 'Search employee name or ID...'
                  : e.name,
      onTap: _loading ? () {} : _pickEmployee,
    );
  }

  // ---- Records (inline, mirrors the profile tab) ---------------------------

  Widget _recordsArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${widget.title} Records',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (_section == _Section.salary)
              GestureDetector(
                onTap: _openFullProfile,
                child: const Text(
                  'Slips',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _section == _Section.advance
                    ? _advanceForm()
                    : _deductionForm(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.softRedTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Add ${widget.title}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (_recError != null)
          _empty(_recError!)
        else
          ..._rows(),
      ],
    );
  }

  /// Full-month date range, e.g. "01 Jun – 30 Jun, 2026".
  String _monthRange(int m, int y) {
    final last = DateTime(y, m + 1, 0).day;
    final mm = _mName(m);
    return '01 $mm – $last $mm, $y';
  }

  List<Widget> _rows() {
    switch (_section) {
      case _Section.advance:
        if (_adv.isEmpty) return [_empty('No advances found.')];
        return [
          for (final a in _adv)
            _recordCard(
              icon: Icons.event_rounded,
              title: '${_mName(a.month)} ${a.year}',
              subtitle: _monthRange(a.month, a.year),
              amount: a.amount,
              pill: a.paid ? 'Paid' : 'Pending',
              pillOk: a.paid,
              onTap: () => _advanceActions(a),
            ),
        ];
      case _Section.loan:
        if (_ded.isEmpty) return [_empty('No loan / deduction records found.')];
        return [
          for (final d in _ded)
            _recordCard(
              icon: Icons.account_balance_rounded,
              title: d.typeName.isEmpty ? 'Deduction' : d.typeName,
              subtitle: d.description.isNotEmpty
                  ? d.description
                  : _fmtDateTime(d.date),
              amount: d.amount,
              onTap: () => _deductionActions(d),
            ),
        ];
      case _Section.salary:
        if (_sal.isEmpty) return [_empty('No payroll records found.')];
        return [
          for (final s in _sal)
            _recordCard(
              icon: Icons.receipt_long_rounded,
              title: '${_mName(s.month)} ${s.year}',
              subtitle: 'Base ${s.fixSalary}',
              amount: s.netSalary,
            ),
        ];
    }
  }

  Widget _recordCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    String? pill,
    bool pillOk = false,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Leading icon box.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softRedTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(icon, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (pill != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: pillOk
                        ? const Color(0xFFE7F7EF)
                        : AppColors.softRedTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pill,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: pillOk
                          ? const Color(0xFF2BB673)
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: onTap == null
          ? card
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: card,
              ),
            ),
    );
  }

  Widget _empty(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(
        msg,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
