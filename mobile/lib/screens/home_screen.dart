import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../services/database_service.dart';
import '../widgets/animated_nav_bar.dart';
import 'members_screen.dart';
import 'rehearsals_screen.dart';
import 'presentations_screen.dart';
import 'attendance_matrix_screen.dart';
import 'reports_screen.dart';
import 'treasury_screen.dart';
import 'settings_screen.dart';
import 'my_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  late final List<Widget> _screens;
  late final List<NavTab> _tabs;

  @override
  void initState() {
    super.initState();
    final isStaff = DatabaseService.isStaff;

    final allScreens = <Widget>[
      const RehearsalsScreen(),
      const MembersScreen(),
      const PresentationsScreen(),
      const AttendanceMatrixScreen(),
      const ReportsScreen(),
      if (isStaff) const TreasuryScreen(),
      const MyAttendanceScreen(),
      const SettingsScreen(),
    ];

    final allTabs = <NavTab>[
      const NavTab(Icons.calendar_month_outlined, Icons.calendar_month, 'Ensayos'),
      const NavTab(Icons.people_outlined, Icons.people, 'Miembros'),
      const NavTab(Icons.star_outline, Icons.star, 'Present.'),
      const NavTab(Icons.checklist_outlined, Icons.checklist, 'Asist.'),
      const NavTab(Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),
      if (isStaff) const NavTab(Icons.account_balance_outlined, Icons.account_balance, 'Tesoro.'),
      const NavTab(Icons.person_outline, Icons.person, 'Mi'),
      const NavTab(Icons.settings_outlined, Icons.settings, 'Ajustes'),
    ];

    _screens = allScreens;
    _tabs = allTabs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: AnimatedNavBar(
        selectedIndex: _index,
        tabs: _tabs,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
