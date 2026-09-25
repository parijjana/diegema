import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
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
/// The stack rests on the bottom edge, in thumb reach, and turns like a
/// rolodex wheel: drag it down (or fling, or use the mouse wheel) and the
/// card behind slides forward while the front one drops away to the back.
/// It wraps, so it scrolls through its cards endlessly in either direction.
///
/// [cards] is front first.
class CardStack extends StatefulWidget {
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
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack>
    with SingleTickerProviderStateMixin {
  /// The wheel's position in cards: its integer part is the front card
  /// (mod the card count), the fraction how far the next one has come
  /// forward.
  late final AnimationController _pos =
      AnimationController.unbounded(vsync: this);

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _settle(double target) => _pos.animateTo(target,
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  void _step(int by) => _settle(
      (_pos.isAnimating ? _pos.value : _pos.value.roundToDouble()).round() +
          by.toDouble());

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final n = cards.length;
    final peek = CardStack.peekFor(context);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      final pad = widget.padding;
      final avail = math.max(peek * 2, constraints.maxHeight - pad.vertical);
      final width = math.min(560.0, constraints.maxWidth - pad.horizontal);
      // As many title strips as fit above a front card big enough for its
      // face; the rest wait their turn round the wheel.
      final minFront = math.min(avail, scaler.scale(220));
      var visible = n;
      while (visible > 1 && avail - (visible - 1) * peek < minFront) {
        visible--;
      }
      final frontHeight = math.min(
          math.max(scaler.scale(300), minFront), avail - (visible - 1) * peek);
      final frontTop = avail - frontHeight;

      return Semantics(
        customSemanticsActions: n < 2
            ? null
            : {
                const CustomSemanticsAction(label: 'Next card'): () => _step(1),
                const CustomSemanticsAction(label: 'Previous card'): () =>
                    _step(-1),
              },
        child: Listener(
          onPointerSignal: (e) {
            if (n > 1 && e is PointerScrollEvent) {
              _step(e.scrollDelta.dy > 0 ? 1 : -1);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: n < 2 ? null : (_) => _pos.stop(),
            onVerticalDragUpdate:
                n < 2 ? null : (d) => _pos.value += d.primaryDelta! / peek,
            onVerticalDragEnd: n < 2
                ? null
                : (d) {
                    final velocity = d.primaryVelocity! / peek;
                    _settle((_pos.value + velocity * 0.18).roundToDouble());
                  },
            child: ClipRect(
              child: Padding(
                padding: pad,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: width,
                    height: avail,
                    child: AnimatedBuilder(
                      animation: _pos,
                      builder: (context, _) =>
                          _buildCards(n, visible, peek, frontTop, frontHeight),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCards(
      int n, int visible, double peek, double frontTop, double frontHeight) {
    final pos = n < 2 ? 0.0 : _pos.value;
    final base = pos.floor();
    final f = pos - base;
    final children = <Widget>[];
    // Back to front. Slot 0 is the front card; slot `visible` is the one
    // coming round the wheel into the back, drawn only mid-turn.
    for (var s = visible; s >= 0; s--) {
      if (s == visible && (f == 0 || n < 2)) continue;
      final index = ((base + s) % n + n) % n;
      final depth = math.max(0.0, s - f);
      final inset = math.min(depth, 4.0) * 6.0;
      final double top;
      var opacity = 1.0;
      if (s == 0) {
        // The front card drops away as the next one comes forward.
        top = frontTop + f * frontHeight * 0.5;
        opacity = 1 - f;
      } else {
        top = frontTop - (s - f) * peek;
        if (s == visible) opacity = f;
      }
      children.add(Positioned(
        top: top,
        left: inset,
        right: inset,
        height: frontHeight,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: _StackCardView(
            card: widget.cards[index],
            front: s == 0,
            // Only a settled front card flies into an opened page.
            hero: s == 0 && f == 0,
          ),
        ),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: children);
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
  final bool hero;
  const _StackCardView(
      {required this.card, required this.front, required this.hero});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget surface = CardSurface(
      child: InkWell(
        onTap: card.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(Sp.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardTitleRow(
                title: card.title,
                leading: card.leading,
                trailing: card.trailing,
                maxLines: 1,
              ),
              if (card.face != null) ...[
                const SizedBox(height: Sp.x4),
                Divider(color: c.border, height: 1),
                const SizedBox(height: Sp.x4),
              ],
              // Every card is the front card's height (so one slides into
              // its place whole); a face taller than that clips rather
              // than overflowing.
              Expanded(
                child: card.face == null
                    ? const SizedBox.shrink()
                    : ClipRect(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: card.face!(context),
                        ),
                      ),
              ),
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
          ),
        ),
      ),
    );
    if (hero && card.heroTag != null) {
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
