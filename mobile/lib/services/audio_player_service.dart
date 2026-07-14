import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'drive_service.dart';

/// Reproductor de audio unico y global para el Repertorio (mismo patron
/// estatico que NotificationService/DatabaseService). Al ser un solo
/// reproductor compartido por toda la app, nunca se superponen dos audios
/// aunque el usuario navegue entre subcarpetas mientras algo esta sonando.
class AudioPlayerService {
  static final AudioPlayer _player = AudioPlayer();

  static String? currentTrackId;
  static String? currentTrackName;

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  static Stream<Duration> get positionStream => _player.positionStream;
  static Duration? get duration => _player.duration;
  static bool get isPlaying => _player.playing;

  /// Reproduce una pista nueva, o si ya es la que esta sonando, alterna
  /// entre pausa/reanudar.
  ///
  /// La URL de Drive (`.../files/ID?alt=media&key=...`) no tiene extension,
  /// y a veces Drive no manda un Content-Type que ExoPlayer reconozca como
  /// audio: streameando esa URL directo, just_audio suele fallar en Android
  /// con "(0) source error" porque no puede elegir el extractor correcto.
  /// Por eso se descarga el archivo a un temporal (mismo mecanismo que ya
  /// funciona para las partituras) con la extension real, y se reproduce
  /// desde ahi.
  static Future<void> playTrack(String id, String name, String extension) async {
    if (currentTrackId == id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    currentTrackId = id;
    currentTrackName = name;
    try {
      final file = await _localFileFor(id, extension);
      await _player.setFilePath(file.path);
      await _player.play();
    } catch (_) {
      currentTrackId = null;
      currentTrackName = null;
      rethrow;
    }
  }

  static Future<File> _localFileFor(String id, String extension) async {
    final file = File('${Directory.systemTemp.path}/coro_audio_$id.$extension');
    if (await file.exists() && await file.length() > 0) return file;
    final bytes = await DriveService.downloadBytes(id);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  static Future<void> seek(Duration position) => _player.seek(position);

  static Future<void> stop() async {
    await _player.stop();
    currentTrackId = null;
    currentTrackName = null;
  }
}
