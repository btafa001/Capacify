// Basic smoke test for the Capacify brand mark widget. Kept deliberately
// dependency-free (no Firebase, no providers) since CapacifyApp itself
// requires Firebase.initializeApp() to have already run, which isn't
// available in a plain widget test without additional mocking.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capacify/shared/widgets/capacify_logo.dart';

void main() {
  testWidgets('CapacifySymbol renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CapacifySymbol(size: 48)),
        ),
      ),
    );

    expect(find.byType(CapacifySymbol), findsOneWidget);
  });
}
