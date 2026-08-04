import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/app.dart';

void main() {
  testWidgets('AudiobookApp renders main header and navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const AudiobookApp());
    expect(find.text('AULOS'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('DISCOVER'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
