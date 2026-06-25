import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/face/face_embedder.dart';
import '../services/face/face_store.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';

/// In-page, guided face enrolment that lives INSIDE the circle — no external
/// screen. The live camera fills the circle; a green ring around it fills up
/// (with a % in the middle) as each of the five angles is captured.
///
/// Tap the circle to capture the current angle. When all angles are done the
/// descriptors are stored locally (for offline kiosk matching) and the
/// straight-on photo + embeddings are uploaded to `/attendance/face/register`.
class InlineFaceEnroll extends StatefulWidget {
  const InlineFaceEnroll({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.size = 240,
    this.onEnrolled,
  });

  final int employeeId;
  final String employeeName;
  final double size;
  final VoidCallback? onEnrolled;

  @override
  State<InlineFaceEnroll> createState() => _InlineFaceEnrollState();
}

class _Step {
  const _Step(this.instruction, this.icon);
  final String instruction;
  final IconData icon;
}

class _InlineFaceEnrollState extends State<InlineFaceEnroll> {
  static const _steps = <_Step>[
    _Step('Look straight at the camera', Icons.center_focus_strong),
    _Step('Slowly turn your head RIGHT', Icons.arrow_forward),
    _Step('Slowly turn your head LEFT', Icons.arrow_back),
    _Step('Tilt your head UP', Icons.arrow_upward),
    _Step('Tilt your head DOWN', Icons.arrow_downward),
  ];

  static const _green = Color(0xFF2BB673);

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  CameraController? _cam;
  bool _initializing = true;
  bool _busy = false; // guards against overlapping captures
  bool _done = false;
  bool _looping = false;
  String? _fatal;
  String _hint = '';
  int _step = 0;
  int _seen = 0; // face-sightings for the current step (for force-accept)

  final List<List<double>> _embeddings = [];
  String? _straightImagePath;

  double get _progress => _embeddings.length / _steps.length;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await FaceEmbedder.instance.ensureLoaded();
    if (!FaceEmbedder.instance.isReady) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _fatal = 'Face model not installed';
      });
      return;
    }
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final cam =
          CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await cam.initialize();
      if (!mounted) return;
      setState(() {
        _cam = cam;
        _initializing = false;
      });
      _startLoop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _fatal = 'Could not open the camera';
      });
    }
  }

  @override
  void dispose() {
    _looping = false;
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  /// Auto-capture loop: every tick it looks for a single face in the right
  /// pose for the current step and captures it automatically. No tapping.
  Future<void> _startLoop() async {
    if (_looping) return;
    _looping = true;
    while (_looping && mounted && !_done && _fatal == null) {
      await _tick();
      // Pause longer after a successful capture so the user can reposition.
      await Future<void>.delayed(
          Duration(milliseconds: _busy ? 100 : 750));
    }
  }

  /// Does the head pose match what the current step asks for? Returns true
  /// also after enough sightings, so a user who can't hit the exact angle
  /// still progresses (force-accept).
  bool _poseOk(double y, double x) {
    if (_seen >= 6) return true; // force-accept fallback
    switch (_step) {
      case 1:
        return y > 15; // turned right
      case 2:
        return y < -15; // turned left
      case 3:
        return x > 10; // tilted up
      case 4:
        return x < -10; // tilted down
      default:
        return y.abs() <= 16 && x.abs() <= 16; // straight
    }
  }

  Future<void> _tick() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _busy || _done) return;
    _busy = true;
    try {
      final shot = await cam.takePicture();
      final faces =
          await _detector.processImage(InputImage.fromFilePath(shot.path));

      if (faces.isEmpty) {
        if (mounted) setState(() => _hint = 'Show your face in the circle');
        return;
      }
      if (faces.length > 1) {
        if (mounted) setState(() => _hint = 'Only one person, please');
        return;
      }

      final face = faces.first;
      _seen++;
      final y = face.headEulerAngleY ?? 0;
      final x = face.headEulerAngleX ?? 0;
      if (!_poseOk(y, x)) {
        if (mounted) setState(() => _hint = 'Hold the pose…');
        return;
      }

      // Pose matched — capture this angle.
      final bytes = await shot.readAsBytes();
      final emb = await FaceEmbedder.instance
          .embed(bytes, faceRect: face.boundingBox);
      if (emb == null) {
        if (mounted) setState(() => _hint = 'Move into better light');
        return;
      }

      _embeddings.add(emb);
      if (_step == 0) _straightImagePath = shot.path;

      if (_step >= _steps.length - 1) {
        await _finish();
      } else {
        if (mounted) {
          setState(() {
            _step++;
            _seen = 0;
            _hint = '';
          });
        }
      }
    } catch (_) {
      // A transient camera/detector error — just try again next tick.
    } finally {
      _busy = false;
    }
  }

  Future<void> _finish() async {
    _looping = false;
    await FaceStore.instance
        .enroll(widget.employeeId, widget.employeeName, _embeddings);
    try {
      if (_straightImagePath != null) {
        await ZedgiftApi.instance.registerFace(
          widget.employeeId,
          _straightImagePath!,
          embeddings: jsonEncode(_embeddings),
        );
      }
    } catch (_) {/* local enrolment still succeeded */}

    if (!mounted) return;
    setState(() => _done = true);
    _snack('✓ Face registered for ${widget.employeeName}');
    widget.onEnrolled?.call();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.primaryDark : _green,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).round();
    return Column(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Live camera filling the circle.
              ClipOval(
                child: SizedBox(
                  width: widget.size - 18,
                  height: widget.size - 18,
                  child: _preview(),
                ),
              ),
              // Green progress ring (animates as it fills).
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                builder: (_, v, child) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _RingPainter(v),
                ),
              ),
              // Centre status: % while capturing, check when done.
              if (_fatal == null) _centreBadge(percent),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _caption(),
      ],
    );
  }

  Widget _preview() {
    final cam = _cam;
    if (_fatal != null) {
      return Container(
        color: const Color(0xFF2A3142),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(_fatal!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );
    }
    if (_initializing || cam == null || !cam.value.isInitialized) {
      return Container(
        color: const Color(0xFF2A3142),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white54),
      );
    }
    final ps = cam.value.previewSize;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: ps?.height ?? widget.size,
        height: ps?.width ?? widget.size,
        child: CameraPreview(cam),
      ),
    );
  }

  /// A small badge sitting at the bottom of the ring — % while in progress,
  /// a green tick once enrolment is complete.
  Widget _centreBadge(int percent) {
    return Positioned(
      bottom: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _done ? _green : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _done
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Done',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              )
            : Text('$percent%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _caption() {
    if (_fatal != null) {
      return Text(_fatal!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    }
    if (_done) {
      return Text('Face registered successfully.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _green));
    }
    final step = _steps[_step];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(step.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(step.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _hint.isNotEmpty
              ? _hint
              : 'Auto-scanning…  •  Step ${_step + 1} of ${_steps.length}',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - 6) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.white.withValues(alpha: 0.30);
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2BB673);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
