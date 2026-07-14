import 'package:flutter/material.dart';
import '../config/theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
                              color: selectedIndex == i ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(selectedIndex == i ? 14 : 10),
                            ),
                            child: Center(
                              child: Icon(
                                selectedIndex == i ? tabs[i].selectedIcon : tabs[i].icon,
                                color: selectedIndex == i ? activeColor : inactiveColor.withValues(alpha: 0.6),
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
                              color: selectedIndex == i ? activeColor : inactiveColor.withValues(alpha: 0.6),
                            ),
                            child: Text(tabs[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
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