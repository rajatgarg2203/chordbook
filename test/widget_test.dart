import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordbook/app/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChordBookApp()));
    await tester.pumpAndSettle();

    expect(find.text('ChordBook'), findsOneWidget);
  });
}
