import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/theme.dart';
import 'services/database_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.database; // warm up DB so isLoggedIn works on first frame
  await DatabaseService.restoreSession();
  initializeDateFormatting('es', null).then((_) {
    runApp(const EscalaCoralApp());
  });
}

class EscalaCoralApp extends StatelessWidget {
  const EscalaCoralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scala Coral',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      home: const SplashScreen(),
    );
  }
}
