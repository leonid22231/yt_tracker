import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/utils/open_external_url.dart';
import 'package:youtrack_timer/youtrack/youtrack_links.dart';

/// Открывает задачу YouTrack в браузере (или копирует ссылку).
Future<void> openYouTrackIssue(
  BuildContext context, {
  required String? baseUrl,
  required String issueIdReadable,
}) async {
  if (baseUrl == null || baseUrl.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите URL YouTrack в настройках')),
      );
    }
    return;
  }

  final url = YouTrackLinks.issueUrl(baseUrl, issueIdReadable);
  final ok = await openExternalUrl(url);
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована в буфер обмена')),
    );
  }
}

/// Кликабельный ID задачи YouTrack.
class YouTrackIssueLink extends StatefulWidget {
  const YouTrackIssueLink({
    super.key,
    required this.issueIdReadable,
    this.baseUrl,
    this.style,
    this.showIcon = false,
    this.maxLines = 1,
    this.onTap,
  });

  final String issueIdReadable;
  final String? baseUrl;
  final TextStyle? style;
  final bool showIcon;
  final int maxLines;
  final VoidCallback? onTap;

  @override
  State<YouTrackIssueLink> createState() => _YouTrackIssueLinkState();
}

class _YouTrackIssueLinkState extends State<YouTrackIssueLink> {
  var _hovered = false;

  bool get _canOpen => widget.baseUrl != null && widget.baseUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _canOpen
          ? (_hovered ? AppColors.accent : AppColors.primary)
          : AppColors.textSecondary,
      decoration: _canOpen ? TextDecoration.underline : null,
      decorationColor: AppColors.primary.withValues(alpha: 0.5),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: _canOpen ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: widget.onTap ??
            (_canOpen
                ? () => openYouTrackIssue(
                      context,
                      baseUrl: widget.baseUrl,
                      issueIdReadable: widget.issueIdReadable,
                    )
                : null),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.issueIdReadable,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
                style: widget.style ?? defaultStyle,
              ),
            ),
            if (widget.showIcon && _canOpen) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: (_hovered ? AppColors.accent : AppColors.primary)
                    .withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip со ссылкой на задачу YouTrack.
class YouTrackIssueChip extends StatefulWidget {
  const YouTrackIssueChip({
    super.key,
    required this.issueIdReadable,
    this.baseUrl,
  });

  final String issueIdReadable;
  final String? baseUrl;

  @override
  State<YouTrackIssueChip> createState() => _YouTrackIssueChipState();
}

class _YouTrackIssueChipState extends State<YouTrackIssueChip> {
  var _hovered = false;

  bool get _canOpen => widget.baseUrl != null && widget.baseUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: _canOpen ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: _hovered ? AppColors.primary.withValues(alpha: 0.2) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: InkWell(
          onTap: _canOpen
              ? () => openYouTrackIssue(
                    context,
                    baseUrl: widget.baseUrl,
                    issueIdReadable: widget.issueIdReadable,
                  )
              : null,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.issueIdReadable,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _canOpen ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                if (_canOpen) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 11,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Горизонтальный список chip-ссылок на задачи.
class YouTrackIssueChipList extends StatelessWidget {
  const YouTrackIssueChipList({
    super.key,
    required this.issueIds,
    this.baseUrl,
    this.spacing = 6,
    this.runSpacing = 6,
  });

  final Iterable<String> issueIds;
  final String? baseUrl;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final ids = issueIds.toList();
    if (ids.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final id in ids)
          YouTrackIssueChip(issueIdReadable: id, baseUrl: baseUrl),
      ],
    );
  }
}
