import 'package:test/test.dart';
import 'package:youtrack_timer/agent/cursor_proxy.dart';

void main() {
  group('CursorProxy.normalize', () {
    test('пустая строка → null', () {
      expect(CursorProxy.normalize(null), isNull);
      expect(CursorProxy.normalize(''), isNull);
      expect(CursorProxy.normalize('   '), isNull);
    });

    test('host:port', () {
      expect(CursorProxy.normalize('127.0.0.1:7890'), '127.0.0.1:7890');
      expect(CursorProxy.normalize('proxy.local:3128'), 'proxy.local:3128');
    });

    test('схема http/https отрезается', () {
      expect(
        CursorProxy.normalize('http://127.0.0.1:7890'),
        '127.0.0.1:7890',
      );
      expect(
        CursorProxy.normalize('https://proxy.local:8080/path'),
        'proxy.local:8080',
      );
    });

    test('IPv6 в скобках', () {
      expect(CursorProxy.normalize('[::1]:7890'), '[::1]:7890');
    });

    test('невалидный формат → ArgumentError', () {
      expect(() => CursorProxy.normalize('127.0.0.1'), throwsArgumentError);
      expect(() => CursorProxy.normalize('not-a-proxy'), throwsArgumentError);
      expect(() => CursorProxy.normalize('host:99999'), throwsArgumentError);
    });

    test('findProxyDirective', () {
      expect(
        CursorProxy.findProxyDirective('127.0.0.1:7890'),
        'PROXY 127.0.0.1:7890',
      );
    });
  });
}
