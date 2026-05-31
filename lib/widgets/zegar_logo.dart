import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "ZEGAR" wordmark with the stylised red hexagon "G" badge.
class ZegarLogo extends StatelessWidget {
  const ZegarLogo({super.key, this.fontSize = 30});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final letterStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
      color: AppColors.textPrimary,
      height: 1,
    );

    final badge = fontSize * 1.18;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('ZE', style: letterStyle),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.04),
          child: SizedBox(
            width: badge,
            height: badge,
            child: CustomPaint(
              painter: _HexPainter(),
              child: Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    fontSize: fontSize * 0.78,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        Text('AR', style: letterStyle),
        Transform.translate(
          offset: Offset(2, -fontSize * 0.36),
          child: Text(
            '®',
            style: TextStyle(
              fontSize: fontSize * 0.32,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pointy-top hexagon path.
    final path = Path();
    final points = <Offset>[
      Offset(w * 0.5, 0),
      Offset(w, h * 0.27),
      Offset(w, h * 0.73),
      Offset(w * 0.5, h),
      Offset(0, h * 0.73),
      Offset(0, h * 0.27),
    ];
    path.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryLight, AppColors.primaryDark],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
