import 'package:flutter/material.dart';

/// ZEGAR brand logo — renders the official wordmark image
/// (`assets/images/cropped-zlogo.png`).
///
/// [fontSize] is kept for backward compatibility with the many call sites that
/// pass it; it now controls the rendered logo height (height ≈ fontSize × 1.7)
/// so the image scales the same way the old text wordmark did.
class ZegarLogo extends StatelessWidget {
  const ZegarLogo({super.key, this.fontSize = 30});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/cropped-zlogo.png',
      height: fontSize * 1.7,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
