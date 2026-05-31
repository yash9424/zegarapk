import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Circular avatar that shows a network photo and falls back to the
/// person's initials if the image can't be loaded (e.g. offline / CORS).
///
/// Uses [Image.network] with an [errorBuilder] so a failed load never
/// throws an unhandled exception — it simply renders the initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.ring = false,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final bool ring;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _initialsCircle() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _initialsCircle();

    Widget avatar;
    if (imageUrl == null || imageUrl!.isEmpty) {
      avatar = fallback;
    } else {
      avatar = ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // On web, draw via a real <img> element so cross-origin photos
          // display without a CORS fetch failing.
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (context, error, stack) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      );
    }

    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: avatar,
    );
  }
}
