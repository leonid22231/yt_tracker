import 'dart:io';

import 'package:args/args.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/services/timer_service.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/utils/logger.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// CLI для автоматического заполнения рабочего времени в YouTrack.
Future<void> main(List<String> arguments) async {
  await AppLog.instance.init(enableFile: true);
  final logger = AppLogger(category: LogCategory.app);

  final parser = ArgParser()
    ..addOption(
      'start-date',
      abbr: 's',
      help: 'Начало периода (yyyy-MM-dd)',
      mandatory: true,
    )
    ..addOption(
      'end-date',
      abbr: 'e',
      help: 'Конец периода (yyyy-MM-dd)',
      mandatory: true,
    )
    ..addOption(
      'token',
      abbr: 't',
      help: 'Токен YouTrack (или YOUTRACK_TOKEN в .env)',
    )
    ..addOption(
      'base-url',
      abbr: 'u',
      help: 'URL YouTrack (или YOUTRACK_URL в .env)',
    )
    ..addFlag(
      'dry-run',
      abbr: 'n',
      help: 'Только показать план, без записи в API',
      negatable: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Справка');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    logger.error(e.message);
    _printUsage(parser);
    exit(1);
  }

  if (args['help'] == true) {
    _printUsage(parser);
    exit(0);
  }

  try {
    final startDate = DateUtils.parseDate(args['start-date'] as String);
    final endDate = DateUtils.parseDate(args['end-date'] as String);

    if (endDate.isBefore(startDate)) {
      logger.error('end-date не может быть раньше start-date');
      exit(1);
    }

    final config = AppConfig.load(
      baseUrl: args['base-url'] as String?,
      token: args['token'] as String?,
      startDate: startDate,
      endDate: endDate,
      dryRun: args['dry-run'] == true,
    );

    final client = YouTrackClient(config);
    final service = TimerService(config: config, client: client, logger: logger);

    final result = await service.run();
    client.close();

    if (result.hasErrors) {
      exit(2);
    }
    exit(0);
  } on ArgumentError catch (e) {
    logger.error(e.message);
    _printUsage(parser);
    exit(1);
  } on YouTrackApiException catch (e) {
    logger.error(e.message);
    exit(2);
  } catch (e, st) {
    logger.error('Неожиданная ошибка: $e');
    logger.error(st.toString());
    exit(2);
  }
}

void _printUsage(ArgParser parser) {
  // ignore: avoid_print
  print('''
Автозаполнение рабочего времени в YouTrack

Использование:
  dart run youtrack_timer --start-date 2024-01-01 --end-date 2024-01-31
  dart run youtrack_timer -s 2024-01-01 -e 2024-01-31 -t YOUR_TOKEN -u https://company.youtrack.cloud

Переменные окружения / .env:
  YOUTRACK_URL   — базовый URL инстанса YouTrack
  YOUTRACK_TOKEN — permanent token (perm:...)

Опции:
${parser.usage}
''');
}
