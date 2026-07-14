import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/drive_service.dart';

/// Contenido de un visor de partitura (PDF con zoom pagina por pagina, o
/// imagen con pinch-zoom), sin Scaffold/AppBar propios para poder
/// incrustarse tanto en una pantalla completa (ScoreViewerScreen) como
/// dentro de SongDetailScreen junto a los controles de audio.
class DriveFileViewer extends StatefulWidget {
  final DriveItem item;

  const DriveFileViewer({super.key, required this.item});

  @override
  State<DriveFileViewer> createState() => _DriveFileViewerState();
}

class _DriveFileViewerState extends State<DriveFileViewer> {
  Uint8List? _bytes;
  String? _error;
  PdfControllerPinch? _pdfController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DriveFileViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.resolvedId != widget.item.resolvedId) _load();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _bytes = null; _error = null; });
    try {
      final bytes = Uint8List.fromList(await DriveService.downloadBytes(widget.item.resolvedId));
      if (!mounted) return;
      if (widget.item.kind == DriveItemKind.pdf) {
        _pdfController = PdfControllerPinch(document: PdfDocument.openData(bytes));
      }
      setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar la partitura: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ]),
        ),
      );
    }
    if (_bytes == null) return const Center(child: CircularProgressIndicator());
    if (widget.item.kind == DriveItemKind.pdf) return PdfViewPinch(controller: _pdfController!);
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Center(child: Image.memory(_bytes!)),
    );
  }
}
