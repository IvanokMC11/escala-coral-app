import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_player_service.dart';
import '../services/drive_service.dart';
import '../widgets/audio_mini_player.dart';
import '../widgets/drive_file_viewer.dart';

/// Partitura de una cancion junto con sus audios por cuerda, para poder
/// ver la partitura mientras se escucha cualquiera de las voces.
class SongDetailScreen extends StatelessWidget {
  final Song song;

  const SongDetailScreen({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Orden fijo (Soprano/Alto/Tenor/Bajo/Completo), solo las que existan.
    final cuerdas = kCuerdas.where((c) => song.audios.containsKey(c)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(song.title, style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
      backgroundColor: Colors.black,
      bottomNavigationBar: const AudioMiniPlayer(),
      body: Column(
        children: [
          Expanded(
            child: song.hasScore
                ? DriveFileViewer(item: song.score!)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.picture_as_pdf_outlined, color: Colors.white38, size: 56),
                        const SizedBox(height: 12),
                        const Text('Sin partitura disponible para esta canción', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                      ]),
                    ),
                  ),
          ),
          if (cuerdas.isNotEmpty)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Escuchar', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cuerdas.map((c) => _CuerdaChip(
                          label: c == 'COMPLETO' ? 'Completo' : c[0] + c.substring(1).toLowerCase(),
                          item: song.audios[c]!,
                          trackName: '${song.title} — ${c == 'COMPLETO' ? 'Completo' : c}',
                        )).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CuerdaChip extends StatelessWidget {
  final String label;
  final DriveItem item;
  final String trackName;

  const _CuerdaChip({required this.label, required this.item, required this.trackName});

  Future<void> _play(BuildContext context) async {
    try {
      await AudioPlayerService.playTrack(item.resolvedId, trackName, DriveService.audioExtension(item));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo reproducir: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<PlayerState>(
      stream: AudioPlayerService.playerStateStream,
      builder: (context, snapshot) {
        final isCurrent = AudioPlayerService.currentTrackId == item.resolvedId;
        final playing = isCurrent && (snapshot.data?.playing ?? false);
        return ActionChip(
          avatar: Icon(playing ? Icons.pause : Icons.play_arrow, size: 18, color: isCurrent ? Colors.white : theme.colorScheme.primary),
          label: Text(label),
          backgroundColor: isCurrent ? theme.colorScheme.primary : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          labelStyle: TextStyle(color: isCurrent ? Colors.white : null, fontWeight: FontWeight.w600),
          onPressed: () => _play(context),
        );
      },
    );
  }
}
