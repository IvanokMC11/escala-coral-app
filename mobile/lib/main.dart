import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

const _supabaseHost = 'vvhvpgyvglsmeastrsvt.supabase.co';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://$_supabaseHost';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aHZwZ3l2Z2xzbWVhc3Ryc3Z0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MzM0NDgsImV4cCI6MjA5OTAwOTQ0OH0.eiAzDs50FT3rtQh5mIjiHy_u-FC93XCWqazaW6cahKE';

  try {
    await Firebase.initializeApp();
  } catch (_) {}

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
    await DatabaseService.restoreSession();
  } catch (_) {}

  try {
    await NotificationService.init();
  } catch (_) {}

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
      // Limita el escalado de fuente del sistema: si el usuario tiene el
      // tamaño de letra del celular muy grande, el texto ya no rompe los
      // diseños (nombres en vertical, filas encimadas, etc.).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
