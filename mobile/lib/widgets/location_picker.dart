import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'common.dart';

/// Selector de ubicacion en mapa con vista compacta + mapa a pantalla
/// completa, busqueda de lugares y boton "Mi ubicacion". Reusado al crear
/// un ensayo, al editar la ubicacion de un ensayo puntual, y para la
/// ubicacion por defecto del coro en Ajustes.
class LocationPicker extends StatefulWidget {
  final Position? selectedPosition;
  final ValueChanged<Position> onLocationSelected;
  final VoidCallback onClear;
  final String title;
  final int radiusMeters;

  const LocationPicker({
    super.key,
    required this.selectedPosition,
    required this.onLocationSelected,
    required this.onClear,
    this.title = 'Ubicación del ensayo',
    this.radiusMeters = 30,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late MapController _mapController;
  LatLng _center = const LatLng(-13.5319, -71.9675);
  double? _accuracy;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.selectedPosition != null) {
      _center = LatLng(widget.selectedPosition!.latitude, widget.selectedPosition!.longitude);
      _accuracy = widget.selectedPosition!.accuracy;
    }
  }

  void _showFullscreenMap(BuildContext context) {
    LatLng tempCenter = _center;
    double? tempAccuracy = _accuracy;

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => ModalWidthConstraint(maxWidth: 640, child: Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton.icon(icon: const Icon(Icons.my_location, size: 18), label: const Text('Mi ubicación'), onPressed: () async {
              try {
                final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 15)).timeout(const Duration(seconds: 15));
                tempCenter = LatLng(pos.latitude, pos.longitude);
                tempAccuracy = pos.accuracy;
                _mapController.move(tempCenter, 18);
                setSheetState(() {});
              } catch (_) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No se pudo obtener GPS'))); }
            }),
            TextButton.icon(icon: const Icon(Icons.search, size: 18), label: const Text('Buscar'), onPressed: () => _showSearchDialog(ctx, setSheetState)),
          ])),
          Expanded(child: Stack(children: [
            FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: tempCenter, initialZoom: widget.selectedPosition != null ? 18 : 15, onTap: (_, latlng) { tempCenter = latlng; tempAccuracy = null; setSheetState(() {}); }), children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.escala_coral'),
              if (tempAccuracy != null && tempAccuracy! > 0) CircleLayer(circles: [CircleMarker(point: tempCenter, radius: tempAccuracy!, color: Colors.blue.withValues(alpha: 0.15), borderColor: Colors.blue.withValues(alpha: 0.5), borderStrokeWidth: 1)]),
              CircleLayer(circles: [CircleMarker(point: tempCenter, radius: widget.radiusMeters.toDouble(), color: Colors.green.withValues(alpha: 0.1), borderColor: Colors.green, borderStrokeWidth: 2)]),
              MarkerLayer(markers: [Marker(point: tempCenter, width: 44, height: 44, child: const Icon(Icons.location_on, color: Colors.red, size: 44))]),
            ]),
            const Center(child: IgnorePointer(child: Icon(Icons.my_location, color: Colors.blue, size: 36, shadows: [Shadow(color: Colors.white, blurRadius: 4)]))),
          ])),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))]), child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (tempAccuracy != null) Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.gps_fixed, size: 16, color: tempAccuracy! <= 20 ? Colors.green : Colors.orange), const SizedBox(width: 6), Text('Precisión GPS: ${tempAccuracy!.toStringAsFixed(0)}m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tempAccuracy! <= 20 ? Colors.green : Colors.orange))]),
            if (tempAccuracy != null) const SizedBox(height: 8),
            Text('Lat: ${tempCenter.latitude.toStringAsFixed(6)}  Lng: ${tempCenter.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.check, size: 20), label: const Text('Confirmar ubicación'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () {
              widget.onLocationSelected(Position(latitude: tempCenter.latitude, longitude: tempCenter.longitude, timestamp: DateTime.now(), accuracy: tempAccuracy ?? 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0));
              Navigator.pop(ctx);
            })),
          ])),
        ]),
      ))),
    );
  }

  void _showSearchDialog(BuildContext context, StateSetter setSheetState) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Buscar lugar'), content: ModalWidthConstraint(maxWidth: 420, child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ej: Plaza de Armas, Cusco', prefixIcon: Icon(Icons.search)), autofocus: true, onSubmitted: (q) => _geocodeAndMove(q, ctx, setSheetState))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), FilledButton(onPressed: () => _geocodeAndMove(ctrl.text, ctx, setSheetState), child: const Text('Buscar'))]));
  }

  Future<void> _geocodeAndMove(String query, BuildContext dialogCtx, StateSetter setSheetState) async {
    if (query.trim().isEmpty) return;
    Navigator.pop(dialogCtx);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {'q': query, 'format': 'json', 'limit': '1', 'countrycodes': 'pe'});
      final response = await http.get(uri, headers: {'User-Agent': 'ScalaCoral/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']); final lon = double.parse(data[0]['lon']);
          setSheetState(() => _mapController.move(LatLng(lat, lon), 18));
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selectedPosition != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        if (hasSelection) Chip(label: const Text('GPS activado', style: TextStyle(fontSize: 11)), avatar: const Icon(Icons.gps_fixed, size: 14, color: Colors.green), backgroundColor: Colors.green.withValues(alpha: 0.1), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: widget.onClear),
      ]),
      const SizedBox(height: 4),
      Text(hasSelection ? 'Radio ${widget.radiusMeters}m • Precisión: ${_accuracy?.toStringAsFixed(0) ?? '?'}m' : 'Toca el mapa o usa "Mi ubicación" para activar validación GPS (${widget.radiusMeters}m)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      GestureDetector(onTap: () => _showFullscreenMap(context), behavior: HitTestBehavior.opaque, child: Container(height: 180, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(children: [
        // IgnorePointer: esta es solo una vista previa, no debe capturar
        // gestos de pan/zoom — si lo hiciera, le "roba" el tap al
        // GestureDetector de arriba y "Tocar para editar" deja de
        // responder (el mapa interactivo gana el gesture arena).
        IgnorePointer(
          child: FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: _center, initialZoom: hasSelection ? 17 : 15), children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.escala_coral'),
            if (hasSelection) ...[if (_accuracy != null && _accuracy! > 0) CircleLayer(circles: [CircleMarker(point: _center, radius: _accuracy!, color: Colors.blue.withValues(alpha: 0.15), borderColor: Colors.blue.withValues(alpha: 0.5), borderStrokeWidth: 1)]), CircleLayer(circles: [CircleMarker(point: _center, radius: widget.radiusMeters.toDouble(), color: Colors.green.withValues(alpha: 0.1), borderColor: Colors.green, borderStrokeWidth: 2)]), MarkerLayer(markers: [Marker(point: _center, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))])],
          ]),
        ),
        const Center(child: IgnorePointer(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fullscreen, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black, blurRadius: 4)]), SizedBox(height: 4), Text('Tocar para editar', style: TextStyle(color: Colors.white, fontSize: 11, shadows: [Shadow(color: Colors.black, blurRadius: 4)]))]))),
      ])))),
      if (hasSelection) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Lat: ${widget.selectedPosition!.latitude.toStringAsFixed(6)}  Lng: ${widget.selectedPosition!.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
    ]);
  }
}
