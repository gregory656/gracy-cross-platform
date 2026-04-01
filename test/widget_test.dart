import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gracy/app.dart';

void main() {
  testWidgets('renders the Gracy home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GracyApp()));
    await tester.pumpAndSettle();

    expect(find.text('GRACY'), findsOneWidget);
    expect(find.text('Privacy Shield'), findsOneWidget);
    expect(find.text('The Lock'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}


