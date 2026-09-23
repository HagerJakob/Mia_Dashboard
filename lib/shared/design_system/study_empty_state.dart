import 'package:flutter/material.dart';

import 'study_colors.dart';

class StudyEmptyState extends StatelessWidget {
  const StudyEmptyState({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: StudyColors.subtleInk),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: StudyColors.mutedInk),
            ),
          ),
        ],
      ),
    );
  }
}
