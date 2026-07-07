import 'package:flutter/material.dart';

class AnimatedNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavTab> tabs;

  const AnimatedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.tabs = _defaultTabs,
  });

  static const _defaultTabs = [
    NavTab(Icons.calendar_month_outlined, Icons.calendar_month, 'Ensayos'),
    NavTab(Icons.people_outlined, Icons.people, 'Miembros'),
    NavTab(Icons.star_outline, Icons.star, 'Present.'),
    NavTab(Icons.checklist_outlined, Icons.checklist, 'Asist.'),
    NavTab(Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),
    NavTab(Icons.account_balance_outlined, Icons.account_balance, 'Tesoro.'),
    NavTab(Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.97),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 6),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++) Expanded(
                  child: GestureDetector(
                    onTap: () => onDestinationSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            width: selectedIndex == i ? 44 : 36,
                            height: selectedIndex == i ? 44 : 36,
                            decoration: BoxDecoration(
                              color: selectedIndex == i ? theme.colorScheme.primaryContainer : Colors.transparent,
                              borderRadius: BorderRadius.circular(selectedIndex == i ? 12 : 8),
                            ),
                            child: Center(
                              child: Icon(
                                selectedIndex == i ? tabs[i].selectedIcon : tabs[i].icon,
                                color: selectedIndex == i ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                size: selectedIndex == i ? 24 : 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontSize: selectedIndex == i ? 11 : 10,
                              fontWeight: selectedIndex == i ? FontWeight.w600 : FontWeight.normal,
                              color: selectedIndex == i ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            child: Text(tabs[i].label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavTab(this.icon, this.selectedIcon, this.label);
}
