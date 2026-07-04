import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/face/face_store.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/inline_face_enroll.dart';
import '../../widgets/search_field.dart';
import '../../widgets/user_avatar.dart';

/// Pick an existing employee (real list from the API). Selecting one fills the
/// detail fields, and the face is registered via the camera enrol flow.
class RegisterEmployeePage extends StatefulWidget {
  const RegisterEmployeePage({
    super.key,
    this.initialEmployeeId,
    this.initialEmployeeName,
    this.embedded = false,
  });

  /// When opened from an employee's profile, this employee is pre-selected so
  /// the inline camera is ready immediately (no need to search again).
  final int? initialEmployeeId;
  final String? initialEmployeeName;

  /// True when hosted as a tab inside [AdminShell] — then it renders just its
  /// content and lets the shell provide the single bottom nav bar.
  final bool embedded;

  @override
  State<RegisterEmployeePage> createState() => _RegisterEmployeePageState();
}

class _RegisterEmployeePageState extends State<RegisterEmployeePage> {
  bool _loading = true;
  String? _error;
  List<EmployeeListItem> _employees = const [];
  EmployeeListItem? _selected;

  // The captured face (held until an employee is chosen and Register is tapped).
  List<List<double>>? _embeddings;
  String? _faceImagePath;
  bool _submitting = false;

  // Keys the camera widget: swapping to a fresh key resets it after a
  // register, and gives the title-row button access to switchCamera().
  GlobalKey<InlineFaceEnrollState> _camKey = GlobalKey();

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
      final list = await ZedgiftApi.instance.employees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        // Pre-select the employee we were opened for (from a profile page).
        if (widget.initialEmployeeId != null) {
          for (final e in list) {
            if (e.id == widget.initialEmployeeId) {
              _selected = e;
              break;
            }
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load employees.';
        _loading = false;
      });
    }
  }

  Future<void> _pickEmployee() async {
    final picked = await showModalBottomSheet<EmployeeListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EmployeePickerSheet(employees: _employees),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  /// The face-capture area: a live inline camera that auto-scans the five
  /// angles. Capture happens first and independently of the employee — the
  /// result is held until "Register" is tapped.
  Widget _captureArea() {
    return InlineFaceEnroll(
      key: _camKey,
      size: 205, // compact enough for the whole page to fit one screen
      showSwitchButton: false, // the title row hosts the flip button
      onCaptured: (embeddings, imagePath) => setState(() {
        _embeddings = embeddings;
        _faceImagePath = imagePath;
      }),
      onRetake: () => setState(() {
        _embeddings = null;
        _faceImagePath = null;
      }),
    );
  }

  /// Attach the captured face to the selected employee: store it locally for
  /// offline kiosk matching and upload it to the API.
  Future<void> _register() async {
    final e = _selected;
    final emb = _embeddings;
    final path = _faceImagePath;
    if (e == null || emb == null || emb.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      await FaceStore.instance.enroll(e.id, e.name, emb);
      if (path != null) {
        await ZedgiftApi.instance
            .registerFace(e.id, path, embeddings: jsonEncode(emb));
      }
      if (!mounted) return;
      _snack('✓ Registered successfully for ${e.name}');
      // Reset for the next enrolment.
      setState(() {
        _embeddings = null;
        _faceImagePath = null;
        _selected = null;
        _submitting = false;
        _camKey = GlobalKey(); // recreate the camera widget fresh
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Could not register. Please try again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                // Title on the left, camera flip button on the right.
                Row(
                  children: [
                    const Text(
                      'Register Face',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1.15,
                      ),
                    ),
                    const Spacer(),
                    _swapCameraButton(),
                  ],
                ),
                const SizedBox(height: 10),
                Center(child: _captureArea()),
                const SizedBox(height: 14),
                _formCard(),
                const SizedBox(height: 12),
                _registerButton(),
              ],
            ),
          ),
        ],
      ),
    );

    // As a shell tab the bottom bar comes from AdminShell; standalone it
    // brings its own so the nav is always present.
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 1, // Register Face
        onTap: (i) => goToAdminTab(context, i),
      ),
      body: content,
    );
  }

  /// Camera flip (front ↔ back) — brand-red tile with a white icon.
  Widget _swapCameraButton() {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _camKey.currentState?.switchCamera(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.cameraswitch_rounded,
              color: Colors.white, size: 17),
        ),
      ),
    );
  }

  Widget _appBar() {
    return AppHeader(
      leadingIcon: Icons.arrow_back,
      // Embedded as a tab → go to Home; standalone → pop the route.
      onLeadingTap: () => widget.embedded
          ? adminTab.value = 0
          : Navigator.of(context).maybePop(),
    );
  }

  Widget _formCard() {
    final e = _selected;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Select Employee'),
          const SizedBox(height: 6),
          _employeePicker(),
          const SizedBox(height: 12),
          // Employee ID + Department side by side — both read-only.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _readFieldGroup(
                  'Employee ID',
                  e == null ? '' : e.customId.toString(),
                  'EMP ID',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _readFieldGroup(
                  'Department Name',
                  e?.departmentName ?? '',
                  'Department',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Enabled only when a face is captured AND an employee is chosen.
  Widget _registerButton() {
    final ready = _embeddings != null &&
        _embeddings!.isNotEmpty &&
        _selected != null &&
        !_submitting;
    final hint = _embeddings == null || _embeddings!.isEmpty
        ? 'Capture the face first'
        : _selected == null
            ? 'Choose an employee to register'
            : null;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: ready ? _register : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Register',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ],
      ],
    );
  }

  // ---- Field building blocks ---------------------------------------------

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

  BoxDecoration _fieldBox() => BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      );

  /// A label above a read-only field (used for the ID / Department pair).
  Widget _readFieldGroup(String label, String value, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        _readField(value, hint),
      ],
    );
  }

  /// Read-only filled field (auto-filled from the selected employee).
  Widget _readField(String value, String hint) {
    final empty = value.trim().isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: _fieldBox(),
      child: Text(
        empty ? hint : value,
        style: TextStyle(
          fontSize: 14,
          color: empty ? AppColors.textMuted : AppColors.textPrimary,
          fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _employeePicker() {
    final e = _selected;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _loading ? null : _pickEmployee,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: _fieldBox(),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _loading
                    ? 'Loading employees...'
                    : _error != null
                        ? _error!
                        : e == null
                            ? 'Choose an employee...'
                            : e.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: e == null ? AppColors.textMuted : AppColors.textPrimary,
                  fontWeight: e == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

}

/// Searchable employee picker (handles the ~900-employee list).
class _EmployeePickerSheet extends StatefulWidget {
  const _EmployeePickerSheet({required this.employees});
  final List<EmployeeListItem> employees;

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Grab handle.
            Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Title row + close.
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
            // Search.
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
                  ? _emptyState()
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
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _miniTag(Icons.badge_outlined, 'ID ${e.customId}'),
                          if (e.departmentName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: _miniTag(
                                  Icons.apartment, e.departmentName,
                                  muted: true),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.softRedTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: AppColors.primary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(IconData icon, String text, {bool muted = false}) {
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 46, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text('No employees found',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Try a different name, ID or department',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
