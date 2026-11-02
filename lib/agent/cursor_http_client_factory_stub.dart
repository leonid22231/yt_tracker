import 'package:http/http.dart' as http;

/// Web/stub: браузерный fetch не умеет задавать HTTP-прокси из приложения.
/// Значение proxy игнорируется — настройте системный/браузерный прокси.
http.Client createCursorHttpClient({String? proxy}) {
  return http.Client();
}
