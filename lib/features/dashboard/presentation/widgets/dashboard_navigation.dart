import 'package:flutter/material.dart';

import '../../../../shared/models/navigation_item.dart';
import '../../../../theme/app_colors.dart';

class StudySidebar extends StatelessWidget {
  const StudySidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<StudyNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Logo(),
          const SizedBox(height: 28),
          for (var index = 0; index < items.length; index++)
            _SidebarTile(
              item: items[index],
              selected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
          const Spacer(),
          const _SidebarTile(
            item: StudyNavigationItem(
              label: 'Einstellungen',
              icon: Icons.settings_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class StudyNavigationRail extends StatelessWidget {
  const StudyNavigationRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<StudyNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      minWidth: 82,
      selectedIndex: selectedIndex.clamp(0, items.length - 1),
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 18),
        child: CircleAvatar(
          backgroundColor: AppColors.blush,
          child: Icon(Icons.favorite_rounded, color: AppColors.mauve),
        ),
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            label: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}

class StudyBottomNavigation extends StatelessWidget {
  const StudyBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<StudyNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex.clamp(0, items.length - 1),
      onDestinationSelected: onSelected,
      height: 72,
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.favorite_rounded, color: AppColors.mauve),
        ),
        const SizedBox(width: 12),
        Text('StudyBuddy', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, this.selected = false, this.onTap});

  final StudyNavigationItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.blush : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          item.icon,
          color: selected ? AppColors.mauve : AppColors.mutedInk,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: selected ? AppColors.ink : AppColors.mutedInk,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
