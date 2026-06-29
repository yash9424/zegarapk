import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/api_client.dart';
import '../services/face/face_embedder.dart';
import '../services/zedgift_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Kiosk attendance by face. The camera auto-detects whoever stands in front
/// of it — no tapping. The SERVER (`/attendance/face/punch`) identifies the
/// employee and records the punch; on success the screen shows a quick
/// confirmation and then resets itself for the next person.
class FaceAttendancePage extends StatefulWidget {
  const FaceAttendancePage({super.key});

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

enum _Phase { scanning, marking, success }

class _FaceAttendancePageState extends State<FaceAttendancePage>
    with TickerProviderStateMixin {
  final _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  CameraController? _cam;
  bool _initializing = true;
  String? _fatal;

  // Auto-scan state.
  bool _busy = false; // a tick is in flight
  bool _looping = false;
  bool _needClear = false; // the previous person must step away before re-punch
  _Phase _phase = _Phase.scanning;
  String _hint = 'Look at the camera to mark attendance';

  // Last successful punch (shown briefly, then cleared).
  String _resultName = '';
  String _resultLabel = '';
  bool _resultIsIn = false;

  // Live clock.
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  // Continuous rotation for the red arc that sweeps around the circle.
  late final AnimationController _rotate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  static const _innerSize = 250.0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
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
        _fatal = 'Could not open the camera.';
      });
    }
  }

  @override
  void dispose() {
    _looping = false;
    _clockTimer.cancel();
    _pulse.dispose();
    _rotate.dispose();
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  /// Continuous auto-scan: every tick looks for a single face and, when found,
  /// punches attendance. Pauses itself while marking / showing a result.
  Future<void> _startLoop() async {
    if (_looping) return;
    _looping = true;
    while (_looping && mounted && _fatal == null) {
      if (_phase == _Phase.scanning && !_busy) {
        await _tick();
      }
      await Future<void>.delayed(Duration(milliseconds: _busy ? 120 : 600));
    }
  }

  Future<void> _tick() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    _busy = true;
    try {
      final shot = await cam.takePicture();
      final faces =
          await _detector.processImage(InputImage.fromFilePath(shot.path));

      if (faces.isEmpty) {
        _needClear = false; // area cleared — ready for the next person
        _setHint('Look at the camera to mark attendance');
        return;
      }
      if (faces.length > 1) {
        _setHint('One person at a time, please');
        return;
      }
      if (_needClear) {
        _setHint('Please step aside for the next person');
        return;
      }

      final bytes = await shot.readAsBytes();
      final emb = await FaceEmbedder.instance
          .embed(bytes, faceRect: faces.first.boundingBox);
      if (emb == null) {
        _setHint('Move into better light');
        return;
      }

      // A clear single face — try to mark attendance.
      if (mounted) setState(() => _phase = _Phase.marking);
      final now = DateTime.now();
      final res = await ZedgiftApi.instance
          .attendanceByFace(emb, timestamp: _apiTimestamp(now));
      if (!mounted) return;

      var name = (res['name'] ?? res['employee_name'] ?? '').toString().trim();
      final empId = int.tryParse((res['employee_id'] ?? '').toString()) ?? 0;
      if (name.isEmpty && empId > 0) {
        try {
          name = (await ZedgiftApi.instance.employeeDetail(empId)).name;
        } catch (_) {}
        if (!mounted) return;
      }
      if (name.isEmpty) name = 'Employee';
      final status =
          (res['type'] ?? res['punch_status'] ?? res['status'] ?? '')
              .toString()
              .toLowerCase();

      setState(() {
        _phase = _Phase.success;
        _resultName = name;
        _resultIsIn = status == 'in';
        _resultLabel = status == 'in'
            ? 'Clocked IN'
            : status == 'out'
                ? 'Clocked OUT'
                : 'Attendance Marked';
        _needClear = true; // block re-punch until this person leaves
      });

      // Auto-reset for the next employee.
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.scanning;
          _hint = 'Look at the camera to mark attendance';
        });
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.scanning;
        _hint = e.message; // e.g. "Face not recognized."
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.scanning;
        _hint = 'Scan failed. Try again.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    } finally {
      _busy = false;
    }
  }

  void _setHint(String h) {
    if (mounted && _phase == _Phase.scanning && _hint != h) {
      setState(() => _hint = h);
    }
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  /// Format the API wants: Y-m-d H:i:s (24-hour).
  String _apiTimestamp(DateTime t) =>
      '${t.year}-${_2(t.month)}-${_2(t.day)} ${_2(t.hour)}:${_2(t.minute)}:${_2(t.second)}';

  static const _weekdays = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  static const _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  String get _clockText {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final ap = _now.hour < 12 ? 'AM' : 'PM';
    return '${_2(h)}:${_2(_now.minute)}:${_2(_now.second)} $ap';
  }

  String get _dateText =>
      '${_weekdays[_now.weekday - 1]}, ${_months[_now.month - 1]} ${_now.day}, ${_now.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_fatal != null) {
      return Column(
        children: [
          _header(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_fatal!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _header(),
        const SizedBox(height: 8),
        _clock(),
        const Spacer(),
        _cameraCircle(),
        const SizedBox(height: 24),
        // Fixed height so the circle never shifts when the status text changes
        // (hint ↔ "Marking…" ↔ name + badge are different heights).
        SizedBox(height: 120, child: Center(child: _statusArea())),
        const Spacer(flex: 2),
      ],
    );
  }

  /// Top bar — same shared header as the rest of the app, but with no admin
  /// avatar (this is the public kiosk, not an admin session).
  Widget _header() {
    return const AppHeader(leadingIcon: Icons.arrow_back, showAvatar: false);
  }

  Widget _clock() {
    return Column(
      children: [
        Text(
          _clockText,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _dateText,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _cameraCircle() {
    const outer = 296.0;
    final glow =
        _phase == _Phase.success ? const Color(0xFF2BB673) : AppColors.primary;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dark frame with an ambient coloured glow.
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF232A38), Color(0xFF11151E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.45),
                  blurRadius: 38,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          // Pulsing ring while scanning.
          if (_phase == _Phase.scanning)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final v = _pulse.value;
                return Container(
                  width: _innerSize + 16 + v * 18,
                  height: _innerSize + 16 + v * 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.55 - v * 0.45),
                      width: 3,
                    ),
                  ),
                );
              },
            ),
          // Red arc sweeping around the circle (same red-line vibe as the
          // header). Turns green once attendance is marked.
          AnimatedBuilder(
            animation: _rotate,
            builder: (_, __) => CustomPaint(
              size: const Size.square(_innerSize + 30),
              painter: _SweepArcPainter(
                _rotate.value,
                _phase == _Phase.success
                    ? const Color(0xFF2BB673)
                    : AppColors.primary,
              ),
            ),
          ),
          // Live camera.
          ClipOval(
            child: SizedBox(
              width: _innerSize,
              height: _innerSize,
              child: _preview(),
            ),
          ),
          // Marking spinner.
          if (_phase == _Phase.marking)
            Container(
              width: _innerSize,
              height: _innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
              ),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          // Success animation.
          if (_phase == _Phase.success) const _SuccessOverlay(size: _innerSize),
        ],
      ),
    );
  }

  Widget _preview() {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return Container(color: const Color(0xFF11151E));
    }
    final ps = cam.value.previewSize;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: ps?.height ?? _innerSize,
        height: ps?.width ?? _innerSize,
        child: CameraPreview(cam),
      ),
    );
  }

  Widget _statusArea() {
    if (_phase == _Phase.success) {
      final accent =
          _resultIsIn ? const Color(0xFF2BB673) : AppColors.primary;
      return Column(
        children: [
          Text(
            _resultName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _resultLabel,
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }
    if (_phase == _Phase.marking) {
      return Text(
        'Marking attendance…',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        _hint,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Green check that scales in over the camera circle on a successful punch.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, v, __) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: v,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2BB673).withValues(alpha: 0.82),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 96),
          ),
        ),
      ),
    );
  }
}

/// A short coloured arc with a comet-like fade that rotates around the camera
/// circle — the circular cousin of the header's sweeping red line.
class _SweepArcPainter extends CustomPainter {
  _SweepArcPainter(this.t, this.color);
  final double t; // 0..1 rotation progress
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    const sweep = math.pi * 0.42; // ~75° comet tail
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Rotate the whole canvas so the arc spins continuously — the gradient
    // seam stays at the transparent tail, so there's no visible "stop".
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 2 * math.pi);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withValues(alpha: 0.0), color],
      ).createShader(rect);

    canvas.drawArc(rect, 0, sweep, false, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SweepArcPainter old) =>
      old.t != t || old.color != color;
}
