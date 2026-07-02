import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/gitlab_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GitLab'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: settings.when(
        loading: () => const LoadingProgressScreen(
          operation: 'GitLab',
          stepLabel: 'Загрузка настроек…',
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          _bind(s);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionCard(
                icon: Icons.hub_outlined,
                title: 'Подключение GitLab',
                children: [
                  const Text(
                    'Personal Access Token с правами read_api и read_repository. '
                    'Токен хранится локально и не попадает в логи.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GitLab URL',
                      hintText: 'https://gitlab.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'glpat-…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (gitLab.isValidating && gitLab.loadingProgress != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LoadingProgressView(
                        progress: gitLab.loadingProgress,
                        layout: LoadingProgressLayout.panel,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: gitLab.isValidating ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: Text(
                      gitLab.isValidating
                          ? 'Проверка…'
                          : 'Проверить подключение',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.science_outlined,
                title: 'Демо-режим',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Использовать мок-данные'),
                    subtitle: const Text(
                      'Проверить интерфейс аналитики без реального token',
                    ),
                    value: _demoMode,
                    onChanged: (v) => setState(() => _demoMode = v),
                  ),
                ],
              ),
              if (gitLab.user != null) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.person_outline,
                  title: 'Статус',
                  children: [
                    _StatusRow(
                      label: 'Пользователь',
                      value: gitLab.user!.displayName,
                    ),
                    _StatusRow(
                      label: 'Username',
                      value: '@${gitLab.user!.username}',
                    ),
                    if (gitLab.activity != null) ...[
                      _StatusRow(
                        label: 'Коммитов',
                        value: '${gitLab.activity!.commits.length}',
                      ),
                      _StatusRow(
                        label: 'Веток',
                        value: '${gitLab.activity!.branches.length}',
                      ),
                      if (gitLab.activity!.projectCount > 0)
                        _StatusRow(
                          label: 'Проектов',
                          value: '${gitLab.activity!.projectCount}',
                        ),
                    ],
                    if (gitLab.statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          gitLab.statusMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (gitLab.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          gitLab.errorMessage,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
