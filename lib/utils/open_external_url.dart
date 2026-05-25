import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Открывает URL в браузере. На Windows — через `cmd start` (без pigeon url_launcher).
Future<bool> openExternalUrl(String url) async {
  if (url.trim().isEmpty) return false;

  if (!kIsWeb) {
    final viaProcess = await _openViaProcess(url);
    if (viaProcess) return true;
  }

  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } on PlatformException {
    return false;
  } catch (_) {
    return false;
  }

  return false;
}

Future<bool> _openViaProcess(String url) async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '', url],
        runInShell: true,
      );
      return result.exitCode == 0;
    }
    if (Platform.isMacOS) {
      final result = await Process.run('open', [url]);
      return result.exitCode == 0;
    }
    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [url]);
      return result.exitCode == 0;
    }
  } catch (_) {
    return false;
  }
  return false;
}
