import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One card in a [CardStack].
class StackCard {
  final String title;

  /// Sits left of the title: an icon badge or a small cover.
  final Widget leading;

  /// Right of the title, e.g. a progress figure. Keep it one line.
  final Widget? trailing;

  /// What the front card shows under its title row. Only the front card's
  /// face is ever built; the others are covered below their title.
  final WidgetBuilder? face;

  final String semanticLabel;
  final VoidCallback onOpen;

  /// When set, the card flies into an opened [CardStackPage] with the same
  /// tag.
  final Object? heroTag;

  const StackCard({
    required this.title,
    required this.leading,
    required this.semanticLabel,
    required this.onOpen,
    this.trailing,
    this.face,
    this.heroTag,
  });
}

/// A rolodex of physical cards, after webOS's card view on the Palm Pre:
/// stacked top to bottom, each covering the one behind it so only its title
/// row shows, and the front card showing its face.
///
/// The stack sits at the bottom of the screen, in thumb reach, and scrolls:
/// it is laid out in a reversed scroll view, so a short stack rests on the
/// bottom edge and a tall one starts scrolled to the front card, with the
/// cards behind reached by scrolling up.
///
/// [cards] is front first.
class CardStack extends StatelessWidget {
  final List<StackCard> cards;
  final EdgeInsets padding;

  const CardStack({
    super.key,
    required this.cards,
    this.padding = EdgeInsets.zero,
  });

  /// How much of each card shows behind the next: its padding plus a title
  /// row that grows with the text size, so the title is never cut off.
  static double peekFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleRow =
        math.max(40.0, scaler.scale(AppType.titleMd.fontSize! * 1.4));
    return Sp.x5 + titleRow + Sp.x4;
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final peek = peekFor(context);
    final n = cards.length;
    // Cards behind are only ever seen as their title strip, so each is just
    // tall enough to tuck under the next one. The front card is in normal
    // flow and takes whatever height its face needs, which sizes the stack.
    final behindHeight = peek + Sp.x8;
    return SingleChildScrollView(
      reverse: true,
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              // Back to front: the card furthest back is at the top.
              for (var j = 0; j < n - 1; j++)
                Positioned(
                  top: peek * j,
                  // Further back is a touch narrower, so the pile reads as
                  // depth rather than a list.
                  left: math.min(n - 1 - j, 4) * 6.0,
                  right: math.min(n - 1 - j, 4) * 6.0,
                  height: behindHeight,
                  child: _StackCardView(card: cards[n - 1 - j], front: false),
                ),
              Padding(
                padding: EdgeInsets.only(top: peek * (n - 1)),
                child: _StackCardView(card: cards[0], front: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card surface, shared by the stacked card and the opened page so a
/// Hero flight between them is one continuous object.
class CardSurface extends StatelessWidget {
  final Widget child;
  const CardSurface({super.key, required this.child});

  static const radius = R.xl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      // Same radius on the shadow and the fill, and the fill is opaque.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: c.shadowUi.isEmpty ? c.shadow2 : c.shadowUi,
      ),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// A card's top row: leading badge, title, optional trailing widget.
class CardTitleRow extends StatelessWidget {
  final String title;
  final Widget leading;
  final Widget? trailing;
  final int maxLines;

  const CardTitleRow({
    super.key,
    required this.title,
    required this.leading,
    this.trailing,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        SizedBox.square(dimension: 40, child: leading),
        const SizedBox(width: Sp.x3),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(AppType.titleMd).copyWith(color: c.text)),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Sp.x2),
          trailing!,
        ],
      ],
    );
  }
}

/// A round accent badge for a card's leading slot.
class CardIconBadge extends StatelessWidget {
  final IconData icon;
  const CardIconBadge(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.accentWash, shape: BoxShape.circle),
      child: Icon(icon, size: Dim.iconSm, color: c.accentText),
    );
  }
}

class _StackCardView extends StatelessWidget {
  final StackCard card;
  final bool front;
  const _StackCardView({required this.card, required this.front});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget surface = CardSurface(
      child: InkWell(
        onTap: card.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(Sp.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardTitleRow(
                title: card.title,
                leading: card.leading,
                trailing: card.trailing,
                maxLines: 1,
              ),
              if (front) ...[
                if (card.face != null) ...[
                  const SizedBox(height: Sp.x4),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: Sp.x4),
                  card.face!(context),
                ],
                const SizedBox(height: Sp.x3),
                Row(
                  children: [
                    Text('Tap to open',
                        style: AppType.caption.copyWith(color: c.accentText)),
                    const Spacer(),
                    Icon(Icons.open_in_full_rounded,
                        size: 18, color: c.accentText),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (card.heroTag != null) {
      surface = Hero(tag: card.heroTag!, child: surface);
    }
    // The front card's face may hold its own buttons (a shelf of books), so
    // only the cards behind collapse to a single button.
    return Semantics(
      button: true,
      label: card.semanticLabel,
      excludeSemantics: !front,
      child: surface,
    );
  }
}

/// Opens a card full screen, fading in while its surface flies out of the
/// stack (when [heroTag] matches the stacked card's).
Future<void> openStackCard(
  BuildContext context, {
  required String title,
  required Widget leading,
  required WidgetBuilder body,
  Object? heroTag,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, _) => CardStackPage(
      title: title,
      leading: leading,
      heroTag: heroTag,
      body: body,
    ),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ));
}

/// A card opened out of a stack: full screen, title row with Close, and
/// [body] filling the rest (it should scroll itself).
class CardStackPage extends StatelessWidget {
  final String title;
  final Widget leading;
  final Object? heroTag;
  final WidgetBuilder body;

  const CardStackPage({
    super.key,
    required this.title,
    required this.leading,
    required this.body,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget card = CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x4, Sp.x2, Sp.x2),
            child: CardTitleRow(
              title: title,
              leading: leading,
              trailing: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Divider(color: c.border, height: 1),
          Expanded(child: Builder(builder: body)),
        ],
      ),
    );
    if (heroTag != null) {
      card = Hero(
        tag: heroTag!,
        // In flight, show only the surface and title: laying the body out at
        // every intermediate size would be busy and expensive.
        flightShuttleBuilder: (context, animation, direction, from, to) =>
            CardSurface(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x5),
            child: Align(
              alignment: Alignment.topLeft,
              child: CardTitleRow(title: title, leading: leading, maxLines: 1),
            ),
          ),
        ),
        child: card,
      );
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(Sp.x2), child: card),
      ),
    );
  }
}
