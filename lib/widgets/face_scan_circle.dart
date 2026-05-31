import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The circular face-capture preview: a photo with a red ring, a dashed
/// inner guide circle and corner focus brackets — like the screenshot.
class FaceScanCircle extends StatelessWidget {
  const FaceScanCircle({super.key, required this.imageUrl, this.size = 240});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Photo clipped to a circle with a red ring.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFF2A3142),
                  child: const Icon(Icons.person,
                      color: Colors.white54, size: 90),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFF2A3142),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  );
                },
              ),
            ),
          ),
          // Dashed guide circle + corner focus brackets.
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _ScanOverlayPainter()),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Dashed inner circle.
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.55);

    final radius = size.width * 0.40;
    const dashes = 56;
    for (var i = 0; i < dashes; i++) {
      if (i.isOdd) continue;
      final a0 = (i / dashes) * 2 * math.pi;
      final a1 = ((i + 1) / dashes) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, a0, a1 - a0, false, dashPaint);
    }

    // Corner focus brackets around the centre.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7FD8C4);

    final b = size.width * 0.20; // half side of the focus square
    final len = size.width * 0.07;
    final corners = [
      Offset(center.dx - b, center.dy - b),
      Offset(center.dx + b, center.dy - b),
      Offset(center.dx - b, center.dy + b),
      Offset(center.dx + b, center.dy + b),
    ];
    // top-left
    _drawBracket(canvas, bracket, corners[0], len, true, true);
    _drawBracket(canvas, bracket, corners[1], len, false, true);
    _drawBracket(canvas, bracket, corners[2], len, true, false);
    _drawBracket(canvas, bracket, corners[3], len, false, false);
  }

  void _drawBracket(Canvas canvas, Paint p, Offset c, double len,
      bool left, bool top) {
    final dx = left ? len : -len;
    final dy = top ? len : -len;
    canvas.drawLine(c, c.translate(dx, 0), p);
    canvas.drawLine(c, c.translate(0, dy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
