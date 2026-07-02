import 'package:test/test.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_ai_summary_markdown.dart';

void main() {
  test('normalizeAgentMarkdown убирает обёртку ```markdown', () {
    const raw = '''```markdown
## Заголовок
Текст
```''';

    expect(
      normalizeAgentMarkdown(raw),
      '## Заголовок\nТекст',
    );
  });

  test('normalizeAgentMarkdown не трогает обычный текст', () {
    const raw = '## Заголовок\n\n- пункт';
    expect(normalizeAgentMarkdown(raw), raw);
  });
}
