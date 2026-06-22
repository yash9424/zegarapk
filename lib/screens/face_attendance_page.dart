import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'admin/employee_detail_page.dart';
import '../services/api_client.dart';
import '../services/face/face_embedder.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Kiosk attendance by face. The phone detects the face and makes an
/// embedding; the SERVER (`/attendance/face/punch`) identifies the employee
/// and records the punch. Works from any device that's logged in once.
class FaceAttendancePage extends StatefulWidget {
  const FaceAttendancePage({super.key});

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends State<FaceAttendancePage> {
  final _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  CameraController? _cam;
  bool _initializing = true;
  bool _busy = false;
  String? _fatal;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!ApiClient.instance.hasDeviceAccess) {
      setState(() {
        _initializing = false;
        _fatal = 'This device is not set up.\nAn admin must log in once.';
      });
      return;
    }
    await FaceEmbedder.instance.ensureLoaded();
    if (!FaceEmbedder.instance.isReady) {
      setState(() {
        _initializing = false;
        _fatal =
            'Face model not installed.\nAdd assets/models/mobilefacenet.tflite';
      });
      return;
    }
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final cam = CameraController(front, ResolutionPreset.medium,
          enableAudio: false);
      await cam.initialize();
      if (!mounted) return;
      setState(() {
        _cam = cam;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _initializing = false;
        _fatal = 'Could not open the camera.';
      });
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _scan() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await cam.takePicture();
      final faces =
          await _detector.processImage(InputImage.fromFilePath(shot.path));
      if (faces.isEmpty) {
        _snack('No face detected. Try again.', error: true);
        return;
      }
      final bytes = await shot.readAsBytes();
      final emb = await FaceEmbedder.instance
          .embed(bytes, faceRect: faces.first.boundingBox);
      if (emb == null) {
        _snack('Could not read the face.', error: true);
        return;
      }

      // Server identifies + punches. Send the device's exact time so the
      // punch is recorded in real time.
      final now = DateTime.now();
      final res = await ZedgiftApi.instance
          .attendanceByFace(emb, timestamp: _apiTimestamp(now));
      if (!mounted) return;

      final empId =
          int.tryParse((res['employee_id'] ?? '').toString()) ?? 0;
      // Server's punch response has no name — fetch it for the result screen.
      var name =
          (res['name'] ?? res['employee_name'] ?? '').toString().trim();
      if (name.isEmpty && empId > 0) {
        try {
          name = (await ZedgiftApi.instance.employeeDetail(empId)).name;
        } catch (_) {}
        if (!mounted) return;
      }
      if (name.isEmpty) name = 'Employee';
      // Server uses `type` ("in"/"out"); also accept punch_status/status.
      final status =
          (res['type'] ?? res['punch_status'] ?? res['status'] ?? '')
              .toString()
              .toLowerCase();
      final isIn = status == 'in';
      final label = status == 'in'
          ? 'Clocked IN'
          : status == 'out'
              ? 'Clocked OUT'
              : 'Attendance Marked';
      // Always show DD-MM-YYYY + 12-hour, regardless of server format.
      final timeText = _displayStamp(now);

      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _AttendanceResultPage(
          employeeId: empId,
          name: name,
          statusLabel: label,
          isIn: isIn,
          timeText: timeText,
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true); // e.g. "Face not recognized."
    } catch (_) {
      if (!mounted) return;
      _snack('Scan failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  /// Format the API wants: Y-m-d H:i:s (24-hour).
  String _apiTimestamp(DateTime t) =>
      '${t.year}-${_2(t.month)}-${_2(t.day)} ${_2(t.hour)}:${_2(t.minute)}:${_2(t.second)}';

  /// Display format: DD-MM-YYYY + 12-hour (e.g. 16-06-2026  09:05 AM).
  String _displayStamp(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '${_2(t.day)}-${_2(t.month)}-${t.year}  $h:${_2(t.minute)} $ap';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.primaryDark : AppColors.textPrimary,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Face Attendance'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_fatal!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      );
    }
    final cam = _cam;
    if (cam == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(child: CameraPreview(cam)),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            children: [
              const Text('Position your face in the frame and tap Scan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _scan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Icon(Icons.face),
                  label: Text(_busy ? 'Scanning...' : 'Scan Face'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-screen confirmation shown after a successful punch.
class _AttendanceResultPage extends StatelessWidget {
  const _AttendanceResultPage({
    required this.employeeId,
    required this.name,
    required this.statusLabel,
    required this.isIn,
    required this.timeText,
  });

  final int employeeId;
  final String name;
  final String statusLabel;
  final bool isIn;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final accent = isIn ? const Color(0xFF2BB673) : AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: accent, size: 64),
              const SizedBox(height: 18),
              UserAvatar(name: name, radius: 50, ring: true),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  timeText.isEmpty
                      ? 'Marked via Face'
                      : 'Marked via Face • $timeText',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 32),
              if (employeeId > 0)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmployeeDetailPage(
                            employeeId: employeeId, fallbackName: name),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('View Full Profile'),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
