import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passbook_app/main.dart';

void main() {
  testWidgets('FintrustApp auth gate smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FintrustApp());

    // Verify that the splash or login screen is rendered (auth gate defaults to login screen)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
