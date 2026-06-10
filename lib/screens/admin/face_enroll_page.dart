import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../services/face/face_embedder.dart';
import '../../services/face/face_store.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';

class _Step {
  const _Step(this.instruction, this.icon);
  final String instruction;
  final IconData icon;
}

/// Guided, multi-angle face enrolment. The admin captures the employee from
/// five angles; each capture is turned into a descriptor and stored on the
/// device (so the kiosk can identify offline) and the straight-on photo is
/// also uploaded to the backend (`/attendance/face/register`).
class FaceEnrollPage extends StatefulWidget {
  const FaceEnrollPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  final int employeeId;
  final String employeeName;

  @override
  State<FaceEnrollPage> createState() => _FaceEnrollPageState();
}

class _FaceEnrollPageState extends State<FaceEnrollPage> {
  static const _steps = <_Step>[
    _Step('Look straight at the camera', Icons.center_focus_strong),
    _Step('Slowly turn your head RIGHT', Icons.arrow_forward),
    _Step('Slowly turn your head LEFT', Icons.arrow_back),
    _Step('Tilt your head UP', Icons.arrow_upward),
    _Step('Tilt your head DOWN', Icons.arrow_downward),
  ];

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  CameraController? _cam;
  bool _initializing = true;
  bool _busy = false;
  String? _fatal;
  int _step = 0;

  final List<List<double>> _embeddings = [];
  String? _straightImagePath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await FaceEmbedder.instance.ensureLoaded();
    if (!FaceEmbedder.instance.isReady) {
      setState(() {
        _initializing = false;
        _fatal = 'Face model not installed.\nAdd assets/models/mobilefacenet.tflite';
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

  Future<void> _captureStep() async {
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
      if (faces.length > 1) {
        _snack('Multiple faces — only one person please.', error: true);
        return;
      }

      final bytes = await shot.readAsBytes();
      final emb = await FaceEmbedder.instance
          .embed(bytes, faceRect: faces.first.boundingBox);
      if (emb == null) {
        _snack('Could not read the face. Try again.', error: true);
        return;
      }

      _embeddings.add(emb);
      if (_step == 0) _straightImagePath = shot.path;

      if (_step >= _steps.length - 1) {
        await _finish();
      } else {
        setState(() => _step++);
      }
    } catch (e) {
      _snack('Capture failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    // Save locally for offline kiosk matching.
    await FaceStore.instance
        .enroll(widget.employeeId, widget.employeeName, _embeddings);

    // Also push the straight photo + descriptor to the backend.
    try {
      if (_straightImagePath != null) {
        await ZedgiftApi.instance.registerFace(
          widget.employeeId,
          _straightImagePath!,
          descriptor: jsonEncode(_embeddings), // all angles
        );
      }
    } catch (_) {/* local enrolment still succeeded */}

    if (!mounted) return;
    _snack('✓ Face enrolled for ${widget.employeeName}');
    Navigator.of(context).pop(true);
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
        title: const Text('Enroll Face'),
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

    final step = _steps[_step];
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(cam),
              // Progress dots.
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _embeddings.length
                              ? const Color(0xFF2BB673)
                              : (i == _step
                                  ? AppColors.primary
                                  : Colors.white38),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            children: [
              Icon(step.icon, color: Colors.white, size: 34),
              const SizedBox(height: 10),
              Text(
                step.instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Step ${_step + 1} of ${_steps.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _captureStep,
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
                      : const Icon(Icons.camera_alt),
                  label: Text(_busy ? 'Processing...' : 'Capture'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
