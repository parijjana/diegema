import 'package:flutter/material.dart';

import '../core/utils/librivox_description.dart';
import '../theme/app_theme.dart';

/// Renders a LibriVox/archive.org book description as a segmented list —
/// "About", "Contents", "Narrated by", "Summary by", "Formats" — instead of
/// the raw wall of text the API returns, with the LibriVox boilerplate
/// (the "LibriVox recording of... by..." opener and "For further
/// information..." tail) dropped since the title/author are already shown
/// elsewhere on the page.
///
/// When [parseLibriVoxDescription] finds no structure at all (a plain
/// summary with nothing recognisable), this falls back to rendering the
/// summary paragraphs alone — never a blank widget for non-empty input.
class BookDescriptionView extends StatefulWidget {
  final String description;

  /// Tightens spacing for a smaller host (e.g. an overlay sheet rather than
  /// a full detail pane). Sections themselves are unchanged; only the
  /// spacing between them shrinks.
  final bool compact;

  const BookDescriptionView({
    super.key,
    required this.description,
    this.compact = false,
  });

  @override
  State<BookDescriptionView> createState() => _BookDescriptionViewState();
}

class _BookDescriptionViewState extends State<BookDescriptionView> {
  static const int _contentsCollapsedLimit = 6;

  bool _contentsExpanded = false;

  @override
  void didUpdateWidget(covariant BookDescriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description != widget.description) {
      _contentsExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parsed = parseLibriVoxDescription(widget.description);
    final gap = widget.compact ? Sp.x4 : Sp.x6;

    if (parsed.summary.isEmpty &&
        parsed.contents.isEmpty &&
        parsed.readBy == null &&
        parsed.summaryBy == null &&
        parsed.formats == null) {
      return const SizedBox.shrink();
    }

    // Nothing beyond an undifferentiated summary was recognised: render
    // plain paragraphs, with no section heading to lend them false
    // structure.
    if (!parsed.hasStructure) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < parsed.summary.length; i++) ...[
            if (i > 0) const SizedBox(height: Sp.x3),
            Text(
              parsed.summary[i],
              style: AppType.body.copyWith(color: c.textSecondary, height: 1.5),
            ),
          ],
        ],
      );
    }

    final sections = <Widget>[];

    if (parsed.summary.isNotEmpty) {
      sections.add(_Section(
        heading: 'About',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < parsed.summary.length; i++) ...[
              if (i > 0) const SizedBox(height: Sp.x3),
              Text(
                parsed.summary[i],
                style: AppType.body.copyWith(color: c.textSecondary, height: 1.5),
              ),
            ],
          ],
        ),
      ));
    }

    if (parsed.contents.isNotEmpty) {
      final showAll =
          _contentsExpanded || parsed.contents.length <= _contentsCollapsedLimit;
      final shown =
          showAll ? parsed.contents : parsed.contents.take(_contentsCollapsedLimit).toList();
      sections.add(_Section(
        heading: 'Contents',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in shown) _ContentsBullet(text: item, color: c.textSecondary),
            if (!showAll) ...[
              const SizedBox(height: Sp.x1),
              TextButton(
                onPressed: () => setState(() => _contentsExpanded = true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, Dim.tapMin),
                  alignment: Alignment.centerLeft,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Show all ${parsed.contents.length}',
                  style: AppType.label.copyWith(color: c.accentText),
                ),
              ),
            ],
          ],
        ),
      ));
    }

    if (parsed.readBy != null) {
      final language = parsed.language;
      final showLanguage = language != null && language.toLowerCase() != 'english';
      sections.add(_Section(
        heading: 'Narrated by',
        child: Text(
          showLanguage ? '${parsed.readBy} ($language)' : parsed.readBy!,
          style: AppType.body.copyWith(color: c.textSecondary, height: 1.5),
        ),
      ));
    }

    final captions = <Widget>[];
    if (parsed.summaryBy != null) {
      captions.add(Text(
        'Summary by ${parsed.summaryBy}',
        style: AppType.caption.copyWith(color: c.textSecondary),
      ));
    }
    if (parsed.formats != null) {
      captions.add(Text(
        parsed.formats!,
        style: AppType.caption.copyWith(color: c.textSecondary),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: gap),
            Divider(height: 1, color: c.textSecondary.withValues(alpha: 0.15)),
            SizedBox(height: gap),
          ],
          sections[i],
        ],
        if (captions.isNotEmpty) ...[
          SizedBox(height: gap),
          Wrap(
            spacing: Sp.x4,
            runSpacing: Sp.x1,
            children: captions,
          ),
        ],
      ],
    );
  }
}

/// A labelled section: a small caps-weight (but not upper-cased — the app
/// never uppercases labels, see `AppType`) heading followed by its content,
/// with the heading exposed to assistive tech as a real header.
class _Section extends StatelessWidget {
  final String heading;
  final Widget child;

  const _Section({required this.heading, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            heading,
            style: AppType.label.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: Sp.x2),
        child,
      ],
    );
  }
}

class _ContentsBullet extends StatelessWidget {
  final String text;
  final Color color;

  const _ContentsBullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: AppType.body.copyWith(color: color, height: 1.5)),
          Expanded(
            child: Text(
              text,
              style: AppType.body.copyWith(color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
