import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/main.dart';

void main() {
  testWidgets('AudiobookApp renders main header and navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const AudiobookApp());
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('LIBRIVOX'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('DISCOVER'), findsOneWidget);
  });
}
