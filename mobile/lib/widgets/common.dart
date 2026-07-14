import 'package:flutter/material.dart';

/// Bloque estandar para listas/pantallas vacias: icono en circulo + titulo
/// + subtitulo opcional. Antes copiado con pequenas variaciones en Ensayos,
/// Miembros, Presentaciones, Matriz de asistencia, Tesoreria y Reportes.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.iconSize = 56});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5)),
              child: Icon(icon, size: iconSize, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Icono + texto en negrita para encabezar una seccion dentro de una
/// pantalla (ej. "Deudas de miembros", "Reglas de tardanza").
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primaryColor;

  const SectionHeader({super.key, required this.icon, required this.label, this.primaryColor = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = primaryColor ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

/// Tarjeta compacta de estadistica (icono opcional + valor + etiqueta),
/// usada en Tesoreria y Perfil.
class StatCard extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Color? color;

  const StatCard({super.key, this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: c, size: 22), const SizedBox(height: 6)],
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: icon != null ? 14 : 20, color: c), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: icon != null ? 10 : 11, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Estadistica circular compacta (valor centrado en un circulo de color),
/// usada en Mi asistencia.
class StatCircle extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatCircle({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
          child: Center(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Selector "< Mes Año >" reutilizado en Tesoreria, Reportes y Matriz de
/// asistencia. Si [onLabelTap] se define, el texto se puede tocar (ej. para
/// abrir un selector de fecha), mostrando una flecha desplegable.
class MonthSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onLabelTap;

  const MonthSelector({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.onLabelTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final labelText = Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
    final labelWidget = onLabelTap == null
        ? labelText
        : GestureDetector(
            onTap: onLabelTap,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: labelText),
              const SizedBox(width: 6),
              Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
            ]),
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          Flexible(child: labelWidget),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

/// Bloque de error con boton "Reintentar". Se usa cuando falla una carga de
/// datos en vez de dejar una pantalla vacia indistinguible de "sin datos".
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.errorContainer.withValues(alpha: 0.5)),
            child: Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

/// Numero de columnas para grillas de accesos rapidos segun ancho
/// disponible: telefono angosto, tablet o pantalla ancha/plegable.
int responsiveColumns(double width, {int base = 3, int wide = 4, int extraWide = 5}) {
  if (width >= 900) return extraWide;
  if (width >= 600) return wide;
  return base;
}

/// Restringe el ancho maximo de dialogos/hojas modales en pantallas anchas
/// (tablet) para que no se vean estirados de borde a borde.
class ModalWidthConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ModalWidthConstraint({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
