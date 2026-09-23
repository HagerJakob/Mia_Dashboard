import 'package:flutter/material.dart';

import 'study_colors.dart';
import 'study_radius.dart';
import 'study_spacing.dart';

class StudyCard extends StatelessWidget {
  const StudyCard({
    required this.child,
    this.padding = StudySpacing.card,
    this.margin,
    this.backgroundColor = StudyColors.surface,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: StudyRadius.large,
        border: Border.all(color: StudyColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
