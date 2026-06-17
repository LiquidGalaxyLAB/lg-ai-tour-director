// Basic smoke test: the app boots to the Home screen with the prompt heading.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App boots to Home', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AITourDirectorApp()));
    await tester.pump();

    expect(find.text('Where to next?'), findsOneWidget);
  });
}
