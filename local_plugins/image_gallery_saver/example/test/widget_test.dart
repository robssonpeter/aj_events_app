import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_events/main.dart';

void main() {
  testWidgets('Verify Widgets', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(new MyApp(isLoggedIn: false,));
    final Finder flatButtonPass = find.widgetWithText(ElevatedButton, '保存屏幕截图');
    expect(flatButtonPass, findsOneWidget);
  });
}
