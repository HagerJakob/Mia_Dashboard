import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_layout.dart';
import '../../../../shared/widgets/study_card.dart';
import '../../../../theme/app_colors.dart';

class EmptyFeatureScreen extends StatelessWidget {
  const EmptyFeatureScreen({
    required this.title,
    required this.message,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.children = const [],
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 18 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          StudyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.blush,
                  child: Icon(icon, color: AppColors.mauve),
                ),
                const SizedBox(height: 18),
                Text(
                  children.isEmpty ? 'Noch leer' : 'Deine Eintraege',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(actionLabel),
                ),
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
