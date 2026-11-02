import 'package:http/http.dart' as http;

import 'cursor_http_client_factory_stub.dart'
    if (dart.library.io) 'cursor_http_client_factory_io.dart' as impl;

/// HTTP-клиент для Cursor Agent.
///
/// На desktop/CLI: при [proxy] (`host:port`) трафик идёт через прокси.
/// На web: proxy игнорируется (ограничение браузера).
http.Client createCursorHttpClient({String? proxy}) =>
    impl.createCursorHttpClient(proxy: proxy);
