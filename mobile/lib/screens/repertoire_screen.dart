import 'package:flutter/material.dart';
import '../services/drive_service.dart';
import '../widgets/audio_mini_player.dart';
import '../widgets/common.dart';
import 'score_viewer_screen.dart';
import 'song_detail_screen.dart';

/// Repertorio del coro: canciones (partitura + audios por cuerda) y
/// ejercicios sueltos, leidos de la carpeta de Google Drive del coro.
class RepertoireScreen extends StatefulWidget {
  const RepertoireScreen({super.key});

  @override
  State<RepertoireScreen> createState() => _RepertoireScreenState();
}

class _RepertoireScreenState extends State<RepertoireScreen> {
  Repertoire? _repertoire;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!DriveService.isConfigured) {
      setState(() { _loading = false; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final rep = await DriveService.getRepertoire();
    setState(() {
      _repertoire = rep;
      _error = DriveService.lastError;
      _loading = false;
    });
  }

  void _openSong(Song song) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SongDetailScreen(song: song)));
  }

  void _openExercise(DriveItem item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreViewerScreen(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repertorio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
      bottomNavigationBar: const AudioMiniPlayer(),
      body: !DriveService.isConfigured
          ? ErrorRetry(
              message: 'El repertorio todavía no está configurado.\nFalta agregar la API key y el ID de la carpeta de Drive en lib/services/drive_service.dart.',
              onRetry: _load,
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _load)
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final songs = _repertoire?.songs ?? [];
    final exercises = _repertoire?.exercises ?? [];

    if (songs.isEmpty && exercises.isEmpty) {
      return const EmptyState(icon: Icons.library_music_outlined, title: 'Carpeta vacía');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (songs.isNotEmpty) ...[
            const SectionHeader(icon: Icons.music_note_outlined, label: 'Canciones'),
            const SizedBox(height: 8),
            ...songs.map((s) => _SongRow(song: s, onTap: () => _openSong(s))),
            const SizedBox(height: 20),
          ],
          if (exercises.isNotEmpty) ...[
            const SectionHeader(icon: Icons.fitness_center_outlined, label: 'Ejercicios', primaryColor: false),
            const SizedBox(height: 8),
            ...exercises.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined, color: theme.colorScheme.onSurfaceVariant),
                    title: Text(e.name, style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openExercise(e),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongRow({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5)),
          child: Icon(Icons.music_note, color: theme.colorScheme.primary),
        ),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          Icon(Icons.picture_as_pdf, size: 14, color: song.hasScore ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(width: 4),
          Icon(Icons.audiotrack, size: 14, color: song.hasAudio ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          if (song.hasAudio) ...[
            const SizedBox(width: 6),
            Flexible(child: Text(song.audios.keys.where((c) => c != 'COMPLETO').join(' · '), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
