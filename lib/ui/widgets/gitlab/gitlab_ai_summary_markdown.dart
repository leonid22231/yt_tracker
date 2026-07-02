import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/utils/open_external_url.dart';

/// Нормализует ответ агента: убирает обёртку ```markdown и лишние пробелы.
String normalizeAgentMarkdown(String raw) {
  var text = raw.trim();
  if (!text.startsWith('```')) return text;

  final lines = text.split('\n');
  if (lines.isEmpty) return text;

  final first = lines.first.trim();
  if (!first.startsWith('```')) return text;

  lines.removeAt(0);
  if (lines.isNotEmpty && lines.last.trim() == '```') {
    lines.removeLast();
  }
  return lines.join('\n').trim();
}

/// Markdown-рендер AI-сводки GitLab в стиле приложения.
class GitLabAiSummaryMarkdown extends StatelessWidget {
  const GitLabAiSummaryMarkdown({
    super.key,
    required this.data,
    this.selectable = true,
  });

  final String data;
  final bool selectable;

  static MarkdownStyleSheet styleSheet(BuildContext context) {
    const base = TextStyle(
      fontSize: 13,
      height: 1.55,
      color: AppColors.textPrimary,
    );

    return MarkdownStyleSheet(
      p: base,
      pPadding: const EdgeInsets.only(bottom: 8),
      h1: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
      h1Padding: const EdgeInsets.only(top: 4, bottom: 10),
      h2: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h3: base.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      h3Padding: const EdgeInsets.only(top: 10, bottom: 4),
      h4: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      h5: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      h6: base.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      blockquote: base.copyWith(color: AppColors.textSecondary),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      code: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      listBullet: base.copyWith(color: AppColors.primary),
      listIndent: 20,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      a: base.copyWith(
        color: AppColors.accent,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.accent.withValues(alpha: 0.6),
      ),
      tableHead: base.copyWith(fontWeight: FontWeight.w700),
      tableBody: base,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      tableBorder: TableBorder.all(color: AppColors.border, width: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markdown = normalizeAgentMarkdown(data);

    return MarkdownBody(
      data: markdown,
      selectable: selectable,
      styleSheet: styleSheet(context),
      shrinkWrap: true,
      onTapLink: (text, href, title) {
        if (href != null && href.isNotEmpty) {
          openExternalUrl(href);
        }
      },
    );
  }
}
