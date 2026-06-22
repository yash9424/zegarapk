import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';

// ---- Date / time formatting helpers (shared) -----------------------------

String _two(int n) => n.toString().padLeft(2, '0');

/// `dd/MM/yyyy` — the format the leave endpoints expect.
String formatApiDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// `hh:mm AM/PM` — the format the leave endpoints expect.
String formatApiTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '${_two(h)}:${_two(t.minute)} $ampm';
}

/// Parse a stored value like `2026-06-20 08:00:00` (or `2026-06-20`) into a
/// [DateTime]. Returns null if it can't be parsed.
DateTime? parseApiDateTime(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  return DateTime.tryParse(v.replaceFirst(' ', 'T'));
}

/// A form to apply for a leave (create) or edit an existing one.
///
/// - Create mode (employee/kiosk): no [fixedEmployeeId] → shows an employee
///   picker so the person selects their name, then submits a new leave.
/// - Edit mode (admin): pass [editLeaveId] + [fixedEmployeeId] → the employee
///   is locked and the form updates that leave.
///
/// Pops with `true` when a leave was successfully created/updated so the
/// caller can refresh its list.
class LeaveFormPage extends StatefulWidget {
  const LeaveFormPage({
    super.key,
    this.editLeaveId,
    this.fixedEmployeeId,
    this.fixedEmployeeName,
    this.initialStart,
    this.initialEnd,
    this.initialStartTime,
    this.initialEndTime,
    this.initialReason,
  });

  final int? editLeaveId;
  final int? fixedEmployeeId;
  final String? fixedEmployeeName;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final String? initialReason;

  bool get isEdit => editLeaveId != null;

  @override
  State<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  // Employee selection (create mode only).
  List<EmployeeListItem> _employees = const [];
  bool _loadingEmployees = false;
  String? _employeesError;
  int? _selectedEmployeeId;
  String _selectedEmployeeName = '';

  // Form values.
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  final TextEditingController _reason = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = widget.initialStart ?? DateTime(now.year, now.month, now.day);
    _endDate = widget.initialEnd ?? _startDate;
    _startTime = widget.initialStartTime ?? const TimeOfDay(hour: 8, minute: 0);
    _endTime = widget.initialEndTime ?? const TimeOfDay(hour: 18, minute: 0);
    _reason.text = widget.initialReason ?? '';
    _selectedEmployeeId = widget.fixedEmployeeId;
    _selectedEmployeeName = widget.fixedEmployeeName ?? '';
    if (widget.fixedEmployeeId == null) _loadEmployees();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _employeesError = null;
    });
    try {
      final list = await ZedgiftApi.instance.employees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loadingEmployees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employeesError = 'Could not load employees.';
        _loadingEmployees = false;
      });
    }
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

  Future<void> _pickEmployee() async {
    final picked = await showModalBottomSheet<EmployeeListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EmployeePickerSheet(
        employees: _employees,
        loading: _loadingEmployees,
        error: _employeesError,
        onRetry: _loadEmployees,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedEmployeeId = picked.id;
        _selectedEmployeeName = picked.name;
      });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    final empId = _selectedEmployeeId;
    if (empId == null) {
      _snack('Please select an employee.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _snack('End date cannot be before the start date.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      _snack('Please enter a reason.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ZedgiftApi.instance;
      final startDate = formatApiDate(_startDate);
      final endDate = formatApiDate(_endDate);
      final startTime = formatApiTime(_startTime);
      final endTime = formatApiTime(_endTime);
      final reason = _reason.text.trim();

      if (widget.isEdit) {
        await api.updateLeave(
          widget.editLeaveId!,
          employeeId: empId,
          startDate: startDate,
          endDate: endDate,
          startTime: startTime,
          endTime: endTime,
          reason: reason,
        );
      } else {
        await api.createLeave(
          employeeId: empId,
          startDate: startDate,
          endDate: endDate,
          startTime: startTime,
          endTime: endTime,
          reason: reason,
        );
      }
      if (!mounted) return;
      _snack(widget.isEdit
          ? 'Leave updated successfully.'
          : 'Leave submitted — pending approval.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(widget.isEdit
          ? 'Could not update the leave. Please try again.'
          : 'Could not submit the leave. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          widget.isEdit ? 'Edit Leave' : 'Apply for Leave',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _label('Employee'),
            const SizedBox(height: 8),
            _employeeField(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    label: 'Start Date',
                    value: formatApiDate(_startDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickDate(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    label: 'End Date',
                    value: formatApiDate(_endDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickDate(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    label: 'Start Time',
                    value: _startTime.format(context),
                    icon: Icons.access_time,
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    label: 'End Time',
                    value: _endTime.format(context),
                    icon: Icons.access_time,
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _label('Reason'),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Reason for the leave',
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.isEdit ? 'Save Changes' : 'Submit Leave',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  Widget _employeeField() {
    // Edit mode (or a fixed employee): locked, read-only display.
    if (widget.fixedEmployeeId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedEmployeeName.isEmpty
                    ? 'Employee'
                    : _selectedEmployeeName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.lock_outline,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      );
    }

    final hasSelection = _selectedEmployeeId != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _loadingEmployees ? null : _pickEmployee,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_outlined,
                color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _loadingEmployees
                    ? 'Loading employees…'
                    : hasSelection
                        ? _selectedEmployeeName
                        : 'Select your name',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                  color: hasSelection
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Employee picker bottom sheet ----------------------------------------

class _EmployeePickerSheet extends StatefulWidget {
  const _EmployeePickerSheet({
    required this.employees,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<EmployeeListItem> employees;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.employees
        : widget.employees
            .where((e) =>
                e.name.toLowerCase().contains(q) ||
                e.customId.toString().contains(q))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or ID',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _body(filtered)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<EmployeeListItem> filtered) {
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(widget.error!,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: widget.onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text('No employees found.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final e = filtered[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              e.name.isEmpty ? '?' : e.name[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(e.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              if (e.customId != 0) 'ID ${e.customId}',
              if (e.departmentName.isNotEmpty) e.departmentName,
            ].join(' • '),
          ),
          onTap: () => Navigator.of(context).pop(e),
        );
      },
    );
  }
}
