import 'package:flutter/material.dart';

/// Shared adaptive layout values for phone and tablet form factors.
abstract final class AppLayout {
  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 840;
  static const double maxContentWidth = 1180;

  static bool isExpanded(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= expandedBreakpoint && size.height >= compactBreakpoint;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expandedBreakpoint) {
      return const EdgeInsets.fromLTRB(32, 24, 32, 32);
    }
    if (width >= compactBreakpoint) {
      return const EdgeInsets.fromLTRB(24, 20, 24, 28);
    }
    return const EdgeInsets.fromLTRB(16, 16, 16, 24);
  }

  static Widget bounded({required Widget child}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxContentWidth),
      child: child,
    ),
  );
}
