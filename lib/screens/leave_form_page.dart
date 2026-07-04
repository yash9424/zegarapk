import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';
import '../widgets/employee_picker_sheet.dart';
import '../widgets/search_field.dart';

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
    if (_employeesError != null) {
      _loadEmployees(); // retry, the bar shows "Loading employees…"
      return;
    }
    final picked = await pickEmployee(context, _employees);
    if (picked != null && mounted) {
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
                hintText:
                    'Write the reason for this leave...\ne.g. Out of station, medical, family function',
                hintMaxLines: 3,
                hintStyle: const TextStyle(
                    fontSize: 13.5, color: AppColors.textMuted, height: 1.5),
                filled: true,
                fillColor: AppColors.fieldFill,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.4),
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
    // Shared search pill + picker drawer — identical to the Employees page.
    return SearchField(
      hint: _loadingEmployees
          ? 'Loading employees…'
          : _employeesError != null
              ? '$_employeesError Tap to retry.'
              : hasSelection
                  ? _selectedEmployeeName
                  : 'Search employee name or ID...',
      onTap: _loadingEmployees ? () {} : _pickEmployee,
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

