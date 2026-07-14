import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../services/notification_service.dart';
import '../widgets/animated_nav_bar.dart';
import 'dashboard_screen.dart';
import 'rehearsals_screen.dart';
import 'attendance_matrix_screen.dart';
import 'profile_screen.dart';

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
    NotificationService.rescheduleAll();
    _screens = <Widget>[
      const DashboardScreen(),
      const RehearsalsScreen(),
      const AttendanceMatrixScreen(),
      const ProfileScreen(),
    ];

    _tabs = const <NavTab>[
      NavTab(Icons.home_outlined, Icons.home, 'Inicio'),
      NavTab(Icons.calendar_month_outlined, Icons.calendar_month, 'Ensayos'),
      NavTab(Icons.checklist_outlined, Icons.checklist, 'Asist.'),
      NavTab(Icons.person_outline, Icons.person, 'Perfil'),
    ];
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
