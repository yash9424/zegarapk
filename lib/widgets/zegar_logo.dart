import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ZEGAR wordmark — "ZE" + red circle Z badge + "AR®"
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

    final badgeSize = fontSize * 1.18;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('ZE', style: letterStyle),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.04),
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryLight, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'G',
              style: TextStyle(
                fontSize: fontSize * 0.72,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
                shadows: const [
                  Shadow(
                    color: Color(0x44000000),
                    offset: Offset(1, 2),
                    blurRadius: 4,
                  ),
                ],
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
