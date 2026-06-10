import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'admin/employee_detail_page.dart';
import '../services/api_client.dart';
import '../services/face/face_embedder.dart';
import '../services/face/face_store.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Kiosk attendance by face. The employee taps "Scan", the app identifies
/// them from the enrolled faces, asks them to confirm (so look-alikes / twins
/// are never marked wrongly), then punches in/out and shows the result.
class FaceAttendancePage extends StatefulWidget {
  const FaceAttendancePage({super.key});

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

/// Full-screen confirmation shown after a successful punch: profile, the
/// in/out result, the method (Face) and time, plus a link to the full profile.
class _AttendanceResultPage extends StatelessWidget {
  const _AttendanceResultPage({
    required this.employeeId,
    required this.name,
    required this.statusLabel,
    required this.isIn,
  });

  final int employeeId;
  final String name;
  final String statusLabel;
  final bool isIn;

  String get _now {
    final t = DateTime.now();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

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
              Text('Marked via Face • $_now',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 32),
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

class _FaceAttendancePageState extends State<FaceAttendancePage> {
  // Minimum cosine similarity to accept a match (tune per model).
  static const double _threshold = 0.55;

  final _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  CameraController? _cam;
  bool _initializing = true;
  bool _busy = false;
  bool _syncing = false;
  String _syncMsg = '';
  String? _fatal;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!ApiClient.instance.isAuthenticated) {
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
    if (FaceStore.instance.count == 0) {
      // FaceStore loads lazily; trigger a load via identify on empty probe is
      // overkill, so just proceed — identify() will load and may return null.
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
      // First time on this device: pull enrolled faces from the server.
      final n = await FaceStore.instance.ensureLoadedCount();
      if (n == 0 && mounted) await _sync();
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

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncMsg = 'Syncing faces…';
    });
    try {
      final n = await FaceStore.instance.syncFromServer(
        onProgress: (d, t) {
          if (mounted) {
            final pct = t == 0 ? 0 : (d * 100 / t).round();
            setState(() => _syncMsg = 'Syncing faces… $pct%');
          }
        },
      );
      if (mounted) _snack('$n faces ready on this device');
    } catch (_) {
      if (mounted) _snack('Face sync failed. Check connection.', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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

      final match = await FaceStore.instance.identify(emb);
      if (match == null || match.score < _threshold) {
        _snack('Face not recognized. Please enroll first.', error: true);
        return;
      }

      final confirmed = await _confirm(match.name, match.score);
      if (confirmed != true) return;

      await _punch(match.employeeId, match.name);
    } catch (e) {
      _snack('Scan failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String name, double score) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Is this you?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 48, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Match ${(score * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, it\'s me',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _punch(int employeeId, String name) async {
    try {
      final res = await ZedgiftApi.instance.punch(employeeId, type: 'face');
      if (!mounted) return;
      final status =
          (res['punch_status'] ?? res['status'] ?? '').toString().toLowerCase();
      final isIn = status == 'in';
      final label = status == 'in'
          ? 'Clocked IN'
          : status == 'out'
              ? 'Clocked OUT'
              : 'Attendance Marked';
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _AttendanceResultPage(
          employeeId: employeeId,
          name: name,
          statusLabel: label,
          isIn: isIn,
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _snack('Could not mark attendance.', error: true);
    }
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
        actions: [
          if (_fatal == null)
            IconButton(
              tooltip: 'Sync faces from server',
              icon: const Icon(Icons.sync),
              onPressed: _syncing ? null : _sync,
            ),
        ],
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
    if (_syncing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(_syncMsg,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
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
