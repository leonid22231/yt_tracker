import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/providers/gitlab_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/layout/variant_scaffold.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';
import 'package:youtrack_timer/ui/widgets/loading_progress_view.dart';

/// Настройки подключения GitLab.
class GitLabSettingsScreen extends ConsumerStatefulWidget {
  const GitLabSettingsScreen({super.key});

  @override
  ConsumerState<GitLabSettingsScreen> createState() =>
      _GitLabSettingsScreenState();
}

class _GitLabSettingsScreenState extends ConsumerState<GitLabSettingsScreen> {
  final _urlCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _demoMode = false;
  bool _loaded = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _bind(AppSettings s) {
    if (_loaded) return;
    _urlCtrl.text = s.gitLabUrl;
    _tokenCtrl.text = s.gitLabToken;
    _demoMode = s.gitLabDemoMode;
    _loaded = true;
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

  Future<void> _testConnection() async {
    final url = _urlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _showSnack('Укажите Personal Access Token', isError: true);
      return;
    }

    final ok = await ref.read(gitLabProvider.notifier).validateAndConnect(
          baseUrl: url,
          token: token,
        );
    if (ok && mounted) {
      _showSnack('GitLab подключён успешно');
    } else if (mounted) {
      final err = ref.read(gitLabProvider).errorMessage;
      _showSnack(err.isNotEmpty ? err : 'Ошибка подключения', isError: true);
    }
  }

  Future<void> _save() async {
    final current = ref.read(settingsProvider).valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      gitLabUrl: _urlCtrl.text.trim(),
      gitLabToken: _tokenCtrl.text.trim(),
      gitLabDemoMode: _demoMode,
    ).normalized();

    await ref.read(settingsProvider.notifier).update(updated);

    final gitLab = ref.read(gitLabProvider.notifier);
    if (_demoMode) {
      await gitLab.loadDemo();
    } else if (updated.gitLabToken.isNotEmpty) {
      await gitLab.refreshData();
    }

    if (mounted) {
      _showSnack('Настройки GitLab сохранены');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final gitLab = ref.watch(gitLabProvider);
    final isLarge = ref.watch(designVariantProvider).isLarge;
    final p = ref.watch(designVariantProvider).palette;

    return VariantScaffold(
      title: 'GitLab',
      subtitle: 'Настройки подключения',
      toolbarActions: isLarge
          ? [
              OneCToolbarButton(
                palette: p,
                label: 'Сохранить',
                icon: Icons.save_outlined,
                emphasis: true,
                onPressed: _save,
              ),
            ]
          : null,
      body: settings.when(
        loading: () => const LoadingProgressScreen(
          operation: 'GitLab',
          stepLabel: 'Загрузка настроек…',
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          _bind(s);
          return ListView(
            padding: EdgeInsets.all(isLarge ? 8 : 20),
            children: [
              VariantSectionCard(
                icon: Icons.hub_outlined,
                title: 'Подключение GitLab',
                children: [
                  const VariantHintText(
                    'Personal Access Token с правами read_api и read_repository.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GitLab URL',
                      hintText: 'https://gitlab.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'glpat-…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (gitLab.isValidating && gitLab.loadingProgress != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LoadingProgressView(
                        progress: gitLab.loadingProgress,
                        layout: LoadingProgressLayout.panel,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: gitLab.isValidating ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering, size: 16),
                    label: Text(
                      gitLab.isValidating ? 'Проверка…' : 'Проверить подключение',
                    ),
                  ),
                ],
              ),
              SizedBox(height: isLarge ? 8 : 16),
              VariantSectionCard(
                icon: Icons.science_outlined,
                title: 'Демо-режим',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Использовать мок-данные', style: TextStyle(fontSize: 12)),
                    subtitle: const Text(
                      'Проверить интерфейс без реального token',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: _demoMode,
                    onChanged: (v) => setState(() => _demoMode = v),
                  ),
                ],
              ),
              if (gitLab.user != null) ...[
                SizedBox(height: isLarge ? 8 : 16),
                VariantSectionCard(
                  icon: Icons.person_outline,
                  title: 'Статус',
                  children: [
                    _StatusRow(label: 'Пользователь', value: gitLab.user!.displayName),
                    _StatusRow(label: 'Username', value: '@${gitLab.user!.username}'),
                    if (gitLab.activity != null) ...[
                      _StatusRow(
                        label: 'Коммитов',
                        value: '${gitLab.activity!.commits.length}',
                      ),
                      _StatusRow(
                        label: 'Веток',
                        value: '${gitLab.activity!.branches.length}',
                      ),
                    ],
                  ],
                ),
              ],
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

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 11, color: p.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
