import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';

/// Palette from the payslip design spec (§16). Red uses the app brand colour
/// for consistency; the rest match the spec swatches.
class _C {
  _C._();
  static const green = Color(0xFF10B981);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const slate = Color(0xFF64748B);
  static const ink = Color(0xFF0F172A);
  static const pink = Color(0xFFFEE2E2);
  static const cloud = Color(0xFFF1F5F9);
}

/// Full salary breakdown (payslip) for one employee's month. Opened when an
/// admin taps an employee on the Salary list.
class SalaryDetailPage extends StatefulWidget {
  const SalaryDetailPage({
    super.key,
    required this.salaryId,
    this.fallbackName = '',
    this.monthLabel = '',
  });

  final int salaryId;
  final String fallbackName;
  final String monthLabel;

  @override
  State<SalaryDetailPage> createState() => _SalaryDetailPageState();
}

class _SalaryDetailPageState extends State<SalaryDetailPage> {
  bool _loading = true;
  String? _error;
  SalaryDetail? _d;

  bool _approvedLocal = false;
  bool _heldLocal = false;
  bool _dedOpen = true;

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
      final d = await ZedgiftApi.instance.salaryFull(widget.salaryId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _approvedLocal = d.approved;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load salary details.';
        _loading = false;
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

  String _initials(String name) {
    final p =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
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
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null || _d == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error ?? 'Not found.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final d = _d!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _headerCard(d),
        const SizedBox(height: 16),
        _basicsCard(d),
        const SizedBox(height: 16),
        _daysCard(d),
        const SizedBox(height: 16),
        _earningCard(d),
        const SizedBox(height: 16),
        _deductionCard(d),
        const SizedBox(height: 16),
        _netCard(d),
        const SizedBox(height: 16),
        _companyCard(d),
        const SizedBox(height: 16),
        _quickActions(d),
      ],
    );
  }

  // ---- Shared card shell ---------------------------------------------------

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title, Color accent,
      {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.ink)),
        ),
        ?trailing,
      ],
    );
  }

  // ---- 4. Employee header + 5. actions -------------------------------------

  Widget _headerCard(SalaryDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _initials(d.name.isEmpty ? widget.fallbackName : d.name),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _idPill(d.code),
                    const SizedBox(height: 6),
                    Text(
                      d.name.isEmpty ? widget.fallbackName : d.name,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: _C.ink),
                    ),
                    if (d.designationName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(d.designationName,
                          style: TextStyle(
                              fontSize: 13.5, color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (d.departmentName.isNotEmpty)
                          _miniMeta(Icons.work_outline_rounded,
                              d.departmentName),
                        if (d.typeName.isNotEmpty)
                          _miniMeta(Icons.event_note_outlined, d.typeName),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _actionButtons(d),
        ],
      ),
    );
  }

  Widget _idPill(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _C.pink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(code,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary)),
    );
  }

  Widget _miniMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _actionButtons(SalaryDetail d) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _approvedLocal
                  ? null
                  : () {
                      // Approve only — just marks the salary approved.
                      setState(() => _approvedLocal = true);
                      _snack('Salary approved.');
                    },
              icon: Icon(
                  _approvedLocal
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline,
                  size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _approvedLocal ? _C.green : AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _C.green,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: Text(_approvedLocal ? 'Approved' : 'Approve',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _iconOutlineBtn(
          _heldLocal ? Icons.play_arrow_rounded : Icons.pause_circle_outline,
          'Hold',
          active: _heldLocal,
          onTap: () {
            setState(() {
              _heldLocal = !_heldLocal;
              if (_heldLocal) _approvedLocal = false;
            });
            _snack(_heldLocal ? 'Salary put on hold.' : 'Hold removed.');
          },
        ),
        const SizedBox(width: 10),
        _iconOutlineBtn(Icons.print_outlined, 'Print',
            onTap: () => _snack('Preparing pay slip…')),
      ],
    );
  }

  Widget _iconOutlineBtn(IconData icon, String label,
      {required VoidCallback onTap, bool active = false}) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? AppColors.primary : _C.ink,
          backgroundColor:
              active ? AppColors.softRedTint : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: BorderSide(
              color: active ? AppColors.primary : AppColors.fieldBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ---- 6. Salary basics + 7. status chips ----------------------------------

  Widget _basicsCard(SalaryDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.account_balance_wallet_outlined, 'Salary Basics',
              AppColors.primary),
          const SizedBox(height: 16),
          _basicsMetrics(d),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _labeledChip('PF Status', d.pfActive ? 'Active' : 'Inactive',
                  d.pfActive ? _C.green : _C.slate),
              _labeledChip('Fix Wage', d.fixWageLabel, _C.blue),
              _labeledChip(
                  'Status',
                  _heldLocal
                      ? 'On Hold'
                      : _approvedLocal
                          ? 'Approved'
                          : 'Pending',
                  _heldLocal
                      ? AppColors.primary
                      : _approvedLocal
                          ? _C.green
                          : AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  /// Four basics metrics: all in one row when there's room, otherwise a 2×2
  /// grid so nothing gets squeezed or overflows on a phone.
  Widget _basicsMetrics(SalaryDetail d) {
    final metrics = <(IconData, String, String)>[
      (Icons.payments_outlined, 'FIX SALARY', d.fixSalary),
      (Icons.schedule, 'WORKING HRS', d.workingHrs),
      (Icons.event_available_outlined, 'WORKING DAYS', d.workingDays),
      (Icons.timelapse_outlined, 'TOTAL MINUTES', d.totalMinutes),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        // ~110px per metric is comfortable; below that, drop to 2×2.
        final oneRow = c.maxWidth >= 440;
        if (oneRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in metrics)
                Expanded(child: _metric(m.$1, m.$2, m.$3)),
            ],
          );
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _metric(metrics[0].$1, metrics[0].$2, metrics[0].$3)),
                const SizedBox(width: 12),
                Expanded(child: _metric(metrics[1].$1, metrics[1].$2, metrics[1].$3)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _metric(metrics[2].$1, metrics[2].$2, metrics[2].$3)),
                const SizedBox(width: 12),
                Expanded(child: _metric(metrics[3].$1, metrics[3].$2, metrics[3].$3)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink)),
        ),
      ],
    );
  }

  Widget _labeledChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  // ---- 8. Days -------------------------------------------------------------

  Widget _daysCard(SalaryDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.calendar_month_outlined, 'Days', AppColors.primary),
          const SizedBox(height: 14),
          _kv('Present Days', d.presentDays, valueColor: AppColors.primary),
          const SizedBox(height: 10),
          _kv('Paid Holiday', d.paidHoliday),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _kv('Total Days', d.totalDays,
              valueColor: AppColors.primary, bold: true),
        ],
      ),
    );
  }

  // ---- 9. Total earning ----------------------------------------------------

  Widget _earningCard(SalaryDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
              Icons.savings_outlined, 'Total Earning Amount', _C.green),
          const SizedBox(height: 14),
          _amountRow('Basic Salary', d.basicSalary),
          _amountRow('OT Amount (${d.otHours} Hrs)', d.otAmount),
          _amountRow('Paid Holiday Amount', d.paidHolidayAmount),
          _amountRow('Meal Amount', d.mealAmount),
          _amountRow('Production Incentive', d.productionIncentive),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Row(
            children: [
              const Text('Gross Salary',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink)),
              const Spacer(),
              Text(d.grossSalary,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _C.green)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- 10. Deduction -------------------------------------------------------

  Widget _deductionCard(SalaryDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.trending_down_rounded, 'Deduction',
              AppColors.primary,
              trailing: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _dedOpen = !_dedOpen),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                      _dedOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                ),
              )),
          if (_dedOpen) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _pillKV('PF', d.pf)),
                const SizedBox(width: 10),
                Expanded(child: _pillKV('PT', d.pt)),
              ],
            ),
            const SizedBox(height: 14),
            _amountRow('Advance Payment', d.advancePayment),
            _amountRow('Loan Recovery', d.loanRecovery),
            _amountRow('Hold Salary Amount', d.holdSalary),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            Row(
              children: [
                const Text('Total Deduction',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _C.ink)),
                const Spacer(),
                Text(d.totalDeduction,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pillKV(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.cloud,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _C.ink)),
          ),
        ],
      ),
    );
  }

  // ---- 11. Net payable -----------------------------------------------------

  Widget _netCard(SalaryDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Net Payable Amount',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white.withValues(alpha: 0.9), size: 24),
            ],
          ),
          const SizedBox(height: 18),
          _netRow('BANK TRANSFER', d.bankTransfer, Icons.account_balance),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
                height: 1, color: Colors.white.withValues(alpha: 0.25)),
          ),
          _netRow('CASH PAYMENT', d.cashPayment, Icons.payments_rounded),
        ],
      ),
    );
  }

  Widget _netRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ),
        Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 34),
      ],
    );
  }

  // ---- 12. Company contribution --------------------------------------------

  Widget _companyCard(SalaryDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.groups_outlined, 'Company Contribution', _C.violet),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _contribBox('Bonus', d.bonus, _C.violet)),
              const SizedBox(width: 12),
              Expanded(child: _contribBox('EPF', d.epf, _C.violet)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.violet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CTC (Total Cost)',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(d.ctc,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.violet)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contribBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.cloud,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ---- 13. Quick actions ---------------------------------------------------

  Widget _quickActions(SalaryDetail d) {
    return Column(
      children: [
        _quickBtn(Icons.download_rounded, 'Download Pay Slip',
            () => _snack('Preparing pay slip…')),
        const SizedBox(height: 12),
        _quickBtn(Icons.mail_outline_rounded, 'Email to Employee',
            () => _snack('Emailing pay slip to employee…')),
      ],
    );
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19, color: _C.ink),
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.ink,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.fieldBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        label: Text(label,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ---- Small row helpers ---------------------------------------------------

  Widget _amountRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
        ],
      ),
    );
  }

  Widget _kv(String label, String value,
      {Color valueColor = _C.ink, bool bold = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? _C.ink : AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 17 : 15,
                fontWeight: FontWeight.w800,
                color: valueColor)),
      ],
    );
  }
}
