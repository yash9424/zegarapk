import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/face/face_embedder.dart';
import '../theme/app_theme.dart';

/// In-page, guided face CAPTURE that lives INSIDE the circle — no external
/// screen. The live camera fills the circle; a green ring around it fills up
/// (with a % in the middle) as each of the five angles is captured.
///
/// This widget only CAPTURES — it auto-scans the five angles and then hands the
/// embeddings + straight-on photo back via [onCaptured]. It does NOT need an
/// employee and does NOT upload anything; the parent attaches the captured face
/// to the chosen employee when "Register" is tapped.
class InlineFaceEnroll extends StatefulWidget {
  const InlineFaceEnroll({
    super.key,
    this.size = 240,
    this.onCaptured,
    this.onRetake,
    this.showSwitchButton = true,
  });

  final double size;

  /// Hide the built-in overlay flip button when the page hosts its own
  /// (e.g. next to the title). Switching is then driven via
  /// [InlineFaceEnrollState.switchCamera] through a GlobalKey.
  final bool showSwitchButton;

  /// Fired once all five angles are captured. The parent holds the data and
  /// uploads it after an employee is chosen and "Register" is tapped.
  final void Function(List<List<double>> embeddings, String? straightImagePath)?
      onCaptured;

  /// Fired when the user taps "Retake" — the parent should drop any held
  /// capture so the Register button disables again.
  final VoidCallback? onRetake;

  @override
  State<InlineFaceEnroll> createState() => InlineFaceEnrollState();
}

class _Step {
  const _Step(this.instruction, this.icon);
  final String instruction;
  final IconData icon;
}

class InlineFaceEnrollState extends State<InlineFaceEnroll> {
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
  // Lowest |yaw|+|pitch| seen so far — picks the most front-facing frame for
  // the photo we freeze on (a clean straight face, never a tilt).
  double _bestStraightScore = 999;

  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.front; // front by default
  int _loopId = 0; // bumps each _startLoop so stale loops retire

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
      _cameras = await availableCameras();
      await _openCamera(_lens);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _fatal = 'Could not open the camera';
      });
    }
  }

  /// Open (or re-open) the camera for the given lens direction.
  Future<void> _openCamera(CameraLensDirection lens) async {
    final desc = _cameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => _cameras.first,
    );
    final cam =
        CameraController(desc, ResolutionPreset.medium, enableAudio: false);
    await cam.initialize();
    if (!mounted) {
      await cam.dispose();
      return;
    }
    setState(() {
      _cam = cam;
      _lens = desc.lensDirection;
      _initializing = false;
    });
    _startLoop();
  }

  /// Flip between the front and back camera. Resets the capture in progress.
  /// Public so a host page can trigger it from its own button via a GlobalKey.
  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _initializing) return;
    _looping = false;
    final old = _cam;
    setState(() {
      _cam = null;
      _initializing = true;
      _embeddings.clear();
      _straightImagePath = null;
      _bestStraightScore = 999;
      _step = 0;
      _seen = 0;
      _done = false;
      _hint = '';
    });
    widget.onRetake?.call();
    await old?.dispose();
    final next = _lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    try {
      await _openCamera(next);
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
  /// A loop token ensures that switching the camera (which starts a fresh
  /// loop) cleanly retires the previous one — no two loops running at once.
  Future<void> _startLoop() async {
    final id = ++_loopId;
    _looping = true;
    while (_looping && mounted && !_done && _fatal == null && id == _loopId) {
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

      // Keep the most front-facing frame seen anywhere in the session as the
      // display/upload photo — guarantees a straight face, not a head-down one.
      final straightScore = y.abs() + x.abs();
      if (straightScore < _bestStraightScore) {
        _bestStraightScore = straightScore;
        _straightImagePath = shot.path;
      }

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

      if (_step >= _steps.length - 1) {
        _finish();
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

  void _finish() {
    _looping = false;
    if (!mounted) return;
    setState(() => _done = true);
    widget.onCaptured
        ?.call(List<List<double>>.of(_embeddings), _straightImagePath);
  }

  /// Discard the capture and scan again from the first angle.
  void _reset() {
    _embeddings.clear();
    _straightImagePath = null;
    _bestStraightScore = 999;
    setState(() {
      _step = 0;
      _seen = 0;
      _done = false;
      _hint = '';
    });
    widget.onRetake?.call();
    _startLoop();
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
              // Flip-camera button (front ↔ back), top-right of the circle.
              // Hidden when the host page provides its own switch button.
              if (widget.showSwitchButton &&
                  _fatal == null &&
                  !_done &&
                  _cameras.length > 1)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: switchCamera,
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(Icons.cameraswitch_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
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
    // After capture, freeze the circle on the captured photo (not the live
    // camera). "Retake" clears _done and brings the camera back.
    if (_done && _straightImagePath != null) {
      // Mirror only for the front camera so the frozen photo matches the
      // selfie-style preview; the back camera is already un-mirrored.
      final mirror = _lens == CameraLensDirection.front;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scaleByDouble(mirror ? -1.0 : 1.0, 1.0, 1.0, 1.0),
        child: Image.file(
          File(_straightImagePath!),
          fit: BoxFit.cover,
          width: widget.size - 18,
          height: widget.size - 18,
        ),
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
      return Column(
        children: [
          const Text('Face captured ✓',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
          const SizedBox(height: 2),
          Text('Now choose the employee below, then tap Register.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retake'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      );
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
