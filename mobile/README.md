# Scala Coral — App de Gestión de Asistencia Coral

Aplicación móvil Flutter para la gestión de asistencia del coro **Scala Coral Universitaria** de la **UNSAAC** (Universidad Nacional de San Antonio Abad del Cusco). Reemplaza un sistema anterior con backend en Cloudflare Workers + API REST por una solución completamente local con SQLite.

---

## Stack tecnológico

| Tecnología | Versión | Propósito |
|-----------|---------|-----------|
| **Flutter** | 3.33+ | Framework cross-platform (Android + Windows) |
| **Dart** | 3.6+ | Lenguaje de programación |
| **sqflite** | 2.4.2 | Base de datos SQLite local en Android |
| **sqflite_common_ffi** | 2.3.4 | SQLite para desktop (Windows/Linux/Mac) |
| **syncfusion_flutter_calendar** | 29.2.5 | Calendario mensual interactivo |
| **flutter_animate** / **animations** | 2.2.0 | Transiciones animadas entre pantallas |
| **fl_chart** | 1.2.0 | Gráfico de barras para Top 10 |
| **pdf** | 3.13.0 | Generación de PDF para Beca Comedor |
| **printing** | 5.15.0 | Compartir PDF por sistema |
| **intl** | 0.20.2 | Formateo de fechas en español |
| **flutter_localizations** | SDK | Traducción de componentes Material (DatePicker) |
| **provider** | 6.1.5+1 | Inyección de dependencias (no usado activamente) |

### Dependencias de desarrollo
| Paquete | Propósito |
|---------|-----------|
| flutter_launcher_icons | Generación de iconos de app |

---

## Estructura del proyecto

```
mobile/lib/
├── main.dart                          # Entry point, MaterialApp, localizacion
├── config/
│   └── theme.dart                     # Temas claro/oscuro (Material 3)
├── screens/
│   ├── home_screen.dart               # Navegacion principal con 7 tabs
│   ├── splash_screen.dart             # Pantalla de carga con logo animado
│   ├── rehearsals_screen.dart         # CRUD de ensayos
│   ├── attendance_screen.dart         # Marcado de asistencia por ensayo
│   ├── members_screen.dart            # CRUD de miembros del coro
│   ├── presentations_screen.dart      # Presentaciones + calendario Syncfusion
│   ├── attendance_matrix_screen.dart  # Matriz completa miembros×fechas
│   ├── reports_screen.dart            # Top 10 ranking + grafico + PDF beca
│   ├── treasury_screen.dart           # Tesoreria: deudas, cobros, gastos
│   └── settings_screen.dart           # Configuracion general
├── services/
│   ├── database_service.dart          # Toda la logica SQLite (7 tablas, 660+ lineas)
│   └── pdf_service.dart               # Generacion de PDF Beca Comedor con firma
└── widgets/
    └── animated_nav_bar.dart          # Barra de navegacion inferior animada (7 tabs)
```

---

## Base de datos — SQLite (esquema v7)

Archivo: `escala_coral.db` en el directorio de datos de la app.

### Tabla: `members` (v1 → v3 → v4 → v5)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| name | TEXT NOT NULL | Nombre completo |
| email | TEXT nullable | Email |
| phone | TEXT nullable | Teléfono |
| codigo | TEXT nullable (v3) | Código universitario |
| escuela | TEXT nullable (v3) | Escuela profesional |
| is_active | INTEGER DEFAULT 1 | Miembro activo/inactivo |
| beca_eligible | INTEGER DEFAULT 1 (v4) | Apto para Beca Comedor |
| cuerda | TEXT nullable (v5) | SOPRANO/ALTO/TENOR/BAJO |
| created_at | TEXT DEFAULT now | Fecha de registro |

**Seed**: 20 miembros pre-cargados con datos reales del coro.

### Tabla: `rehearsals` (v1 → v2)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| date | TEXT NOT NULL UNIQUE | Fecha del ensayo (YYYY-MM-DD) |
| start_time | TEXT NOT NULL | Hora de inicio (HH:MM) |
| end_time | TEXT NOT NULL | Hora de fin (HH:MM) |
| description | TEXT nullable | Descripción opcional |
| is_canceled | INTEGER DEFAULT 0 (v2) | 1 si el ensayo fue cancelado |
| created_at | TEXT DEFAULT now | Fecha de registro |

