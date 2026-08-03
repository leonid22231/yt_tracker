import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/layout/variant_scaffold.dart';
import 'package:youtrack_timer/ui/screens/gitlab_settings_screen.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';
import 'package:youtrack_timer/ui/widgets/loading_progress_view.dart';
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
    final isLarge = ref.watch(designVariantProvider).isLarge;

    return VariantScaffold(
      title: 'YouTrack Timer',
      subtitle: 'Настройки',
      toolbarActions: isLarge
          ? [
              OneCToolbarButton(
                palette: ref.watch(designVariantProvider).palette,
                label: 'Сохранить',
                icon: Icons.save_outlined,
                emphasis: true,
                onPressed: _save,
              ),
            ]
          : null,
      body: settings.when(
        loading: () => const LoadingProgressScreen(
          operation: 'Настройки',
          stepLabel: 'Загрузка сохранённых параметров…',
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          _bind(s);
          return ListView(
            padding: EdgeInsets.all(isLarge ? 8 : 20),
            children: [
              VariantSectionCard(
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ytTokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Permanent token',
                      hintText: 'perm:…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('Проверить подключение'),
                  ),
                ],
              ),
              SizedBox(height: isLarge ? 8 : 16),
              VariantSectionCard(
                icon: Icons.auto_awesome,
                title: 'Cursor Agent',
                children: [
                  const VariantHintText(
                    'API-ключ для AI-оценки. Не попадает в логи.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cursorCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CURSOR_API_KEY',
                    ),
                  ),
                ],
              ),
              SizedBox(height: isLarge ? 8 : 16),
              VariantSectionCard(
                icon: Icons.hub_outlined,
                title: 'GitLab',
                children: [
                  const VariantHintText(
                    'Интеграция для аналитики по коммитам, веткам и задачам.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GitLabSettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Настройки GitLab'),
                  ),
                ],
              ),
              SizedBox(height: isLarge ? 8 : 16),
              VariantSectionCard(
                icon: Icons.palette_outlined,
                title: 'Интерфейс',
                children: [
                  const VariantHintText(
                    'Режим оформления. При ручном выборе авто отключается.',
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final mode = ref.watch(designModePreferenceProvider);
                      if (isLarge) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final m in DesignModePreference.values)
                              RadioListTile<DesignModePreference>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(m.label, style: const TextStyle(fontSize: 12)),
                                subtitle: Text(
                                  m.description,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                value: m,
                                groupValue: mode,
                                onChanged: (v) {
                                  if (v != null) {
                                    ref
                                        .read(designModePreferenceProvider.notifier)
                                        .setPreference(v);
                                  }
                                },
                              ),
                          ],
                        );
                      }
                      return SegmentedButton<DesignModePreference>(
                        segments: [
                          for (final m in DesignModePreference.values)
                            ButtonSegment(
                              value: m,
                              label: Text(m.label),
                              icon: Icon(
                                switch (m) {
                                  DesignModePreference.auto => Icons.auto_mode,
                                  DesignModePreference.current => Icons.tablet,
                                  DesignModePreference.large =>
                                    Icons.desktop_windows_outlined,
                                },
                                size: 16,
                              ),
                            ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (sel) => ref
                            .read(designModePreferenceProvider.notifier)
                            .setPreference(sel.first),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: isLarge ? 8 : 16),
              VariantSectionCard(
                icon: Icons.tune,
                title: 'Режимы',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('AI-оценка', style: TextStyle(fontSize: 12)),
                    subtitle: const Text(
                      'Анализ истории задач через Cursor Agent',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: _useAi,
                    onChanged: (v) => setState(() => _useAi = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Защита (Dry-run)', style: TextStyle(fontSize: 12)),
                    subtitle: const Text(
                      'Блокирует запись в YouTrack',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: _dryRun,
                    onChanged: (v) => setState(() => _dryRun = v),
                  ),
                ],
              ),
              if (!isLarge) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('Сохранить')),
              ],
            ],
          );
        },
      ),
    );
  }
}
