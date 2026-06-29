import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../theme/app_theme.dart';
import 'search_field.dart';
import 'user_avatar.dart';

/// Shows the shared employee picker — a bottom drawer with a search bar, a
/// total-count badge and every employee shown with ID + department badges.
/// Returns the chosen employee, or null if dismissed. Used everywhere an
/// employee is searched (Register Face, Loan/Advance/Salary, Directory,
/// Attendance) so the search looks identical across the app.
Future<EmployeeListItem?> pickEmployee(
    BuildContext context, List<EmployeeListItem> employees) {
  return showModalBottomSheet<EmployeeListItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => EmployeePickerSheet(employees: employees),
  );
}

class EmployeePickerSheet extends StatefulWidget {
  const EmployeePickerSheet({super.key, required this.employees});
  final List<EmployeeListItem> employees;

  @override
  State<EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<EmployeePickerSheet> {
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
        ? widget.employees
        : widget.employees
            .where((e) =>
                e.name.toLowerCase().contains(q) ||
                e.customId.toString().contains(q) ||
                e.departmentName.toLowerCase().contains(q))
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
                  // Total-count badge.
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

  Widget _row(EmployeeListItem e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              children: [
                UserAvatar(name: e.name, radius: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name.isEmpty ? 'Unnamed' : e.name,
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
                          _badge(Icons.badge_outlined, 'ID ${e.customId}'),
                          if (e.departmentName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: _badge(Icons.apartment, e.departmentName,
                                  muted: true),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.primary),
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