**Generación automática**: Al iniciar la app se crean ensayos para los próximos 60 días solo en **lunes, miércoles y viernes** de 18:00 a 20:00.

### Tabla: `attendance` (v1 → v7)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| member_id | INTEGER FK → members | Miembro |
| rehearsal_id | INTEGER FK → rehearsals | Ensayo |
| arrival_time | TEXT NOT NULL | Hora de llegada |
| status | TEXT CHECK | `present`, `late`, `absent` |
| late_minutes | INTEGER DEFAULT 0 | Minutos de tardanza |
| fine_amount | REAL DEFAULT 0 | Multa calculada |
| collected | INTEGER DEFAULT 0 (v7) | 1 si la multa fue cobrada |
| notes | TEXT nullable | Notas (ej: "Falta justificada") |
| created_at | TEXT DEFAULT now | Fecha de registro |

**UNIQUE**(member_id, rehearsal_id) — un registro por miembro por ensayo.

**Cálculo de multa** (método `_calc`):
- Si llega antes o en hora → `present`, multa 0
- Si llega dentro del período de gracia → `present`, multa 0 (registra minutos)
- Si llega después del período de gracia → `late`, multa = (minutos - gracia) × tarifa

### Tabla: `presentations` (v2)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| date | TEXT NOT NULL | Fecha |
| time | TEXT NOT NULL | Hora |
| location | TEXT nullable | Lugar |
| repertoire | TEXT nullable | Repertorio |
| is_closed | INTEGER DEFAULT 0 | 1 = cerrada (asistencia bloqueada) |
| created_at | TEXT DEFAULT now | Fecha de registro |

**Auto-cierre**: Las presentaciones pasadas se cierran automáticamente al iniciar la app (`autoClosePresentations`).

### Tabla: `presentation_attendance` (v2)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| member_id | INTEGER FK → members | Miembro |
| presentation_id | INTEGER FK → presentations | Presentación |
| status | TEXT CHECK | `present` / `absent` |
| created_at | TEXT DEFAULT now | Fecha de registro |

**UNIQUE**(member_id, presentation_id).

### Tabla: `settings` (v1)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| key | TEXT PK | Clave de configuración |
| value | TEXT NOT NULL | Valor |

| Clave | Default | Descripción |
|-------|---------|-------------|
| grace_period_minutes | 15 | Minutos de tolerancia |
| fine_per_minute | 0.20 | Multa por minuto extra |
| fine_currency | S/ | Símbolo monetario |
| schedule_monday_start | 18:00 | Horario lunes inicio |
| schedule_monday_end | 20:00 | Horario lunes fin |
| schedule_wednesday_start | 18:00 | Horario miércoles inicio |
| schedule_wednesday_end | 20:00 | Horario miércoles fin |
| schedule_friday_start | 18:00 | Horario viernes inicio |
| schedule_friday_end | 20:00 | Horario viernes fin |
| presentation_weight | 5 | Valor en asistencias de cada presentación |

### Tabla: `member_fines` (v6)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| member_id | INTEGER FK → members | Miembro multado |
| amount | REAL NOT NULL | Monto de la multa |
| reason | TEXT NOT NULL | Motivo |
| created_at | TEXT DEFAULT now | Fecha |
| paid | INTEGER DEFAULT 0 | Pagado (0/1) |
| paid_at | TEXT nullable | Fecha de pago |

### Tabla: `treasury` (v6)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | INTEGER PK AUTO | ID único |
| type | TEXT CHECK | `income` / `expense` |
| concept | TEXT NOT NULL | Concepto del movimiento |
| amount | REAL NOT NULL | Monto |
| description | TEXT nullable | Descripción adicional |
| member_id | INTEGER FK → members nullable | Miembro asociado (opcional) |
| created_at | TEXT DEFAULT now | Fecha |

### Migraciones

| Desde | A | Cambios |
|-------|---|---------|
| v1 | v2 | `is_canceled` en rehearsals, tablas presentations + presentation_attendance + setting presentation_weight |
| v2 | v3 | Columnas `codigo` y `escuela` en members |
| v3 | v4 | Columna `beca_eligible` en members |
| v4 | v5 | Columna `cuerda` en members |
| v5 | v6 | Tablas `member_fines` y `treasury` |
| v6 | v7 | Columna `collected` en attendance |

