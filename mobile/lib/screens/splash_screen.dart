import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        if (DatabaseService.isLoggedIn) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.85),
              theme.colorScheme.primary.withValues(alpha: 0.7),
              theme.colorScheme.primary.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 10)],
                  ),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10))]),
                    child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Image.asset('assets/icon.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 64, color: Color(0xFF6C3FB5)))),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Scala Coral', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('UNSAAC', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 4)),
                const SizedBox(height: 48),
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
