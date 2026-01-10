import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sigma/main.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app builds and shows at least a Material app or some content
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
