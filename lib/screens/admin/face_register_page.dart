import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';

/// Admin enrolls an employee's face: capture a photo with the camera and
/// upload it to `POST /attendance/face/register`.
class FaceRegisterPage extends StatefulWidget {
  const FaceRegisterPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  final int employeeId;
  final String employeeName;

  @override
  State<FaceRegisterPage> createState() => _FaceRegisterPageState();
}

class _FaceRegisterPageState extends State<FaceRegisterPage> {
  final _picker = ImagePicker();
  File? _photo;
  bool _saving = false;

  Future<void> _capture() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (shot == null) return;
      setState(() => _photo = File(shot.path));
    } catch (e) {
      _snack('Could not open camera.', error: true);
    }
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null) {
      _snack('Please capture a face photo first.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ZedgiftApi.instance.registerFace(widget.employeeId, photo.path);
      if (!mounted) return;
      _snack('✓ Face registered for ${widget.employeeName}');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Could not register face. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text('Register Face')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.employeeName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Capture a clear, front-facing photo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              Expanded(child: Center(child: _preview())),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _saving ? null : _capture,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_photo == null ? 'Capture Face' : 'Retake'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_photo == null || _saving) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Face',
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

  Widget _preview() {
    const size = 240.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: _photo == null
          ? const Icon(Icons.person_outline, size: 90, color: AppColors.textMuted)
          : ClipOval(
              child: Image.file(_photo!, fit: BoxFit.cover, width: size, height: size),
            ),
    );
  }
}