---

## Pantallas — Funcionamiento detallado

### 1. SplashScreen
- Logo del coro con animación fade-in + scale (elasticOut)
- Gradiente morado oscuro con glow alrededor del logo
- After 2.5s → transición fade hacia HomeScreen
- Animación controlada por `AnimationController` (1500ms)

### 2. HomeScreen
- `PageTransitionSwitcher` con `FadeThroughTransition` del paquete `animations`
- `IndexedStack` interno para mantener estado de cada tab
- 7 tabs en la barra inferior `AnimatedNavBar`
- Transición suave con `SharedAxisPageTransitionsBuilder` (tipo scaled)

### 3. AnimatedNavBar
- 7 íconos con labels cortos: Ensayos, Miembros, Present., Asist., Reportes, Tesoro., Ajustes
- Contenedor animado redondeado en el ítem seleccionado (primaryContainer)
- `SafeArea` + padding superior para evitar solapamiento con botones de navegación de Android
- Curva `elasticOut` en la animación de selección

### 4. RehearsalsScreen (Ensayos)
- Muestra mes actual con nombre
- Lista de ensayos con: número de día en gradiente, nombre del día, fecha formateada, horario
- Badges: "NO HUBO" (cancelado), "PASADO" (fecha anterior)
- `OpenContainer` (animations) al tocar → transición morph hacia AttendanceScreen
- PopupMenu: Cancelar/Marcar realizado, Tomar asistencia, Eliminar (con confirmación)
- Botón "+" flotante para crear nuevo ensayo:
  - DatePicker en español (con `showDatePicker`)
  - Campos: fecha (selector visual), inicio, fin, descripción
- Pull-to-refresh
- Auto-generación de ensayos al iniciar (60 días, lun/mie/vie)

### 5. AttendanceScreen (Marcado de asistencia)
- Header con gradiente: fecha, horario, badge "ENSAYO" / "FUERA DE HORARIO"
- **Marcación**: cada miembro no marcado muestra:
  - Avatar con iniciales
  - Botón "FJ" (Falta Justificada) naranja → diálogo de confirmación
  - Botón "Marcar" → marca con hora actual
  - Fuera de horario: ambos botones preguntan "¿Seguro?" antes de proceder
- **Cálculo automático**: al marcar, compara hora de llegada vs inicio del ensayo:
  - A tiempo → status `present`
  - Dentro de tolerancia → status `present` (sin multa)
  - Fuera de tolerancia → status `late`, multa = (minutos - gracia) × S/0.20
- **FJ**: guarda como `present` con `arrival_time = 'FJ'` y `notes = 'Falta justificada'`, cuenta como asistencia
- Sección "Asistencia registrada": lista con iconos (✅ A tiempo, ⚠️ Tarde Xmin - S/Y, ❤️ FJ, ❌ Ausente)
- Sección "Resumen mensual": tabla por miembro con % asistencia, tardanzas, multas
- Pull-to-refresh

### 6. MembersScreen (Miembros)
- Barra de búsqueda con filtrado en tiempo real
- Lista de miembros con:
  - Avatar con iniciales
  - Nombre, badges: "No beca" (naranja), cuerda (morado)
  - Subtítulo: código · escuela · email
- **Al tocar**: `showModalBottomSheet` con drag handle
  - Formulario completo: nombre, email, teléfono, código, escuela, cuerda (dropdown), apto beca (checkbox)
  - Adaptado al teclado con `viewInsets.bottom`
  - Validación de campos requeridos
- Botón "+" en AppBar para nuevo miembro
- Deslizar a la izquierda para eliminar (Dismissible) — *nota: eliminado en versión reciente*

### 7. PresentationsScreen (Presentaciones)
- **Calendario Syncfusion** (`SfCalendar`, vista mensual) en la parte superior
  - Días con presentaciones marcados con punto de color
  - Al tocar una fecha → se filtra la lista debajo
  - Estilo oscuro consistente con el tema
- **Lista filtrada**: presenta las presentaciones del día seleccionado
  - Hora, lugar, badge "Abierta"/"Cerrada"
  - Al tocar → bottom sheet de asistencia
