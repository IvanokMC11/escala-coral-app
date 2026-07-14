import 'dart:convert';
import 'package:http/http.dart' as http;

/// Tipo de archivo del repertorio, derivado del mimeType *resuelto* (si es
/// un acceso directo de Drive, el del archivo/carpeta al que apunta).
enum DriveItemKind { folder, audio, pdf, image, other }

/// Las 4 cuerdas del coro (mismo vocabulario que el resto de la app:
/// members_screen.dart, login_screen.dart) mas "COMPLETO" para la mezcla
/// con todas las voces.
const List<String> kCuerdas = ['SOPRANO', 'ALTO', 'TENOR', 'BAJO', 'COMPLETO'];

class DriveItem {
  final String id;
  final String name;
  final String mimeType;
  // Si `id`/`mimeType` son de un acceso directo (shortcut), estos son el
  // archivo/carpeta real al que apunta — todo lo que sea "abrir contenido"
  // (listar, reproducir, descargar) debe usar `resolvedId`, nunca `id`.
  final String resolvedId;
  final String resolvedMimeType;
  final DriveItemKind kind;

  DriveItem({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.resolvedId,
    required this.resolvedMimeType,
  }) : kind = _kindOf(resolvedMimeType);

  static DriveItemKind _kindOf(String mime) {
    if (mime == 'application/vnd.google-apps.folder') return DriveItemKind.folder;
    if (mime.startsWith('audio/')) return DriveItemKind.audio;
    if (mime == 'application/pdf') return DriveItemKind.pdf;
    if (mime.startsWith('image/')) return DriveItemKind.image;
    return DriveItemKind.other;
  }

  factory DriveItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final mimeType = json['mimeType'] as String? ?? '';
    final shortcut = json['shortcutDetails'] as Map<String, dynamic>?;
    final resolvedId = shortcut != null ? (shortcut['targetId'] as String? ?? id) : id;
    final resolvedMimeType = shortcut != null ? (shortcut['targetMimeType'] as String? ?? mimeType) : mimeType;
    return DriveItem(
      id: id,
      name: json['name'] as String,
      mimeType: mimeType,
      resolvedId: resolvedId,
      resolvedMimeType: resolvedMimeType,
    );
  }
}

/// Una cancion del repertorio: su partitura (PDF combinado) y sus audios
/// por cuerda, emparejados por nombre entre las carpetas "Partituras SC" y
/// "Audios SC" aunque no se llamen exactamente igual.
class Song {
  final String title;
  final DriveItem? score;
  final Map<String, DriveItem> audios; // clave: SOPRANO/ALTO/TENOR/BAJO/COMPLETO

  Song({required this.title, this.score, required this.audios});

  bool get hasScore => score != null;
  bool get hasAudio => audios.isNotEmpty;
}

class Repertoire {
  final List<Song> songs;
  final List<DriveItem> exercises;
  Repertoire({required this.songs, required this.exercises});
}

/// Acceso de solo lectura a una carpeta publica de Google Drive (partituras,
/// audios y ejercicios del coro) via la API REST v3, usando una API key en
/// vez de OAuth porque la carpeta es publica ("cualquiera con el enlace").
class DriveService {
  static const String _apiKey = 'AIzaSyDlf0e11MszlAEHp3U_etdZe068572prLM';
  static const String rootFolderId = '1ILKGgsbt6YLbBTWdepmApl4HSAjq5NYP';

  // La API key esta restringida a "Apps de Android" en Google Cloud
  // Console, y esa restriccion NO se valida automaticamente por el
  // sistema operativo: hay que mandar estas dos cabeceras a mano en cada
  // llamada (confirmado probando la API directo: sin ellas devuelve 403
  // API_KEY_ANDROID_APP_BLOCKED). El SHA-1 es el del keystore de debug,
  // que ahora mismo es tambien el que firma el build de release
  // (android/app/build.gradle.kts usa signingConfigs.debug para release).
  // Si en algun momento se crea un keystore de release aparte, hay que
  // agregar su SHA-1 como restriccion adicional en Cloud Console y
  // actualizar (o agregar) el valor aqui.
  static const Map<String, String> _androidHeaders = {
    'X-Android-Package': 'com.escalacoral.escala_coral',
    'X-Android-Cert': '66D3A921320D8EE76086168FF4CD6F5026E49BD0',
  };

