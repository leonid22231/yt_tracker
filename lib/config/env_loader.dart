import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Загрузка `.env` для Flutter/CLI (несколько путей — cwd при `flutter run` разный).
class EnvLoader {
  static final _dotenv = DotEnv(includePlatformEnvironment: true);
  static var _loaded = false;

  static void loadOnce() {
    if (_loaded) return;
    _loaded = true;

    final candidates = <String>{
      '.env',
      '${Directory.current.path}${Platform.pathSeparator}.env',
    };

    // Рядом с pubspec при запуске из build/
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      candidates.add('${dir.path}${Platform.pathSeparator}.env');
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        _dotenv.load([path]);
        return;
      }
    }
  }

  static String? get(String key) {
    loadOnce();
    final v = _dotenv[key] ?? Platform.environment[key];
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }
}
