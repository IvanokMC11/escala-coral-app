# Scala Coral 🎵

Aplicación móvil para la gestión integral de un coro universitario. Desarrollada en **Flutter** con backend en **Supabase**.

## Características

- **Gestión de Miembros** — CRUD completo con codificación y roles
- **Autenticación** — Login por email/contraseña, 3 roles: admin, director, vocal
- **Calendario** — Visualización de eventos con Syncfusion Calendar
- **Finanzas** — Control de aportes y balance general
- **Asistencia** — Registro de asistencia por evento
- **Repertorio** — Catálogo de canciones con acordes y enlaces
- **Tema oscuro** — Paleta rojo (#D32F2F), negro y gris, Material 3

## Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Frontend | Flutter 3.x, Dart |
| Base de datos | Supabase (PostgreSQL) |
| Autenticación | Supabase Auth + tabla `users` con SHA256 |
| Calendario | Syncfusion Calendar + Datepicker |
| Hash | `package:crypto` (SHA256) |

## Estructura del Proyecto

```
mobile/
├── lib/
│   ├── main.dart                  # Entry point, inicialización Supabase
│   ├── config/
│   │   └── theme.dart             # Tema Material 3 rojo/negro
│   ├── services/
│   │   └── database_service.dart  # Todas las consultas a Supabase
│   ├── screens/
│   │   ├── splash_screen.dart     # Splash con logo
│   │   ├── login_screen.dart      # Login con email y contraseña
│   │   ├── home_screen.dart       # Pantalla principal con tabs
│   │   ├── members_screen.dart    # Lista y CRUD de miembros
│   │   ├── calendar_screen.dart   # Calendario de eventos
│   │   ├── finances_screen.dart   # Finanzas y aportes
│   │   └── repertorio_screen.dart # Canciones del repertorio
│   └── widgets/
│       └── animated_nav_bar.dart  # Barra de navegación animada
├── supabase_migration.sql         # Esquema completo de BD
└── pubspec.yaml
```

## Base de Datos

8 tablas principales con índices y 8 funciones PostgreSQL (`SECURITY DEFINER`). RLS habilitado con políticas permisivas para anon key.

## Estado Actual

- ✅ SQL migration ejecutado en Supabase
- ✅ Tema visual rediseñado
- ✅ APK compila
- ✅ App conectada directo a Supabase (sin proxy intermedio)