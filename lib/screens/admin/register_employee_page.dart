import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/face_scan_circle.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

class RegisterEmployeePage extends StatefulWidget {
  const RegisterEmployeePage({super.key});

  @override
  State<RegisterEmployeePage> createState() => _RegisterEmployeePageState();
}

class _RegisterEmployeePageState extends State<RegisterEmployeePage> {
  final _formKey = GlobalKey<FormState>();

  final _idCtrl = TextEditingController(text: 'EMP001');
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();

  String? _selectedEmployeeId;
  String? _department;
  String? _type;
  DateTime? _dateOfJoining;
  String _avatarUrl = 'https://i.pravatar.cc/400?img=68';

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _designationCtrl.dispose();
    super.dispose();
  }

  void _onSelectEmployee(String? id) {
    setState(() {
      _selectedEmployeeId = id;
      if (id == null) return;
      final e = MockData.employees.firstWhere((e) => e.id == id);
      _idCtrl.text = e.id;
      _nameCtrl.text = e.name;
      _phoneCtrl.text = e.phone;
      _designationCtrl.text = e.designation;
      _department = e.department;
      _type = e.type;
      _avatarUrl = e.avatarUrl;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfJoining ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateOfJoining = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfJoining == null) {
      _snack('Please pick the date of joining.');
      return;
    }
    _snack('Employee ${_nameCtrl.text} registered (mock).');
    Navigator.of(context).maybePop();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  String get _dateLabel {
    final d = _dateOfJoining;
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')} '
        '${_months[d.month - 1]} ${d.year}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Register Face',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Ensure the face is clearly visible within the frame.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(child: FaceScanCircle(imageUrl: _avatarUrl)),
                  const SizedBox(height: 16),
                  Center(child: _lightingBadge()),
                  const SizedBox(height: 24),
                  _formCard(),
                  const SizedBox(height: 18),
                  _registerButton(),
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
            name: MockData.adminName,
            imageUrl: MockData.adminAvatar,
            radius: 20,
            ring: true,
          ),
        ],
      ),
    );
  }

  Widget _lightingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softRedTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          SizedBox(width: 6),
          Text(
            'Optimal Lighting',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Select Employee'),
            const SizedBox(height: 8),
            _employeeDropdown(),
            const SizedBox(height: 18),
            _label('Employee ID'),
            const SizedBox(height: 8),
            _textField(_idCtrl, 'EMP001'),
            const SizedBox(height: 18),
            _label('Name'),
            const SizedBox(height: 8),
            _textField(_nameCtrl, 'Full name'),
            const SizedBox(height: 18),
            _label('Phone'),
            const SizedBox(height: 8),
            _textField(
              _phoneCtrl,
              '+1 415 555 0100',
              keyboard: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              ],
            ),
            const SizedBox(height: 18),
            _label('Department'),
            const SizedBox(height: 8),
            _stringDropdown(
              value: _department,
              hint: 'Select department',
              items: MockData.departments,
              onChanged: (v) => setState(() => _department = v),
            ),
            const SizedBox(height: 18),
            _label('Designation'),
            const SizedBox(height: 8),
            _textField(_designationCtrl, 'e.g. Senior Developer'),
            const SizedBox(height: 18),
            _label('Date Of Joining'),
            const SizedBox(height: 8),
            _dateField(),
            const SizedBox(height: 18),
            _label('Type'),
            const SizedBox(height: 8),
            _stringDropdown(
              value: _type,
              hint: 'Select type',
              items: MockData.employmentTypes,
              onChanged: (v) => setState(() => _type = v),
            ),
          ],
        ),
      ),
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

  InputDecoration _decoration(String hint) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      enabledBorder: border(AppColors.fieldBorder),
      border: border(AppColors.fieldBorder),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.primaryLight),
      focusedErrorBorder: border(AppColors.primary),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _decoration(hint),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'This field is required' : null,
    );
  }

  Widget _employeeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedEmployeeId,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
      decoration: _decoration('Choose an employee...'),
      hint: const Text('Choose an employee...',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      items: [
        for (final e in MockData.employees)
          DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.id})')),
      ],
      onChanged: _onSelectEmployee,
    );
  }

  Widget _stringDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
      decoration: _decoration(hint),
      hint: Text(hint,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select an option' : null,
    );
  }

  Widget _dateField() {
    final hasDate = _dateOfJoining != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDate,
      child: InputDecorator(
        decoration: _decoration('Select date'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dateLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: hasDate ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _registerButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text(
            'Register Employee',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
