import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Kiosk-style attendance: an employee finds their name, captures their face
/// and the app marks a punch (`type=face`). The server auto-toggles in/out.
///
/// Requires the device to be authenticated — an admin logs in once and the
/// token is kept on the device, so this screen works from the login page.
class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  final _picker = ImagePicker();
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _loading = true;
  String? _error;
  List<EmployeeListItem> _all = const [];

  @override
  void initState() {
    super.initState();
    if (ApiClient.instance.isAuthenticated) {
      _load();
    } else {
      _loading = false;
      _error = 'not_authed';
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'load_failed';
        _loading = false;
      });
    }
  }

  List<EmployeeListItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.customId.toString().contains(q))
        .toList();
  }

  Future<void> _markFor(EmployeeListItem emp) async {
    // Capture the face as a presence check before punching.
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (shot == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final res = await ZedgiftApi.instance.punch(emp.id, type: 'face');
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loader
      final status = (res['punch_status'] ?? res['status'] ?? '')
          .toString()
          .toLowerCase();
      final inOut = status == 'in'
          ? 'Clocked IN'
          : status == 'out'
              ? 'Clocked OUT'
              : 'Attendance marked';
      _resultDialog(emp.name, inOut, ok: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _resultDialog(emp.name, e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _resultDialog(emp.name, 'Could not mark attendance.', ok: false);
    }
  }

  void _resultDialog(String name, String message, {required bool ok}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle : Icons.error_outline,
                color: ok ? const Color(0xFF2BB673) : AppColors.primary,
                size: 56),
            const SizedBox(height: 12),
            Text(name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error == 'not_authed') {
      return _centerMsg(
        Icons.lock_outline,
        'This device is not set up yet.\nAn admin must log in once to enable '
        'kiosk attendance.',
      );
    }
    if (_error == 'load_failed') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Could not load employees.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final list = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Find your name or ID...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _centerMsg(Icons.search_off, 'No match found')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading: UserAvatar(name: e.name, radius: 22),
                        title: Text(e.name.isEmpty ? 'Unnamed' : e.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        subtitle: Text(
                            'ID ${e.customId} • ${e.departmentName}',
                            style: TextStyle(color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.camera_alt_outlined,
                            color: AppColors.primary),
                        onTap: () => _markFor(e),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _centerMsg(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
