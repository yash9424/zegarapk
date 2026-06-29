import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared search input used on the admin list screens (attendance, directory).
///
/// A taller, softly-elevated pill with an accented search icon and a clear
/// (✕) button that appears live while there is text.
///
/// Two modes:
///  * Editable (default) — pass [controller]/[onChanged]/[onClear]/[hasText].
///  * Tap mode — pass [onTap] (and a [hint]); the pill looks identical but is
///    a read-only button that, on tap, opens a picker sheet. Used where the
///    search is a bottom-sheet picker rather than inline filtering.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    required this.hint,
    this.onChanged,
    this.onClear,
    this.hasText = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool hasText;

  /// When set, the field becomes a tappable bar (opens a picker) instead of an
  /// editable text input — same look, no keyboard.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tapMode = onTap != null;

    final pill = Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.search, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: tapMode
                ? Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                : TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
          ),
          // Live clear button — only in editable mode, while there's text.
          if (!tapMode)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: hasText
                  ? IconButton(
                      key: const ValueKey('clear'),
                      onPressed: onClear,
                      splashRadius: 20,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 20),
                    )
                  : const SizedBox(width: 8, key: ValueKey('empty')),
            ),
        ],
      ),
    );

    if (!tapMode) return pill;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}
