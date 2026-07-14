import 'package:flutter/material.dart';
import '../services/drive_service.dart';
import '../widgets/drive_file_viewer.dart';

/// Visor de un archivo suelto (usado para "Ejercicios", que no tienen
/// audio relacionado). Las partituras de canciones con audio se ven en
/// SongDetailScreen, junto a los controles de reproduccion.
class ScoreViewerScreen extends StatelessWidget {
  final DriveItem item;

  const ScoreViewerScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name, style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
      backgroundColor: Colors.black,
      body: DriveFileViewer(item: item),
    );
  }
}
