import 'package:flutter/material.dart';

class AnimatedNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AnimatedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<AnimatedNavBar> createState() => _AnimatedNavBarState();
}

class _AnimatedNavBarState extends State<AnimatedNavBar> {
  static const _tabs = [
    _NavTab(Icons.calendar_month_outlined, Icons.calendar_month, 'Ensayos'),
    _NavTab(Icons.people_outlined, Icons.people, 'Miembros'),
    _NavTab(Icons.star_outline, Icons.star, 'Present.'),
    _NavTab(Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),
    _NavTab(Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          for (int i = 0; i < _tabs.length; i++) _NavBarItem(
            index: i,
            tab: _tabs[i],
            isSelected: widget.selectedIndex == i,
            onTap: () => widget.onDestinationSelected(i),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavTab(this.icon, this.selectedIcon, this.label);
}

class _NavBarItem extends StatelessWidget {
  final int index;
  final _NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _NavBarItem({
    required this.index,
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(top: isSelected ? 0 : 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? tab.selectedIcon : tab.icon,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      child: Text(tab.label),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: -2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      width: isSelected ? 36 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
