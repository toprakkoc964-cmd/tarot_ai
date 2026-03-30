import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_ai/main.dart';

void main() {
  testWidgets('App boots without Firebase in widget test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TarotAiApp(bootstrapError: 'test'));
    expect(find.byType(FirebaseSetupRequiredPage), findsOneWidget);
  });
}
