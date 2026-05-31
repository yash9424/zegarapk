import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

class EmployeeMyAttendancePage extends StatefulWidget {
  const EmployeeMyAttendancePage({super.key});

  @override
  State<EmployeeMyAttendancePage> createState() =>
      _EmployeeMyAttendancePageState();
}

class _EmployeeMyAttendancePageState extends State<EmployeeMyAttendancePage> {
  static const _periods = ['This Week', 'Last Week', 'This Month', 'Last Month'];
  int _period = 2; // This Month
  DateTime _selected = DateTime(2026, 5, 31);

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String get _monthLabel =>
      '${_months[_selected.month - 1]} ${_selected.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  int _count(DayStatus s) =>
      MockData.myAttendance.where((d) => d.status == s).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    'My Attendance',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _monthSelector(),
                  const SizedBox(height: 14),
                  _periodChips(),
                  const SizedBox(height: 18),
                  _summary(),
                  const SizedBox(height: 20),
                  for (final d in MockData.myAttendance) ...[
                    _dayTile(d),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
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
          const UserAvatar(
            name: MockData.employeeName,
            imageUrl: MockData.employeeAvatar,
            radius: 18,
            ring: true,
          ),
        ],
      ),
    );
  }

  Widget _monthSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              _monthLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _periodChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final selected = _period == i;
          return GestureDetector(
            onTap: () => setState(() => _period = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.fieldBorder,
                ),
              ),
              child: Text(
                _periods[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
              'Present', _count(DayStatus.present), const Color(0xFF2BB673)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
              'Late', _count(DayStatus.late), const Color(0xFFE8923B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
              'Absent', _count(DayStatus.absent), AppColors.primary),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _dayTile(MyAttendanceDay d) {
    final style = _statusStyle(d.status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: style.$2),
              Expanded(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.date,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 2),
                          Text(d.weekday,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('In ${d.inTime}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 2),
                          Text('Out ${d.outTime}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      _pill(style.$1, style.$2, style.$3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _statusStyle(DayStatus s) {
    switch (s) {
      case DayStatus.present:
        return ('Present', const Color(0xFF2BB673), const Color(0xFFE7F7EF));
      case DayStatus.late:
        return ('Late', const Color(0xFFE8923B), const Color(0xFFFCEFE0));
      case DayStatus.absent:
        return ('Absent', AppColors.primary, AppColors.softRedTint);
    }
  }

  Widget _pill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          )),
    );
  }
}
