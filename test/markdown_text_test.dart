// Verifies MarkdownText strips markdown markers and renders their content,
// so AI replies no longer show raw '*'/'#'/'`' symbols.

import 'package:ai_recipe_generator/core/widgets/markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concatenates the visible text of every SelectableText.rich in the tree.
String _renderedText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final w in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
    buffer.write(w.textSpan?.toPlainText() ?? '');
    buffer.write('\n');
  }
  // Bullet/number markers are plain Text widgets, not SelectableText.
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    buffer.write(w.data ?? '');
  }
  return buffer.toString();
}

void main() {
  testWidgets('renders headings, bold, code and bullets without raw markers',
      (tester) async {
    const md = '# Garlic Pasta\n'
        'A **quick** dish with `olive oil`.\n'
        '* boil water\n'
        '* add *fresh* basil';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownText(data: md)),
      ),
    );
    await tester.pump();

    final rendered = _renderedText(tester);

    // Content is present…
    expect(rendered, contains('Garlic Pasta'));
    expect(rendered, contains('quick'));
    expect(rendered, contains('olive oil'));
    expect(rendered, contains('boil water'));
    expect(rendered, contains('fresh'));

    // …but the markdown markers are gone.
    expect(rendered.contains('**'), isFalse);
    expect(rendered.contains('# '), isFalse);
    expect(rendered.contains('`'), isFalse);
  });

  testWidgets('renders a blockquote without the raw > marker', (tester) async {
    const md = 'Intro line.\n'
        '> Tip: use *fresh* garlic\n'
        '> and let it rest.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownText(data: md)),
      ),
    );
    await tester.pump();

    final rendered = _renderedText(tester);

    expect(rendered, contains('Tip: use'));
    expect(rendered, contains('fresh'));
    expect(rendered, contains('and let it rest.'));
    // The blockquote marker (and inline italics) are stripped.
    expect(rendered.contains('>'), isFalse);
    expect(rendered.contains('*'), isFalse);
  });

  testWidgets('renders a pipe table without raw pipes', (tester) async {
    const md = '| Ingredient | Amount |\n'
        '| --- | --- |\n'
        '| Flour | 2 cups |\n'
        '| **Sugar** | 1 cup |';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownText(data: md)),
      ),
    );
    await tester.pump();

    final rendered = _renderedText(tester);

    // Header + cells present…
    expect(rendered, contains('Ingredient'));
    expect(rendered, contains('Amount'));
    expect(rendered, contains('Flour'));
    expect(rendered, contains('2 cups'));
    expect(rendered, contains('Sugar'));
    // …with a real Table widget and no raw pipes or separator dashes.
    expect(find.byType(Table), findsOneWidget);
    expect(rendered.contains('|'), isFalse);
    expect(rendered.contains('---'), isFalse);
    expect(rendered.contains('**'), isFalse);
  });

  testWidgets('malformed / ragged table does not throw', (tester) async {
    // Ragged rows (too few / too many cells) and a stray trailing line.
    const md = '| A | B | C |\n'
        '| --- | --- | --- |\n'
        '| only one |\n'
        '| x | y | z | extra |\n'
        'trailing text';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownText(data: md)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    final rendered = _renderedText(tester);
    expect(rendered, contains('only one'));
    expect(rendered, contains('trailing text'));
  });
}
