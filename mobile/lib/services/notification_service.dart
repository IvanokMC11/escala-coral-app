import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'database_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _local.initialize(settings);

    // FCM
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle token refresh
    messaging.onTokenRefresh.listen((token) {
      _saveFcmToken(token);
    });

    // Get initial token
    final token = await messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background handler already set in main.dart
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  @pragma('vm:entry-point')
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    _showNotification(
      title: message.notification?.title ?? 'Scala Coral',
      body: message.notification?.body ?? '',
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification when app is in foreground
    await _showNotification(
      title: message.notification?.title ?? 'Scala Coral',
      body: message.notification?.body ?? '',
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  static Future<void> _saveFcmToken(String token) async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId != null) {
        await DatabaseService.updateFcmToken(userId, token);
      }
    } catch (_) {}
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showNotification(title: title, body: body, payload: payload);
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'presentaciones_channel',
      'Presentaciones',
      channelDescription: 'Notificaciones de presentaciones y ensayos',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Programa notificaciones para una presentación en fecha/hora específica.
  static Future<void> scheduleForPresentation({
    required int eventId,
    required String title,
    required String location,
    required DateTime eventDate,
  }) async {
    final now = DateTime.now();
    final offsets = [
      const Duration(minutes: 30),
      const Duration(minutes: 10),
      const Duration(minutes: 5),
    ];
    final messages = [
      '📢 $title comenzará en 30 minutos en $location',
      '⏰ $title comenzará en 10 minutos en $location',
      '🚀 $title — ¡Empezamos!',
    ];

    for (var i = 0; i < offsets.length; i++) {
      final fireTime = eventDate.subtract(offsets[i]);
      if (fireTime.isAfter(now)) {
        await _scheduleLocal(
          id: eventId * 100 + i,
          title: 'Scala Coral',
          body: messages[i],
          scheduledAt: fireTime,
          payload: 'event_$eventId',
        );
      }
    }
  }

  static Future<void> _scheduleLocal({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledAt, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'escalacoral_presentaciones',
      'Presentaciones',
      channelDescription: 'Recordatorios de presentaciones y ensayos',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _local.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancela todas las notificaciones programadas
  static Future<void> cancelAll() async {
    await _local.cancelAll();
  }

  /// Reprograma todas las notificaciones de presentaciones futuras
  static Future<void> rescheduleAll() async {
    await cancelAll();
    final events = await DatabaseService.getFutureEvents();
    for (final event in events) {
      final dateStr = event['date'] as String?;
      final timeStr = event['time'] as String? ?? event['start_time'] as String? ?? '19:00';
      final name = event['repertoire'] as String? ?? event['description'] as String? ?? 'Evento';
      final location = event['location'] as String? ?? '';
      if (dateStr != null) {
        // PostgreSQL TIME devuelve "HH:MM:SS" → tomar solo HH:MM
        final cleanTime = timeStr.split(':').take(2).join(':');
        final dt = DateTime.tryParse('${dateStr}T$cleanTime:00');
        if (dt != null && dt.isAfter(DateTime.now())) {
          final id = event['id'] as int? ?? 0;
          await scheduleForPresentation(
            eventId: id,
            title: name,
            location: location,
            eventDate: dt,
          );
        }
      }
    }
  }

  /// Solicita permiso de notificaciones en Android 13+ (API 33+)
  static Future<void> requestNotificationPermission() async {
    final androidImplementation = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }
}