import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  DateTime _selectedMonth = DateTime(2023, 10);
  // The week strip shown in the design (Mon 23 → Sun 29), Tue selected.
  static const _days = [
    ('Mon', '23'),
    ('Tue', '24'),
    ('Wed', '25'),
    ('Thu', '26'),
    ('Fri', '27'),
    ('Sat', '28'),
    ('Sun', '29'),
  ];
  int _selectedDay = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _monthSelector(),
                const SizedBox(height: 16),
                _weekStrip(),
                const SizedBox(height: 20),
                _statRow(),
                const SizedBox(height: 18),
                for (final r in MockData.dayAttendance) ...[
                  _AttendanceCard(record: r),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
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
          const UserAvatar(
            name: MockData.adminName,
            imageUrl: MockData.adminAvatar,
            radius: 20,
            ring: true,
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  String get _monthLabel {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${names[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  Widget _monthSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _pickMonth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekStrip() {
    return Row(
      children: [
        const Icon(Icons.chevron_left, color: AppColors.textMuted),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _days.length; i++)
                Expanded(child: _dayChip(i, _days[i].$1, _days[i].$2)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ],
    );
  }

  Widget _dayChip(int i, String dow, String date) {
    final selected = _selectedDay == i;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              dow,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'PRESENT',
            MockData.attendancePresent,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            'ON TIME',
            MockData.attendanceOnTime,
            AppColors.textPrimary,
          ),
        ),
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

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record});
  final DayAttendance record;

  @override
  Widget build(BuildContext context) {
    final isLate = record.status == DayStatus.late;
    final cardColor =
        isLate ? const Color(0xFFFDF3F3) : AppColors.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_deptIcon(record.department),
                    color: AppColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.empId} • ${record.department}',
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
              _timeCol('In Time', record.inTime,
                  valueColor: isLate ? AppColors.primary : null),
              _timeCol('Out Time', record.outTime),
              _timeCol(
                'Total',
                '${record.totalMins} mins',
                valueColor: AppColors.primary,
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    final present = record.status == DayStatus.present;
    final color = present ? const Color(0xFF2BB673) : const Color(0xFFB8860B);
    final bg = present ? const Color(0xFFE7F7EF) : const Color(0xFFFBF3D9);
    final label = present ? 'PRESENT' : 'LATE';
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

  Widget _timeCol(String label, String value,
      {Color? valueColor, bool alignEnd = false}) {
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Expanded(
      child: Column(
        crossAxisAlignment: cross,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _deptIcon(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('engineer')) return Icons.engineering_outlined;
    if (d.contains('design')) return Icons.brush_outlined;
    if (d.contains('operation')) return Icons.settings_suggest_outlined;
    if (d.contains('security')) return Icons.shield_outlined;
    return Icons.badge_outlined;
  }
}
