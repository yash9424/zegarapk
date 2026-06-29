import 'package:flutter/material.dart';

import '../services/mock_auth.dart';
import '../theme/app_theme.dart';
import 'admin_bottom_nav.dart';
import 'user_avatar.dart';
import 'zegar_logo.dart';

/// Shared top header for admin / kiosk screens so every page's header looks
/// like one consistent bar: a leading action (menu/back), the centered ZEGAR
/// logo, and the admin avatar (tap → Profile). The bottom corners are softly
/// curved and a red highlight sweeps across the bottom edge so the header
/// reads as a distinct, branded bar.
class AppHeader extends StatefulWidget {
  const AppHeader({
    super.key,
    this.leadingIcon = Icons.arrow_back,
    this.onLeadingTap,
    this.showLeading = true,
    this.showAvatar = true,
  });

  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final bool showLeading;
  final bool showAvatar;

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  static const _radius = Radius.circular(22);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _openProfile(BuildContext context) {
    adminTab.value = 3; // Profile tab in AdminShell
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final name = MockAuth.instance.currentUser?.name ?? 'Admin';
    final avatarUrl = MockAuth.instance.currentUser?.avatarUrl;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: _radius),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: _radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
              child: Row(
                children: [
                  if (widget.showLeading)
                    IconButton(
                      onPressed: widget.onLeadingTap ??
                          () => Navigator.of(context).maybePop(),
                      icon: Icon(widget.leadingIcon,
                          color: AppColors.textPrimary),
                      splashRadius: 22,
                    )
                  else
                    const SizedBox(width: 40),
                  const Spacer(),
                  const ZegarLogo(fontSize: 22),
                  const Spacer(),
                  if (widget.showAvatar)
                    GestureDetector(
                      onTap: () => _openProfile(context),
                      child: UserAvatar(
                          name: name,
                          imageUrl: avatarUrl,
                          radius: 20,
                          ring: true),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
            _sweepLine(),
          ],
        ),
      ),
    );
  }

  /// A faint red base line with a brighter red segment that sweeps across.
  Widget _sweepLine() {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final segW = w * 0.34;
          return AnimatedBuilder(
            animation: _sweep,
            builder: (_, __) {
              final left = _sweep.value * (w + segW) - segW;
              return Stack(
                children: [
                  Container(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  Positioned(
                    left: left,
                    width: segW,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primary,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
