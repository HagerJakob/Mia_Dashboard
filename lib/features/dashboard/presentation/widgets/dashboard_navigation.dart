import 'package:flutter/material.dart';

import '../../../../shared/models/navigation_item.dart';
import '../../../../shared/design_system/study_assets.dart';
import '../../../../shared/design_system/study_radius.dart';
import '../../../../shared/design_system/study_svg_asset.dart';
import '../../../../theme/app_colors.dart';

class StudySidebar extends StatelessWidget {
  const StudySidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
    super.key,
  });

  final List<StudyNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: StudyRadius.large,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Logo(),
          const SizedBox(height: 22),
          for (var index = 0; index < items.length; index++)
            _SidebarTile(
              item: items[index],
              selected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
          const Spacer(),
          _SidebarTile(
            item: StudyNavigationItem(
              label: 'Einstellungen',
              icon: Icons.settings_rounded,
            ),
            onTap: onSettings,
          ),
          const SizedBox(height: 10),
          const _SyncPill(),
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
    required this.onSettings,
    super.key,
  });

  final List<StudyNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      minWidth: 82,
      selectedIndex: selectedIndex.clamp(0, items.length - 1),
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      scrollable: true,
      leading: const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 18),
        child: _LogoMark(size: 46),
      ),
      trailing: IconButton(
        tooltip: 'Konto & Synchronisierung',
        onPressed: onSettings,
        icon: const Icon(Icons.settings_rounded),
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
            borderRadius: StudyRadius.medium,
          ),
          clipBehavior: Clip.antiAlias,
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: StudySvgAsset(
              asset: StudyAssets.appIcon,
              semanticLabel: 'StudyBuddy Logo',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'StudyBuddy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: StudyRadius.medium,
      ),
      clipBehavior: Clip.antiAlias,
      child: const Padding(
        padding: EdgeInsets.all(5),
        child: StudySvgAsset(
          asset: StudyAssets.appIcon,
          semanticLabel: 'StudyBuddy Logo',
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.blush : AppColors.surface,
        borderRadius: StudyRadius.medium,
        child: ListTile(
          hoverColor: AppColors.blush.withValues(alpha: .45),
          dense: true,
          minLeadingWidth: 22,
          visualDensity: VisualDensity.compact,
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
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: .55),
        borderRadius: StudyRadius.medium,
        border: Border.all(color: AppColors.sage.withValues(alpha: .18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_outlined, size: 18, color: AppColors.sage),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lokal bereit',
              style: TextStyle(
                color: AppColors.mutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
