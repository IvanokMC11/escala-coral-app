import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_player_service.dart';

/// Barra de reproduccion persistente (nombre de la pista, progreso,
/// play/pausa). Se usa como `bottomNavigationBar` tanto en RepertoireScreen
/// como en SongDetailScreen para que el audio siga sonando y controlable
/// sin importar en cual de las dos pantallas este el usuario.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // El chequeo de "hay pista actual" va DENTRO del builder (no antes) para
    // que la barra aparezca/desaparezca sola apenas se empieza a reproducir
    // algo, sin depender de que la pantalla contenedora haga su propio
    // setState.
    return StreamBuilder<PlayerState>(
      stream: AudioPlayerService.playerStateStream,
      builder: (context, snapshot) {
        if (AudioPlayerService.currentTrackId == null) {
          // No se puede devolver SizedBox.shrink(): al ser bottomNavigationBar,
          // Scaffold le quita el padding inferior de seguridad al body dando
          // por hecho que este widget ya cubre esa franja. Si medimos 0, el
          // contenido del body (ej. los botones "Escuchar" de SongDetailScreen)
          // queda tapado por los botones de navegacion del sistema (atras/
          // inicio/recientes). Reservamos esa altura igual, sin mostrar nada.
          return SizedBox(height: MediaQuery.paddingOf(context).bottom);
        }
        final playing = snapshot.data?.playing ?? false;
        return SafeArea(
          top: false,
          child: Material(
            elevation: 8,
            color: theme.colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                  stream: AudioPlayerService.positionStream,
                  builder: (context, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = AudioPlayerService.duration ?? Duration.zero;
                    final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                    final valueMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                      child: Slider(
                        value: valueMs,
                        max: maxMs,
                        onChanged: (v) => AudioPlayerService.seek(Duration(milliseconds: v.toInt())),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    Icon(Icons.music_note, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(AudioPlayerService.currentTrackName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    IconButton(
                      icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36, color: theme.colorScheme.primary),
                      onPressed: AudioPlayerService.togglePlayPause,
                    ),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
