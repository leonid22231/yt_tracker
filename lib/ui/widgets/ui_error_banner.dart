import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/error_messages.dart';

/// Баннер ошибки: короткий текст + опционально «Подробнее».
class UiErrorBanner extends StatefulWidget {
  const UiErrorBanner({
    super.key,
    required this.message,
    this.margin,
  });

  final String message;
  final EdgeInsetsGeometry? margin;

  @override
  State<UiErrorBanner> createState() => _UiErrorBannerState();
}

class _UiErrorBannerState extends State<UiErrorBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parsed = UserErrorMessage.fromRaw(widget.message);
    final hasDetail =
        parsed.detail != null && parsed.detail!.trim() != parsed.title.trim();

    return Container(
      margin: widget.margin ??
          EdgeInsets.fromLTRB(p.isOneC ? 8 : 16, p.isOneC ? 6 : 12, p.isOneC ? 8 : 16, 0),
      padding: EdgeInsets.all(p.isOneC ? 8 : 12),
      decoration: p.isOneC
          ? OneCDecorations.raised(p, color: p.formBackground).copyWith(
              border: Border(
                left: BorderSide(color: p.danger, width: 3),
                top: BorderSide(color: p.borderShadow),
                right: BorderSide(color: p.borderHighlight),
                bottom: BorderSide(color: p.borderHighlight),
              ),
            )
          : BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: p.danger, size: p.isOneC ? 18 : 20),
              SizedBox(width: p.isOneC ? 8 : 10),
              Expanded(
                child: Text(
                  parsed.title,
                  style: TextStyle(
                    fontSize: p.isOneC ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (hasDetail) ...[
            SizedBox(height: p.isOneC ? 4 : 6),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Скрыть' : 'Подробнее',
                    style: TextStyle(fontSize: 11, color: p.link),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Текст ошибки скопирован'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    'Копировать',
                    style: TextStyle(fontSize: 11, color: p.link),
                  ),
                ),
              ],
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: p.isOneC
                    ? OneCDecorations.sunken(p)
                    : BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                child: SelectableText(
                  parsed.detail!,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: p.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
