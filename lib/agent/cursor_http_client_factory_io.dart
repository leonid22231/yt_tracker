import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:youtrack_timer/agent/cursor_proxy.dart';

/// IO-реализация: при заданном прокси все запросы к Cursor идут через него.
http.Client createCursorHttpClient({String? proxy}) {
  final normalized = CursorProxy.normalize(proxy);
  if (normalized == null) {
    return http.Client();
  }

  final ioClient = HttpClient();
  ioClient.findProxy = (_) => CursorProxy.findProxyDirective(normalized);
  return IOClient(ioClient);
}
