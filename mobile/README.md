# Scala Coral 🎵

App móvil (Flutter) para la gestión integral de un coro universitario.
Backend en **Supabase** (ver [`../backend/`](../backend/) para el esquema y
las migraciones SQL).

## Características

- **Miembros** — CRUD con código, escuela/carrera y cuerda (soprano/alto/tenor/bajo)
- **Autenticación y roles** — login local con `users` + hash SHA256, roles admin/director/vocal, cada miembro puede vincularse a su cuenta
- **Ensayos** — CRUD de ensayos con ubicación geolocalizada (mapa) y cancelación
- **Asistencia** — registro por ensayo con chequeo de geolocalización (geofence) y multas automáticas, matriz mensual de todos los miembros para administración, e historial propio para cada miembro
- **Presentaciones** — CRUD de presentaciones/actuaciones públicas y su propia asistencia
- **Repertorio** — canciones leídas desde una carpeta de Google Drive: partitura (PDF/imagen con zoom) + audio por cuerda reproducible con reproductor persistente
- **Reportes** — estadísticas mensuales (gráficos) y exportación a PDF ("Beca Comedor", reporte diario de asistencia)
- **Tesorería** — control de aportes y balance
- **Notificaciones** — push (Firebase Cloud Messaging) y recordatorios locales programados de ensayos/presentaciones
- **Tema oscuro** — paleta rojo (#D32F2F) / negro, Material 3

## Stack Tecnológico

| Componente | Tecnología |
|---|---|
| App | Flutter, Dart |
| Base de datos / Auth | Supabase (PostgreSQL) — ver [`../backend/`](../backend/) |
| Archivos del repertorio | Google Drive API v3 (API key) |
| Audio | `just_audio` |
| Visor de partituras | `pdfx` |
| Mapas / geolocalización | `flutter_map` + `geolocator` |
| Notificaciones | `firebase_messaging` (push) + `flutter_local_notifications` (locales) |
| PDFs generados | `pdf` + `printing` |
| Gráficos | `fl_chart` |

## Estructura del proyecto

```
mobile/
├── lib/
│   ├── main.dart                        # Entry point: Firebase, Supabase, notificaciones
│   ├── config/
│   │   ├── theme.dart                   # Tema Material 3 rojo/negro
│   │   └── carreras.dart                # Carreras UNSAAC (registro de miembros)
│   ├── services/
│   │   ├── database_service.dart        # Consultas a Supabase + sesión/auth
│   │   ├── drive_service.dart           # Cliente de Google Drive (repertorio)
│   │   ├── audio_player_service.dart    # Reproductor de audio global (repertorio)
│   │   ├── location_service.dart        # Geolocalización/geofence (asistencia)
│   │   ├── notification_service.dart    # Push (FCM) + notificaciones locales
│   │   └── pdf_service.dart             # Generación de PDFs (reportes)
│   ├── screens/                         # Splash, login, home (tabs), dashboard,
│   │                                     # miembros, ensayos, asistencia (evento/
│   │                                     # matriz/propia), presentaciones,
│   │                                     # repertorio (+ detalle canción, visor),
│   │                                     # reportes, tesorería, ajustes, perfil
│   └── widgets/                         # nav bar animada, mini-player de audio,
│                                         # visor de archivos de Drive, selector
│                                         # de ubicación, componentes comunes
└── pubspec.yaml
```

## Base de datos

El esquema y las migraciones SQL viven en [`../backend/`](../backend/), no en
esta carpeta. Correrlos en Supabase → SQL Editor.
