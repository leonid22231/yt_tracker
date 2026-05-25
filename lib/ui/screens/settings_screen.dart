import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Настройки подключений и режимов.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  final _ytTokenCtrl = TextEditingController();
  final _cursorCtrl = TextEditingController();
  bool _useAi = true;
  bool _dryRun = true;
  bool _loaded = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _ytTokenCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  void _bind(AppSettings s) {
    if (_loaded) return;
    _urlCtrl.text = s.youTrackUrl;
    _ytTokenCtrl.text = s.youTrackToken;
    _cursorCtrl.text = s.cursorApiKey;
    _useAi = s.useAi;
    _dryRun = s.dryRun;
    _loaded = true;
  }

  Future<void> _testConnection() async {
    final settings = AppSettings(
      youTrackUrl: _urlCtrl.text.trim(),
      youTrackToken: _ytTokenCtrl.text.trim(),
      cursorApiKey: _cursorCtrl.text.trim(),
    ).normalized();

    if (!settings.hasYouTrack) {
      _showSnack('Укажите URL и токен YouTrack');
      return;
    }

    final client = YouTrackClient(
      AppConfig(
        baseUrl: settings.youTrackUrl,
        token: settings.youTrackToken,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      ),
    );

    try {
      await client.ping();
      client.close();
      _showSnack('Подключение успешно');
    } on YouTrackApiException catch (e) {
      client.close();
      _showSnack(e.message.split('\n').first, isError: true);
    } catch (e) {
      client.close();
      _showSnack('$e', isError: true);
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, maxLines: 4),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  Future<void> _save() async {
    final updated = AppSettings(
      youTrackUrl: _urlCtrl.text.trim(),
      youTrackToken: _ytTokenCtrl.text.trim(),
      cursorApiKey: _cursorCtrl.text.trim(),
      useAi: _useAi,
      dryRun: _dryRun,
    ).normalized();
    await ref.read(settingsProvider.notifier).update(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки сохранены')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          _bind(s);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionCard(
                icon: Icons.cloud_outlined,
                title: 'YouTrack',
                children: [
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL инстанса',
                      hintText: 'https://company.youtrack.cloud',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ytTokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Permanent token',
                      hintText: 'perm:…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Проверить подключение'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.auto_awesome,
                title: 'Cursor Agent',
                children: [
                  const Text(
                    'API-ключ для AI-оценки. Не попадает в логи.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cursorCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CURSOR_API_KEY',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.tune,
                title: 'Режимы',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('AI-оценка'),
                    subtitle: const Text(
                      'Анализ истории задач через Cursor Agent',
                    ),
                    value: _useAi,
                    onChanged: (v) => setState(() => _useAi = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Защита (Dry-run)'),
                    subtitle: const Text(
                      'Блокирует запись в YouTrack. Проверка всегда без записи.',
                    ),
                    value: _dryRun,
                    onChanged: (v) => setState(() => _dryRun = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