- **Bottom sheet de asistencia**:
  - Marcar todos presente (botón)
  - Lista de miembros con toggle presente/ausente (iconos circulares)
  - Botón "Cerrar" (si es fecha pasada) → bloquea ediciones
  - Guardar persistencia
- **Crear presentación**: bottom sheet con DatePicker visual + hora + lugar + repertorio
- Auto-cierre de presentaciones pasadas al ingresar

### 8. AttendanceMatrixScreen (Asistencia General)
- Selector de mes con flechas + texto táctil que abre DatePicker
- Tabla `DataTable`:
  - **Filas**: todos los miembros activos
  - **Columnas**: cada fecha de ensayo del mes (día + inicial del día)
  - **Celdas**: iconos de estado (✅ presente, ⚠️ tarde, ❤️ FJ, ❌ ausente, `-` sin marcar)
  - Últimas columnas: **% asistencia**, **T (tardanzas)**, **Multa (S/)** por miembro
- Scroll horizontal + vertical (anidado)
- Resumen visual: colores según rango de asistencia (verde ≥90%, naranja ≥70%, rojo <70%)

### 9. ReportsScreen (Reportes)
- Selector de mes con flechas + táctil para DatePicker
- **Top 10 ranking**: bar chart (fl_chart) con las 5 mejores asistencias + tabla completa
  - Columnas: # (medallas para top 3), Nombre, %, Tardanzas, Multa
  - Cálculo: combina asistencias a ensayos + presentaciones ponderadas (peso configurable)
  - Ejemplo: si peso=5, una presentación cuenta como 5 asistencias
- **Detalle de miembros**: tabla completa con % asistencia, tardanzas, multa de cada miembro
- **Botón "Beca Comedor"**: genera PDF con:
  - Datos generales (fecha, grupo, mes)
  - Carta de presentación firmada por la presidente
  - Tabla de estudiantes beneficiarios (solo aptos: `beca_eligible = 1`)
  - Firma escaneada (`firma_jaide_ramirez.png`)
  - Compartir vía sistema (`Printing.sharePdf`)

### 10. TreasuryScreen (Tesorería)
- Selector de mes con flechas
- **Tres tarjetas de resumen**: Ingresos (🟢), Gastos (🔴), Balance (🟢/🔴)
- **Deudas de miembros**:
  - Buscador por nombre en tiempo real
  - Lista de deudores ordenada por monto descendente
  - Cada item: nombre + total deuda (rojo)
  - Deuda = multas de tardanza no cobradas (attendance.collected=0) + multas manuales no pagadas (member_fines.paid=0)
  - Botón "Cobrar": transacción SQL → marca attendance.collected=1, member_fines.paid=1, registra ingreso en treasury
  - Sin estado intermedio ni doble cobro (todo en una transacción)
- **Movimientos del mes**: listado de ingresos/gastos con iconos verdes/rojos
- **AppBar**: botón 💰 (Multa manual → selecciona miembro, monto, motivo) + menú (Fondo externo / Gasto)

### 11. SettingsScreen (Ajustes)
- **Reglas de tardanza**: minutos de tolerancia, multa por minuto
- **Presentaciones**: valor en asistencias (peso)
- **Horarios**: lunes, miércoles, viernes (inicio/fin)
- Cada ítem es una tarjeta con icono, label y valor; al tocar → diálogo de edición
- Footer: logo, "Scala Coral", "UNSAAC", versión, crédito "Creado por Konavi, el mejor tenor xd"

---

## Diagrama de flujo de datos

```
Usuario
  │
  ├── Ensayos
  │     ├── Crear (DatePicker + horario)
  │     ├── Cancelar (is_canceled=1)
  │     ├── Eliminar (cascade attendance)
  │     └── Tomar asistencia
  │           ├── Marcar (hora automática)
  │           │     └── _calc() → status + fine_amount
  │           ├── FJ (presente condicional)
  │           └── Fuera de horario (confirmación)
  │
  ├── Miembros
  │     ├── CRUD completo
  │     ├── Búsqueda
  │     └── Datos: código, escuela, cuerda, beca_eligible
  │
  ├── Presentaciones
  │     ├── Calendario mensual (Syncfusion)
  │     ├── Asistencia por miembro
  │     ├── Cerrar automático/manual
  │     └── Ponderación en ranking
  │
  ├── Asistencia General
  │     └── Matriz miembros × fechas con iconos
  │
  ├── Reportes
  │     ├── Top 10 (ensayos + presentaciones)
  │     └── PDF Beca Comedor (con firma)
  │
  ├── Tesorería
  │     ├── Deudas (tardanza + multas manuales)
  │     ├── Cobrar (transacción atómica)
  │     ├── Multas manuales
  │     ├── Gastos
  │     ├── Fondos externos
  │     └── Búsqueda de deudores
  │
  └── Ajustes
        └── Configuración de reglas y horarios
```

