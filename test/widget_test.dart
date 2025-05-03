import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funny_bot/main.dart';  // Ensure this imports your main.dart

void main() {
  testWidgets('Chat UI functionality test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the chat input field is present.
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the send button is present.
    expect(find.byIcon(Icons.send), findsOneWidget);

    // Enter text into the TextField.
    await tester.enterText(find.byType(TextField), 'Hello!');

    // Tap the send button to send the message.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Verify that the user message "Hello!" is displayed.
    expect(find.text('Hello!'), findsOneWidget);

    // Verify that the bot's response (since you're using the OpenAI API) is displayed.
    // This assumes you mock or simulate a response from the bot for the test.
    // For now, we expect a "bot" message, for example, "Oops! My circuits just sneezed 🤖💨"
    expect(find.text('Oops! My circuits just sneezed 🤖💨'), findsOneWidget);
  });
}
