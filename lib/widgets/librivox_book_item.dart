import 'package:flutter/material.dart';
import '../domain/models/librivox_book.dart';

class LibriVoxBookItem extends StatelessWidget {
  final LibriVoxBook book;
  final bool isSelected;
  final VoidCallback onTap;

  const LibriVoxBookItem({
    super.key,
    required this.book,
    this.isSelected = false,
    required this.onTap,
  });

  BoxDecoration _buildCoverDecoration(ThemeData theme, double hue, bool isSelected) {
    final startColor = HSLColor.fromAHSL(1.0, hue, 0.65, 0.22).toColor();
    final endColor = HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.75, 0.12).toColor();
    final accentColor = HSLColor.fromAHSL(1.0, hue, 0.9, 0.6).toColor();

    return BoxDecoration(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(3),
        bottomLeft: Radius.circular(3),
        topRight: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [startColor, endColor],
      ),
      border: Border.all(
        color: isSelected
            ? theme.colorScheme.primary
            : accentColor.withValues(alpha: 0.25),
        width: isSelected ? 2.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.35),
          blurRadius: isSelected ? 16 : 8,
          spreadRadius: isSelected ? 1 : 0,
          offset: const Offset(3, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hash = book.title.hashCode;
    final double hue = (hash.abs() % 360).toDouble();
    final String firstLetter = book.title.isNotEmpty ? book.title[0].toUpperCase() : '';
    final String coverUrl = book.coverArtUrl;

    final Widget proceduralCover = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: _buildCoverDecoration(theme, hue, isSelected),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Book Spine Crease
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 12,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Top Decorative Neon Accent Strip
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            height: 3,
            child: Container(
              decoration: BoxDecoration(
                color: HSLColor.fromAHSL(1.0, hue, 0.9, 0.6).toColor().withValues(alpha: 0.6),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(
                    color: HSLColor.fromAHSL(1.0, hue, 0.9, 0.6).toColor().withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Glossy Sheen Overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.8, -1.0),
                    end: const Alignment(0.8, 1.0),
                    stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Center Decorative Letter Emblem
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
          ),
          // Headphone Icon Badge
          Positioned(
            bottom: 6,
            left: 12,
            child: Icon(
              Icons.headphones_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );

    final Widget coverWidget = coverUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2.5 : 1,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(3),
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => proceduralCover,
              ),
            ),
          )
        : proceduralCover;

    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 145,
            width: 110,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: coverWidget,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            book.authorNames,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              height: 1.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