---

## Puntos clave de arquitectura

### Offline-first
- 100% local, sin conexión a internet
- Datos persistidos en SQLite
- No hay backend, API ni sincronización

### State management
- `setState` en cada pantalla (sin Provider/Bloc/Riverpod)
- Cada pantalla maneja su propio estado y carga inicial en `initState`
- Los datos se recargan después de cada operación CRUD

### Manejo de fechas
- Todas las fechas se almacenan como TEXT en formato `YYYY-MM-DD`
- Formateo en español con `intl` + `DateFormat`
- DatePicker en español gracias a `flutter_localizations`
- `initializeDateFormatting('es')` para locale español

### Temas
- Material 3 (predeterminado: oscuro)
- Color semilla: `#7C4DFF` (morado vibrante)
- Tema claro y oscuro extraídos en `config/theme.dart`
- Cards con `borderRadius: 16`, `elevation: 0`
- Inputs con `borderRadius: 14`, fondo relleno

### Animaciones
- `SharedAxisPageTransitionsBuilder` (tipo scaled) para navegación entre pantallas
- `PageTransitionSwitcher` + `FadeThroughTransition` para tabs
- `OpenContainer` para morph animation de tarjeta a pantalla de asistencia
- Animación personalizada en splash (fade + scale elasticOut)
- Nav bar con contenedor animado redondeado

---

## Posibles mejoras (para el especialista)

### Arquitectura
- Migrar a **Riverpod** o **Bloc** para state management escalable
- Separar `DatabaseService` en repositorios por dominio (MemberRepository, RehearsalRepository, etc.)
- Implementar **DAO pattern** con modelos tipados en lugar de `Map<String, dynamic>`
- Agregar **capa de servicios** entre UI y base de datos

### Base de datos
- Usar **drift** (antes Moor) para tipo-seguridad en queries SQL
- Agregar **índices compuestos** para queries frecuentes (member_id + fecha)
- Implementar **migraciones** con drift en lugar de SQL manual
- Considerar **SQLite encryption** para datos sensibles

### UI/UX
- Implementar **tema dinámico** (Material You) en Android
- Agregar **modo claro** configurable por usuario
- Mejorar **accesibilidad**: tamaños de fuente dinámicos, contraste
- Agregar **notificaciones locales** para recordatorio de ensayos
- Soporte para **tablet** con diseño adaptativo (Master-detail)

### Testing
- Tests unitarios para `_calc` (cálculo de multas)
- Tests de widget para cada pantalla
- Tests de integración para flujo completo (crear ensayo → marcar asistencia → ver reporte)

### Performance
- **Lazy loading** para la matriz de asistencia (virtual scrolling)
- **Cache** de consultas frecuentes (miembros, settings)
- **Background processing** para auto-generación de ensayos
- Optimizar queries con `EXPLAIN QUERY PLAN`

### Features faltantes
- **Sincronización cloud** (Firebase/Supabase) para respaldo y multi-dispositivo
- **Roles de usuario** (admin, tesorero, director)
- **Exportación a Excel/CSV** de todos los reportes
- **Gráficos** más detallados (asistencia por miembro a lo largo del tiempo)
- **Cobro parcial** de deudas (no solo total)
- **Historial de pagos** por miembro
- **Reporte anual** con estadísticas consolidadas
- **QR/NFC** para marcado rápido de asistencia
- **Firma digital** en PDF (no solo imagen escaneada)

### Seguridad
- Agregar **autenticación biométrica** (huella/rostro) para abrir la app
- **Ofuscación** del código Dart en release
- Proteger contra **SQL injection** (ya se usan parametrized queries, verificar)

---

## Compilación y despliegue

```bash
# Android Debug
cd mobile
flutter build apk --debug

# Android Release
flutter build apk --release

# Windows (requiere Developer Mode)
flutter run -d windows
```
