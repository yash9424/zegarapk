FACE RECOGNITION MODEL — REQUIRED FILE
======================================

The app identifies a face on-device using a TensorFlow Lite face-embedding
model. You must place ONE model file here:

    assets/models/mobilefacenet.tflite

Recommended model: MobileFaceNet (input 112x112x3, output 192-d embedding).
Free, widely used. Search "mobilefacenet.tflite" (e.g. on GitHub:
sirius-ai/MobileFaceNet_TF, or many Flutter face-recognition repos ship it).

If your model has a different input size or output length, update the
constants at the top of:

    lib/services/face/face_embedder.dart
      _inputSize   (default 112)
      _outputLen   (default 192)
      normalization (default (pixel - 127.5) / 128.0)

Without this file the app still runs, but face ENROLL and face ATTENDANCE
will show "face model not installed" instead of identifying people.
