import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double defaultRadius = 30.0; // metros

  /// Motivo por el que la ultima llamada a [getCurrentPosition] devolvio
  /// null, para poder mostrarle al usuario un mensaje especifico en vez
  /// de un generico "no se pudo marcar asistencia".
  static String? lastFailureReason;

  /// Verifica permisos y obtiene posición actual. Si la lectura fresca
  /// tarda demasiado o falla, recurre a la ultima ubicacion conocida del
  /// dispositivo (si es reciente) en vez de fallar directamente — el GPS
  /// en frio puede tardar mas de 10s, sobre todo en interiores.
  static Future<Position?> getCurrentPosition() async {
    lastFailureReason = null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      lastFailureReason = 'Activa el GPS de tu celular para marcar asistencia.';
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        lastFailureReason = 'Necesitas dar permiso de ubicación para marcar asistencia.';
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      lastFailureReason = 'El permiso de ubicación está bloqueado. Actívalo desde los ajustes del celular.';
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      // Respaldo: ultima ubicacion conocida, si no es demasiado vieja.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 5) {
          return last;
        }
      } catch (_) {}
      lastFailureReason = 'No se pudo obtener tu ubicación. Intenta de nuevo en un lugar más abierto.';
      return null;
    }
  }

  /// Calcula distancia en metros entre dos puntos (Haversine)
  static double calculateDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Valida si una posición está dentro del radio del ensayo
  static bool isWithinGeofence({
    required Position userPosition,
    required double rehearsalLat,
    required double rehearsalLng,
    double radiusMeters = defaultRadius,
  }) {
    final distance = calculateDistance(
      userPosition.latitude,
      userPosition.longitude,
      rehearsalLat,
      rehearsalLng,
    );
    return distance <= radiusMeters;
  }

  /// Obtiene dirección legible desde coordenadas (reverse geocoding)
  static Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      // Requiere package:geocoding
      // final placemarks = await placemarkFromCoordinates(lat, lng);
      // if (placemarks.isNotEmpty) {
      //   final p = placemarks.first;
      //   return '${p.street}, ${p.subLocality}, ${p.locality}';
      // }
    } catch (_) {}
    return null;
  }
}
