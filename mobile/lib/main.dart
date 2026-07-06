import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const EscalaCoralApp(),
    ),
  );
}

class EscalaCoralApp extends StatelessWidget {
  const EscalaCoralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escala Coral',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3FB5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3FB5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
        builder: (_, state, __) =>
            state.isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