  static bool get isConfigured => _apiKey != 'TU_API_KEY_AQUI' && rootFolderId != 'TU_FOLDER_ID_AQUI';

  static String? lastError;

  /// Lista el contenido directo (accesos directos incluidos, resueltos) de
  /// una carpeta de Drive. Las carpetas aparecen primero, luego el resto
  /// ordenado por nombre.
  static Future<List<DriveItem>> listFolder(String folderId) async {
    lastError = null;
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': "'$folderId' in parents and trashed = false",
      'key': _apiKey,
      'fields': 'files(id,name,mimeType,shortcutDetails)',
      'orderBy': 'folder,name',
      'pageSize': '200',
    });
    try {
      final response = await http.get(uri, headers: _androidHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        lastError = 'Error ${response.statusCode} al consultar Drive. Verifica la API key y que la carpeta sea pública.';
        return [];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as List?) ?? [];
      return files.map((f) => DriveItem.fromJson(f as Map<String, dynamic>)).toList();
    } catch (e) {
      lastError = 'No se pudo conectar con Google Drive: $e';
      return [];
    }
  }

  /// URL de descarga/streaming directa de un archivo (usada tanto para
  /// reproducir audio como para cargar partituras). Siempre sobre el id
  /// *resuelto* (nunca el de un acceso directo, que no tiene contenido).
  static String streamUrl(String resolvedFileId) {
    return Uri.https('www.googleapis.com', '/drive/v3/files/$resolvedFileId', {
      'alt': 'media',
      'key': _apiKey,
    }).toString();
  }

  /// Cabeceras que hay que mandar en cualquier request a la API de Drive
  /// (incluido el streaming de audio con just_audio) para que la
  /// restriccion "Apps de Android" de la key no la rechace.
  static Map<String, String> get androidHeaders => _androidHeaders;

  static Future<List<int>> downloadBytes(String resolvedFileId) async {
    final response = await http.get(Uri.parse(streamUrl(resolvedFileId)), headers: _androidHeaders).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('No se pudo descargar el archivo (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  /// Arma el repertorio completo: encuentra las subcarpetas "Partituras",
  /// "Audios" y "Ejercicios" dentro de la carpeta raiz (por nombre, sin
  /// depender de IDs fijos), empareja partituras con sus audios por cuerda,
  /// y devuelve tambien los ejercicios sueltos.
  static Future<Repertoire> getRepertoire() async {
    final root = await listFolder(rootFolderId);
    if (lastError != null) return Repertoire(songs: [], exercises: []);

    DriveItem? findSubfolder(String keyword) {
      for (final item in root) {
        if (item.kind == DriveItemKind.folder && item.name.toLowerCase().contains(keyword)) return item;
      }
      return null;
    }

    final partiturasFolder = findSubfolder('partitura');
    final audiosFolder = findSubfolder('audio');
    final ejerciciosFolder = findSubfolder('ejercicio');

    final scores = partiturasFolder != null ? await listFolder(partiturasFolder.resolvedId) : <DriveItem>[];
    final audioShortcuts = audiosFolder != null ? await listFolder(audiosFolder.resolvedId) : <DriveItem>[];
    final exercises = ejerciciosFolder != null ? await listFolder(ejerciciosFolder.resolvedId) : <DriveItem>[];

    // Cada acceso directo en "Audios SC" normalmente apunta a una carpeta
    // con un archivo por cuerda adentro, pero alguno puede apuntar
    // directo a un solo audio (ej. una mezcla completa sin desglose por
    // cuerda) — se trata como si fuera "COMPLETO".
    final audioGroupsByTitle = <String, Map<String, DriveItem>>{};
    for (final shortcut in audioShortcuts) {
      if (shortcut.kind == DriveItemKind.folder) {
        final files = await listFolder(shortcut.resolvedId);
        final byCuerda = <String, DriveItem>{};
        for (final f in files) {
          if (f.kind != DriveItemKind.audio) continue;
          final upperName = f.name.toUpperCase();
          for (final cuerda in kCuerdas) {
            if (upperName.contains(cuerda)) {
              byCuerda[cuerda] = f;
              break;
            }
          }
          // Si el archivo no menciona ninguna cuerda en el nombre, se
          // asume que es la mezcla completa.
          if (!kCuerdas.any((c) => upperName.contains(c))) byCuerda['COMPLETO'] = f;
        }
        if (byCuerda.isNotEmpty) audioGroupsByTitle[_displayTitle(shortcut.name)] = byCuerda;
      } else if (shortcut.kind == DriveItemKind.audio) {
        audioGroupsByTitle[_displayTitle(shortcut.name)] = {'COMPLETO': shortcut};
      }
    }

    // Emparejar partituras con grupos de audio por titulo parecido: greedy
    // global (se toman primero los pares con mayor coincidencia de
    // palabras) en vez de emparejar en el orden en que Drive devuelve los
    // archivos, para no depender de esa casualidad de orden.
    final candidatePairs = <({DriveItem score, String audioTitle, int similarity})>[];
    for (final score in scores) {
      for (final audioTitle in audioGroupsByTitle.keys) {
        final s = _titleSimilarity(score.name, audioTitle);
        if (s > 0) candidatePairs.add((score: score, audioTitle: audioTitle, similarity: s));
      }
    }
    candidatePairs.sort((a, b) => b.similarity.compareTo(a.similarity));

    final matchedAudioTitleForScore = <String, String>{}; // score.id -> audioTitle
    final usedAudioTitles = <String>{};
    for (final pair in candidatePairs) {
      if (matchedAudioTitleForScore.containsKey(pair.score.id)) continue;
      if (usedAudioTitles.contains(pair.audioTitle)) continue;
      matchedAudioTitleForScore[pair.score.id] = pair.audioTitle;
      usedAudioTitles.add(pair.audioTitle);
    }

    final songs = <Song>[];
    for (final score in scores) {
      final audioTitle = matchedAudioTitleForScore[score.id];
      final audios = audioTitle != null ? audioGroupsByTitle[audioTitle]! : <String, DriveItem>{};
      songs.add(Song(title: _displayTitle(score.name), score: score, audios: audios));
    }
    // Grupos de audio que no tenian ninguna partitura parecida: igual se
    // muestran, solo que sin partitura.
    for (final entry in audioGroupsByTitle.entries) {
      if (usedAudioTitles.contains(entry.key)) continue;
      songs.add(Song(title: entry.key, score: null, audios: entry.value));
    }
    songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Repertoire(songs: songs, exercises: exercises);
  }

  static String _displayTitle(String fileName) {
    return fileName.replaceAll(RegExp(r'\.(pdf|mp3|wav|m4a)$', caseSensitive: false), '').trim();
  }

  /// Extension de archivo para un audio, usada para guardar el temporal que
  /// reproduce AudioPlayerService (necesita una extension real para que
  /// ExoPlayer detecte el formato). Se toma del nombre si lo trae, si no del
  /// mimeType resuelto.
  static String audioExtension(DriveItem item) {
    final match = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(item.name);
    if (match != null) return match.group(1)!.toLowerCase();
    switch (item.resolvedMimeType) {
      case 'audio/wav':
      case 'audio/x-wav':
        return 'wav';
      case 'audio/mp4':
      case 'audio/x-m4a':
        return 'm4a';
      case 'audio/ogg':
        return 'ogg';
      default:
        return 'mp3';
    }
  }

  static const Map<String, String> _accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n', 'ü': 'u',
  };

  static const Set<String> _stopwords = {'de', 'del', 'la', 'el', 'los', 'las', 'y', 'un', 'una', 'al'};

  static Set<String> _significantWords(String name) {
    var s = _displayTitle(name).toLowerCase();
    _accents.forEach((accented, plain) => s = s.replaceAll(accented, plain));
    s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    return s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !_stopwords.contains(w)).toSet();
  }

  /// Numero de palabras significativas en comun entre dos nombres de
  /// archivo/carpeta, ignorando mayusculas, acentos, extension y palabras
  /// vacias (de/del/la/y/...). Mayor numero = mejor coincidencia.
  static int _titleSimilarity(String a, String b) {
    final wordsA = _significantWords(a);
    final wordsB = _significantWords(b);
    return wordsA.intersection(wordsB).length;
  }
}
