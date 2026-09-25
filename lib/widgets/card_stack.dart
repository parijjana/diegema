import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_theme.dart';

/// One card in a [CardStack].
class StackCard {
  final String title;

  /// Sits left of the title: an icon badge or a small cover.
  final Widget leading;

  /// Right of the title, e.g. a progress figure. Keep it one line.
  final Widget? trailing;

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
    this.heroTag,
  });
}

/// A rolodex of physical cards, after webOS's card view on the Palm Pre:
/// stacked top to bottom, each tucked a little under the next, showing only
/// its title row. Tap one to open it.
///
/// The stack rests on the bottom edge, in thumb reach, and turns like a
/// rolodex wheel: drag it down (or fling, or use the mouse wheel) and the
/// cards roll forward, the front one dropping away to come round at the
/// back. It wraps, so it turns endlessly in either direction.
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

  /// A card's height: its title row, which grows with the text size so the
  /// title is never cut off, with even padding above and below.
  static double cardHeightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleRow =
        math.max(40.0, scaler.scale(AppType.titleMd.fontSize! * 1.4));
    return titleRow + Sp.x4 * 2;
  }

  /// How far apart the cards sit: each tucks [Sp.x3] under the next.
  static double stepFor(BuildContext context) => cardHeightFor(context) - Sp.x3;

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
    final height = CardStack.cardHeightFor(context);
    final step = CardStack.stepFor(context);

    return LayoutBuilder(builder: (context, constraints) {
      final pad = widget.padding;
      final avail = math.max(height, constraints.maxHeight - pad.vertical);
      final width = math.min(560.0, constraints.maxWidth - pad.horizontal);
      // As many cards as fit; the rest wait their turn round the wheel.
      final visible = math.min(n, ((avail - height) / step).floor() + 1);
      final frontTop = avail - height;

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
                n < 2 ? null : (d) => _pos.value += d.primaryDelta! / step,
            onVerticalDragEnd: n < 2
                ? null
                : (d) {
                    final velocity = d.primaryVelocity! / step;
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
                          _buildCards(n, visible, step, frontTop, height),
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
      int n, int visible, double step, double frontTop, double height) {
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
        top = frontTop + f * height;
        opacity = 1 - f;
      } else {
        top = frontTop - (s - f) * step;
        if (s == visible) opacity = f;
      }
      children.add(Positioned(
        top: top,
        left: inset,
        right: inset,
        height: height,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: _StackCardView(
            card: widget.cards[index],
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

/// A short value for a card's trailing slot ("2 on", "42%").
class CardTrailingText extends StatelessWidget {
  final String text;
  const CardTrailingText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(text,
        style: AppType.label
            .copyWith(color: c.accentText, fontWeight: FontWeight.w700));
  }
}

class _StackCardView extends StatelessWidget {
  final StackCard card;
  final bool hero;
  const _StackCardView({required this.card, required this.hero});

  @override
  Widget build(BuildContext context) {
    Widget surface = CardSurface(
      child: InkWell(
        onTap: card.onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CardTitleRow(
              title: card.title,
              leading: card.leading,
              trailing: card.trailing,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
    if (hero && card.heroTag != null) {
      surface = Hero(tag: card.heroTag!, child: surface);
    }
    return Semantics(
      button: true,
      label: card.semanticLabel,
      excludeSemantics: true,
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

/// A card opened out of a stack: full screen, its title row, [body] (which
/// should scroll itself), and Close at the bottom, in thumb reach.
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
            padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x4, Sp.x5, Sp.x4),
            child: CardTitleRow(title: title, leading: leading),
          ),
          Divider(color: c.border, height: 1),
          Expanded(child: Builder(builder: body)),
          Divider(color: c.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x2),
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Close',
                iconSize: Dim.iconMd,
                constraints: const BoxConstraints.tightFor(
                    width: Dim.tapComfy, height: Dim.tapComfy),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: Sp.x5),
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: Sp.x4),
                child:
                    CardTitleRow(title: title, leading: leading, maxLines: 1),
              ),
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
