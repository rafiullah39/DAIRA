import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daira/main.dart';
import 'package:daira/theme.dart';

void main() {
  testWidgets('DAIRA Login Screen Initial UI Test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    // Note: Since Firebase is initialized in main(), you might need to mock it 
    // for complex tests, but this basic test checks the UI structure.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that the Brand Name 'DAIRA' is present.
    expect(find.text('DAIRA'), findsOneWidget);

    // 3. Verify that the Login button exists.
    expect(find.text('LOG IN'), findsOneWidget);

    // 4. Verify that the input fields for Email and Password are present.
    expect(find.byType(TextField), findsNWidgets(2));

    // 5. Verify the Theme color for the Login Button.
    final ElevatedButton loginButton = tester.widget(find.byType(ElevatedButton));
    expect(
        loginButton.style?.backgroundColor?.resolve({}),
        DairaTheme.accentOrange
    );
  });
}