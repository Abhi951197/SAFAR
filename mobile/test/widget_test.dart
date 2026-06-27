import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safar/src/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows app name', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Safar'), findsOneWidget);
    expect(find.text('Every day is a new journey'), findsOneWidget);
  });
}
