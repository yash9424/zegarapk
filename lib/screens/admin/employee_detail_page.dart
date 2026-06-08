import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

/// Full employee profile loaded live from `GET /employees/{id}`, plus the
/// person's recent attendance from `GET /attendance/history`.
class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({
    super.key,
    required this.employeeId,
    this.fallbackName = '',
  });

  final int employeeId;
  final String fallbackName;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  bool _loading = true;
  String? _error;
  EmployeeDetail? _emp;
  List<AttendanceHistoryDay> _history = const [];

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
      final emp = await ZedgiftApi.instance.employeeDetail(widget.employeeId);
      // Attendance history is best-effort; never block the profile on it.
      List<AttendanceHistoryDay> hist = const [];
      try {
        hist = await ZedgiftApi.instance.attendanceHistory(widget.employeeId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _emp = emp;
        _history = hist;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this employee.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: Text(_emp?.name.isNotEmpty == true
            ? _emp!.name
            : (widget.fallbackName.isEmpty ? 'Employee' : widget.fallbackName)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _emp == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error ?? 'Not found',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final e = _emp!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _header(e),
        const SizedBox(height: 20),
        _section('Work', [
          _row('Employee ID', e.customId.toString()),
          _row('Department', e.departmentName),
          _row('Designation', e.designationName),
          _row('Type', e.typeName),
          _row('Date of joining', e.doj),
          _row('Previous company', e.previousCompany),
        ]),
        const SizedBox(height: 16),
        _section('Personal', [
          _row('Phone', e.phone),
          _row('Emergency', e.emergencyPhone),
          _row('Education', e.education),
          _row('Date of birth', e.dob),
          _row('Current city', e.currentState),
          _row('Current address', e.currentAddress),
          _row('Permanent address', e.permanentAddress),
        ]),
        const SizedBox(height: 16),
        _section('Salary', [
          _row('Salary', e.salary),
          _row('Net salary', e.netSalary),
        ]),
        if (e.banks.isNotEmpty) ...[
          const SizedBox(height: 16),
          _section('Bank', [
            for (final b in e.banks) ...[
              _row('Bank', b.bankName),
              _row('A/C holder', b.holderName),
              _row('A/C number', b.accountNumber),
              _row('IFSC', b.ifsc),
              _row('Branch', b.branch),
            ],
          ]),
        ],
        const SizedBox(height: 16),
        _attendanceSection(),
      ],
    );
  }

  Widget _header(EmployeeDetail e) {
    return Row(
      children: [
        UserAvatar(name: e.name, radius: 34, ring: true),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name.isEmpty ? 'Unnamed' : e.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [e.designationName, e.departmentName]
                    .where((s) => s.isNotEmpty)
                    .join(' • '),
                style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final visible = rows.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final v = value.trim();
    if (v.isEmpty || v == '0' || v == '1970-01-01') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT ATTENDANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            Text('No attendance records.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else
            for (final d in _history) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(d.date,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('In  ${d.dutyIn}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Out ${d.dutyOut}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const Divider(height: 14, color: AppColors.divider),
            ],
        ],
      ),
    );
  }
}
