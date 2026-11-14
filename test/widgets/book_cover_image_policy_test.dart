import 'package:diegema/widgets/book_cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester t, String url) => t.pumpWidget(MaterialApp(
        home: BookCoverImage(
          bookId: 'b',
          networkUrl: url,
          fallbackBuilder: (_) => const Text('fallback'),
        ),
      ));

  testWidgets('off-policy cover URL renders the fallback, no Image.network',
      (t) async {
    for (final u in [
      'https://evil.example/c.jpg',
      'http://evil.example/c.jpg',
      'https://user@archive.org/c.jpg',
    ]) {
      await pump(t, u);
      expect(find.text('fallback'), findsOneWidget, reason: u);
    }
  });

  testWidgets('allowed host builds a network image upgraded to https',
      (t) async {
    await pump(t, 'http://archive.org/services/img/x');
    final img = t.widget<Image>(find.byType(Image));
    expect(
        (img.image as NetworkImage).url, 'https://archive.org/services/img/x');
  });
}
