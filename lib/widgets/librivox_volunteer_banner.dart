import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'glass_card.dart';

class LibriVoxVolunteerBanner extends StatelessWidget {
  const LibriVoxVolunteerBanner({super.key});

  Future<void> _launchVolunteerUrl() async {
    final uri = Uri.parse('https://librivox.org/pages/volunteer-for-librivox/');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching volunteer URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: primary.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VOLUNTEER FOR LIBRIVOX',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0),
                ),
                const SizedBox(height: 3),
                Text(
                  'Donate your voice or proof-listen to help bring public domain books to life.',
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _launchVolunteerUrl,
            child: Text(
              'JOIN →',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }
}
