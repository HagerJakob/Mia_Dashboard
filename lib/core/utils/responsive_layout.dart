import 'package:flutter/widgets.dart';

import '../constants/app_breakpoints.dart';

enum WindowSizeClass { compact, medium, expanded }

extension ResponsiveLayout on BuildContext {
  WindowSizeClass get windowSizeClass {
    final width = MediaQuery.sizeOf(this).width;

    if (width >= AppBreakpoints.desktop) {
      return WindowSizeClass.expanded;
    }
    if (width >= AppBreakpoints.tablet) {
      return WindowSizeClass.medium;
    }
    return WindowSizeClass.compact;
  }

  bool get isCompact => windowSizeClass == WindowSizeClass.compact;
  bool get isMedium => windowSizeClass == WindowSizeClass.medium;
  bool get isExpanded => windowSizeClass == WindowSizeClass.expanded;
}
