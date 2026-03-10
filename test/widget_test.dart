import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_ai/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const TarotAiApp());
    expect(find.text('Tarot AI'), findsNothing);
  });
}
