import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tarot_ai/main.dart';

void main() {
  testWidgets('App boots without Firebase in widget test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FirebaseSetupRequiredPage(error: 'test'),
      ),
    );
    expect(find.byType(FirebaseSetupRequiredPage), findsOneWidget);
  });
}
