# Scala Coral 🎵

Gestión integral de un coro universitario: asistencia, ensayos, presentaciones,
repertorio, tesorería y reportes.

## Estructura del repo

| Carpeta | Contenido |
|---|---|
| [`mobile/`](mobile/README.md) | App Flutter (frontend) — Android, iOS y Windows |
| [`backend/`](backend/) | Esquema y migraciones SQL de Supabase (backend) |

La app se conecta directo a [Supabase](https://supabase.com) (Postgres alojado
+ Auth); no hay servidor propio en este repo. Los scripts en `backend/` son
los que hay que correr en el SQL Editor de Supabase para crear/actualizar el
esquema.

Para detalles de la app (features, stack, cómo correrla) ver
[`mobile/README.md`](mobile/README.md).
