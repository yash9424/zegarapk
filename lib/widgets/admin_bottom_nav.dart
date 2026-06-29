import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_drawer.dart';

final ValueNotifier<int> adminTab = ValueNotifier<int>(0);

/// Handle a bottom-nav tap. The three items are:
///   0 = Home, 1 = Register Face, 2 = Log Out.
/// Home & Register are shell tabs (one shared bar), so we just switch the tab
/// after popping any sub-page that's open on top of the shell.
void goToAdminTab(BuildContext context, int index) {
  switch (index) {
    case 0: // Home
      adminTab.value = 0;
      Navigator.of(context).popUntil((r) => r.isFirst);
      break;
    case 1: // Register Face
      adminTab.value = 1;
      Navigator.of(context).popUntil((r) => r.isFirst);
      break;
    case 2: // Log Out
      confirmAndLogout(Navigator.of(context, rootNavigator: true));
      break;
  }
}

class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, String)>[
    (Icons.home_rounded, 'Home'),
    (Icons.face_retouching_natural, 'Register'),
    (Icons.logout_rounded, 'Logout'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: SlidingNav(
            currentIndex: currentIndex,
            items: _items,
            activeColor: AppColors.primary,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Shared sliding-capsule nav. The capsule translates smoothly between tabs.
class SlidingNav extends StatelessWidget {
  const SlidingNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.activeColor,
    required this.onTap,
  });

  final int currentIndex;
  final List<(IconData, String)> items;
  final Color activeColor;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tabW = constraints.maxWidth / items.length;
      const capsuleH = 40.0;
      // Size the capsule snugly to the active label (icon + gap + text +
      // padding), clamped so it never spills past its tab.
      final tp = TextPainter(
        text: TextSpan(
          text: items[currentIndex].$2,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final capsuleW = (tp.width + 22 + 7 + 28).clamp(86.0, tabW - 6).toDouble();
      final capsuleLeft = tabW * currentIndex + (tabW - capsuleW) / 2;

      return Stack(
        children: [
          // Animated sliding capsule.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            left: capsuleLeft,
            top: (constraints.maxHeight - capsuleH) / 2,
            width: capsuleW,
            height: capsuleH,
            child: Container(
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          // Tap targets + icons/labels on top.
          Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              items[i].$1,
                              size: 22,
                              color: currentIndex == i
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                            if (currentIndex == i) ...[
                              const SizedBox(width: 7),
                              Text(
                                items[i].$2,
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }
}
