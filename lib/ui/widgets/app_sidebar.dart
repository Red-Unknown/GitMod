import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppSidebarItem {
  const AppSidebarItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.title = 'GitMod 工作台',
  });

  final String title;
  final List<AppSidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: AppSpace.sm),
            child: Row(
              children: [
                const Icon(Icons.sports_esports, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xxs),
              child: _SidebarButton(
                item: items[index],
                selected: index == selectedIndex,
                onPressed: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({required this.item, required this.selected, required this.onPressed});

  final AppSidebarItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(item.icon, size: 18),
      label: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        foregroundColor: selected ? AppColors.textPrimary : AppColors.textSecondary,
        backgroundColor: selected ? AppColors.primary.withValues(alpha: 0.38) : Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
    );
  }
}
