import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Wraps the on-device TensorFlow Lite face-embedding model.
///
/// Turns a face image into a fixed-length vector ("descriptor") that can be
/// compared with [cosine]. Identical faces give a high similarity (close to
/// 1.0); different people give a low one.
///
/// The model file is loaded from `assets/models/mobilefacenet.tflite`. If it
/// is missing the embedder stays [isReady] == false and callers should show a
/// "model not installed" message instead of trying to identify anyone.
class FaceEmbedder {
  FaceEmbedder._();
  static final FaceEmbedder instance = FaceEmbedder._();

  // Adjust these to match your model (see assets/models/README.txt).
  static const String _asset = 'assets/models/mobilefacenet.tflite';
  static const int _inputSize = 112;
  static const int _outputLen = 192;

  Interpreter? _interpreter;
  bool _tried = false;

  bool get isReady => _interpreter != null;

  /// Load the model once. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_tried) return;
    _tried = true;
    try {
      _interpreter = await Interpreter.fromAsset(_asset);
    } catch (_) {
      _interpreter = null; // model file not present / invalid
    }
  }

  /// Compute a normalised embedding for a face inside [jpegBytes].
  /// If [faceRect] is given the image is cropped to it first (recommended —
  /// pass the ML Kit bounding box). Returns null if the model isn't ready or
  /// the image can't be decoded.
  Future<List<double>?> embed(Uint8List jpegBytes, {Rect? faceRect}) async {
    final interp = _interpreter;
    if (interp == null) return null;

    var image = img.decodeImage(jpegBytes);
    if (image == null) return null;
    // Apply EXIF rotation so pixel coords line up with the ML Kit face box.
    image = img.bakeOrientation(image);

    if (faceRect != null) {
      final x = faceRect.left.clamp(0, image.width - 1).toInt();
      final y = faceRect.top.clamp(0, image.height - 1).toInt();
      final w = faceRect.width.clamp(1, image.width - x).toInt();
      final h = faceRect.height.clamp(1, image.height - y).toInt();
      image = img.copyCrop(image, x: x, y: y, width: w, height: h);
    }

    final resized =
        img.copyResize(image, width: _inputSize, height: _inputSize);

    // Build the [1, size, size, 3] float input, normalised to [-1, 1].
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [
            (p.r - 127.5) / 128.0,
            (p.g - 127.5) / 128.0,
            (p.b - 127.5) / 128.0,
          ];
        }),
      ),
    );

    final output =
        List.generate(1, (_) => List<double>.filled(_outputLen, 0.0));
    interp.run(input, output);

    return _l2normalize(output[0]);
  }

  List<double> _l2normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return v;
    return [for (final x in v) x / norm];
  }

  /// Cosine similarity of two L2-normalised vectors (just their dot product).
  static double cosine(List<double> a, List<double> b) {
    if (a.length != b.length) return -1;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }
}
