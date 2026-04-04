import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:gracy/app.dart';

void main() {
  testWidgets('renders the Gracy app', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GracyApp()));
    await tester.pumpAndSettle();

    // Basic app rendering test - the app should load without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}


