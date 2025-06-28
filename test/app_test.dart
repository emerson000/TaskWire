// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taskwire/main.dart';

void main() {
  testWidgets('TaskWire app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppWrapper());

    await tester.pumpAndSettle();

    expect(find.text('TaskWire'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('Drawer navigation test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppWrapper());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Print Settings'), findsOneWidget);
  });

  testWidgets('Theme switching test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppWrapper());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final themeButton = find.byIcon(Icons.brightness_auto);
    expect(themeButton, findsOneWidget);

    await tester.tap(themeButton);
    await tester.pumpAndSettle();
  });
}
