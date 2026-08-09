import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Lightweight markdown renderer for AI chat replies.
///
/// Deliberately NOT a full CommonMark parser — it covers only the subset LLM
/// chat output commonly emits, so no external package (and its build risk) is
/// needed:
/// * headings `#`, `##`, `###`
/// * bullet lists (`-`, `*`, `•`) and numbered lists (`1.`)
/// * blockquotes (`> `)
/// * GitHub-style pipe tables
/// * inline **bold**, *italic*, and `code`
///
/// Everything is styled from design tokens and inherits [baseStyle] (so the
/// same widget works on any background by passing the right text color).
class MarkdownText extends StatelessWidget {
  const MarkdownText({super.key, required this.data, this.baseStyle});

  /// The raw markdown text to render.
  final String data;

  /// Base text style (color/size) that inline and block styles derive from.
  final TextStyle? baseStyle;

  static final RegExp _heading = RegExp(r'^(#{1,3})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)\.\s+(.*)$');
  static final RegExp _blockquote = RegExp(r'^\s*>\s?(.*)$');
  static final RegExp _inlineToken =
      RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\*(.+?)\*', dotAll: true);

  /// A pipe-table separator row, e.g. `| --- | :--: |` (dashes with optional
  /// leading/trailing pipes and `:` alignment markers).
  static final RegExp _tableSeparator =
      RegExp(r'^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$');

  @override
  Widget build(BuildContext context) {
    final TextStyle base = baseStyle ?? AppTextStyles.body;
    final List<String> lines =
        data.replaceAll('\r\n', '\n').trim().split('\n');
    final List<Widget> blocks = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: AppDimensions.spaceS));
        continue;
      }

      final RegExpMatch? heading = _heading.firstMatch(line);
      if (heading != null) {
        final int level = heading.group(1)!.length;
        final TextStyle style = level == 1
            ? base.copyWith(fontSize: 18, fontWeight: FontWeight.w700)
            : level == 2
                ? base.copyWith(fontSize: 16, fontWeight: FontWeight.w600)
                : base.copyWith(fontWeight: FontWeight.w600);
        blocks.add(_paragraph(heading.group(2)!, style));
        continue;
      }

      // Table: a row containing '|' immediately followed by a separator row.
      if (line.contains('|') &&
          i + 1 < lines.length &&
          _tableSeparator.hasMatch(lines[i + 1])) {
        final int consumed = _appendTable(blocks, lines, i, base);
        if (consumed > 0) {
          i += consumed - 1;
          continue;
        }
      }

      // Blockquote: consume consecutive `> ` lines into one quoted block.
      final RegExpMatch? quote = _blockquote.firstMatch(line);
      if (quote != null) {
        final List<String> quoteLines = <String>[quote.group(1)!];
        while (i + 1 < lines.length) {
          final RegExpMatch? next = _blockquote.firstMatch(lines[i + 1]);
          if (next == null) break;
          quoteLines.add(next.group(1)!);
          i++;
        }
        blocks.add(_blockquoteBlock(quoteLines, base));
        continue;
      }

      final RegExpMatch? bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        blocks.add(_listRow('•  ', bullet.group(1)!, base));
        continue;
      }

      final RegExpMatch? numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        blocks.add(_listRow('${numbered.group(1)}.  ', numbered.group(2)!, base));
        continue;
      }

      blocks.add(_paragraph(line, base));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _paragraph(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceXs),
      child: SelectableText.rich(TextSpan(children: _inline(text, style))),
    );
  }

  Widget _listRow(String marker, String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(marker, style: style.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: SelectableText.rich(TextSpan(children: _inline(text, style))),
          ),
        ],
      ),
    );
  }

  /// Renders consecutive `> ` lines as a single quoted block: a subtle brand
  /// left accent bar plus muted italic text (all from design tokens).
  Widget _blockquoteBlock(List<String> quoteLines, TextStyle style) {
    final TextStyle quoteStyle = style.copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
    );
    final List<Widget> rows = <Widget>[
      for (final String text in quoteLines)
        SelectableText.rich(TextSpan(children: _inline(text, quoteStyle))),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceXs),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.secondary, width: 3),
          ),
        ),
        padding: const EdgeInsets.only(
          left: AppDimensions.spaceM,
          top: AppDimensions.spaceXs,
          bottom: AppDimensions.spaceXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
  }

  /// Parses a GitHub-style pipe table starting at [start] (a header row whose
  /// next line is a separator). Appends one bordered [Table] widget to [blocks]
  /// and returns how many source lines it consumed. Returns 0 if the table is
  /// too malformed to render, so the caller falls back to plain paragraphs.
  int _appendTable(
    List<Widget> blocks,
    List<String> lines,
    int start,
    TextStyle base,
  ) {
    final List<String> header = _splitRow(lines[start]);
    if (header.isEmpty) return 0;
    final int columns = header.length;

    // Collect body rows until a blank line or a non-table line.
    final List<List<String>> bodyRows = <List<String>>[];
    int i = start + 2; // skip header + separator
    while (i < lines.length) {
      final String line = lines[i].trimRight();
      if (line.trim().isEmpty || !line.contains('|')) break;
      bodyRows.add(_splitRow(line));
      i++;
    }

    final TextStyle headerStyle = base.copyWith(fontWeight: FontWeight.w600);
    final BorderSide side = BorderSide(color: AppColors.border, width: 1);

    final List<TableRow> tableRows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(color: AppColors.primarySoft),
        children: <Widget>[
          for (int c = 0; c < columns; c++)
            _tableCell(c < header.length ? header[c] : '', headerStyle),
        ],
      ),
      for (final List<String> row in bodyRows)
        TableRow(
          children: <Widget>[
            // Pad/truncate ragged rows to the header column count.
            for (int c = 0; c < columns; c++)
              _tableCell(c < row.length ? row[c] : '', base),
          ],
        ),
    ];

    blocks.add(Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceS),
      child: Table(
        border: TableBorder(
          top: side,
          bottom: side,
          left: side,
          right: side,
          horizontalInside: side,
          verticalInside: side,
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: tableRows,
      ),
    ));

    return i - start;
  }

  /// One padded table cell rendering inline markdown.
  Widget _tableCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceS,
        vertical: AppDimensions.spaceXs,
      ),
      child: SelectableText.rich(TextSpan(children: _inline(text, style))),
    );
  }

  /// Splits one pipe-table row into trimmed cell strings, tolerating the
  /// optional leading/trailing pipes GitHub tables allow.
  static List<String> _splitRow(String line) {
    final List<String> parts = line.trim().split('|');
    if (parts.isNotEmpty && parts.first.trim().isEmpty) parts.removeAt(0);
    if (parts.isNotEmpty && parts.last.trim().isEmpty) {
      parts.removeAt(parts.length - 1);
    }
    return <String>[for (final String p in parts) p.trim()];
  }

  /// Splits [text] into styled inline spans (bold / italic / code / plain).
  static List<InlineSpan> _inline(String text, TextStyle base) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;

    for (final RegExpMatch m in _inlineToken.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(
            fontFamily: 'monospace',
            color: AppColors.primaryDark,
          ),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: m.group(3),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: base));
    }
    return spans;
  }
}
